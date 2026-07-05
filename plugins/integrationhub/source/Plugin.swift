import AppKit
import Core
import Foundation
import SwiftUI

public enum Plugin {
    public static let block = Block(
        id: "integrationhub",
        title: "Integration Hub",
        defaultSize: GridSize(width: 10, height: 4)
    ) { context in
        Runtime(context: context)
    }
}

@MainActor
final class Runtime: ObservableObject, BlockRuntime {
    @Published private(set) var state = IntegrationHubState(status: "Ready", items: [])

    private let context: Block.Context
    private let reader: IntegrationHubReader
    private var reloadTask: Task<Void, Never>?

    init(context: Block.Context, reader: IntegrationHubReader? = nil) {
        self.context = context
        self.reader = reader ?? IntegrationHubReader(context: context)
    }

    func start() {
        refreshNow()
    }

    func stop() {
        reloadTask?.cancel()
        reloadTask = nil
    }

    func refresh() async {
        refreshNow()
    }

    func makeView() -> AnyView {
        AnyView(IntegrationHubView(runtime: self))
    }

    func copyCommand(_ item: IntegrationItem) {
        guard context.allowsExternalWrites, let command = item.command, !command.isEmpty else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    func openURL(_ item: IntegrationItem) {
        guard context.allowsExternalWrites,
              let rawURL = item.url,
              let url = URL(string: rawURL) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func refreshNow() {
        if context.storageDirectory != nil || !context.allowsLiveProcesses {
            reload()
        } else {
            state = IntegrationHubState(status: "Checking", items: [])
            reloadTask?.cancel()
            let reader = reader
            reloadTask = Task.detached {
                let state = reader.state()
                guard !Task.isCancelled else {
                    return
                }
                await MainActor.run {
                    self.state = state
                }
            }
        }
    }

    private func reload() {
        state = reader.state()
    }
}

struct IntegrationHubReader: Sendable {
    var context: Block.Context
    var environment: [String: String] = ProcessInfo.processInfo.environment
    var executablePath: @Sendable (String) -> String? = { LocalCommand.executablePath($0) }

    func state() -> IntegrationHubState {
        if let storageDirectory = context.storageDirectory {
            return fixtureState(in: storageDirectory)
        }
        guard context.allowsLiveProcesses else {
            return IntegrationHubState(status: "Live checks disabled", items: [])
        }
        return liveState()
    }

    private func fixtureState(in directory: URL) -> IntegrationHubState {
        let url = directory.appendingPathComponent("integrationhub-items.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return IntegrationHubState(status: "No fixture", items: [])
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(IntegrationHubState.self, from: data)
        } catch {
            return IntegrationHubState(status: error.localizedDescription, items: [])
        }
    }

    private func liveState() -> IntegrationHubState {
        let items = [
            browserbaseBrowse(),
            browserbaseLegacyBB(),
            integrationsCatalog(),
            localCLI(id: "coast", name: "Coast", kind: "screen context", commandName: "coast", readyCommand: "coast usage top-applications --tr today --limit 5", url: "https://coast.ai"),
            localCLI(id: "cued", name: "Cued", kind: "contacts", commandName: "cued", readyCommand: "cued integrations status", url: nil),
            localCLI(id: "gh", name: "GitHub CLI", kind: "developer queue", commandName: "gh", readyCommand: "gh pr list --limit 12", url: "https://cli.github.com"),
            steipeteToolbelt()
        ]
        let readyCount = items.filter(\.isReady).count
        return IntegrationHubState(status: "\(readyCount) of \(items.count) ready", items: items)
    }

    private func browserbaseBrowse() -> IntegrationItem {
        let installed = executablePath("browse") != nil
        let hasAPIKey = !(environment["BROWSERBASE_API_KEY"] ?? "").isEmpty
        return IntegrationItem(
            id: "browserbase-browse",
            name: "Browserbase Browse",
            kind: "browser automation",
            status: installed ? (hasAPIKey ? "Ready" : "Needs key") : "Missing",
            detail: installed
                ? (hasAPIKey ? "Browse CLI is installed; cloud commands can use the API key." : "Set BROWSERBASE_API_KEY before cloud/session commands.")
                : "Current Browserbase CLI surface is `browse`.",
            command: installed ? "browse status" : "npm install -g browse",
            url: "https://docs.browserbase.com/integrations/skills/browse-cli",
            priority: 1
        )
    }

    private func browserbaseLegacyBB() -> IntegrationItem {
        let installed = executablePath("bb") != nil
        return IntegrationItem(
            id: "browserbase-bb",
            name: "Browserbase bb",
            kind: "legacy cli",
            status: installed ? "Installed" : "Optional",
            detail: installed
                ? "`bb` is available; prefer `browse` for new Browserbase workflows."
                : "`@browserbasehq/cli` exposes `bb`, but Browserbase docs now steer new work to `browse`.",
            command: installed ? "bb --help" : "npm view @browserbasehq/cli bin version",
            url: "https://www.npmjs.com/package/@browserbasehq/cli",
            priority: 2
        )
    }

    private func integrationsCatalog() -> IntegrationItem {
        IntegrationItem(
            id: "integrations-sh",
            name: "integrations.sh",
            kind: "catalog api",
            status: "Available",
            detail: "Search/detect/discover MCP, OpenAPI, GraphQL, and CLI surfaces without adding credentials to Surface.",
            command: "curl 'https://integrations.sh/api/search?q=browserbase&kind=cli&limit=5'",
            url: "https://integrations.sh/openapi.json",
            priority: 3
        )
    }

    private func localCLI(
        id: String,
        name: String,
        kind: String,
        commandName: String,
        readyCommand: String,
        url: String?
    ) -> IntegrationItem {
        let installed = executablePath(commandName) != nil
        return IntegrationItem(
            id: id,
            name: name,
            kind: kind,
            status: installed ? "Ready" : "Missing",
            detail: installed ? "\(commandName) is on PATH." : "Install or configure \(commandName) before live blocks can enrich from it.",
            command: installed ? readyCommand : nil,
            url: url,
            priority: installed ? 4 : 7
        )
    }

    private func steipeteToolbelt() -> IntegrationItem {
        let available = ["peekaboo", "mcporter", "oracle"].filter { executablePath($0) != nil }
        return IntegrationItem(
            id: "steipete-toolbelt",
            name: "Agent Toolbelt",
            kind: "block ideas",
            status: available.isEmpty ? "Candidates" : "\(available.count) installed",
            detail: available.isEmpty
                ? "Peekaboo, mcporter, oracle, CodexBar, RepoBar, and cookie tools are good Surface block patterns."
                : "Installed: \(available.joined(separator: ", ")).",
            command: "open https://github.com/steipete",
            url: "https://github.com/steipete",
            priority: 8
        )
    }

}

struct IntegrationHubState: Codable, Equatable, Sendable {
    var status: String
    var items: [IntegrationItem]
}

struct IntegrationItem: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var kind: String
    var status: String
    var detail: String
    var command: String?
    var url: String?
    var priority: Int

    var isReady: Bool {
        ["Ready", "Installed", "Available"].contains(status) || status.hasSuffix("installed")
    }

    var statusColor: Color {
        switch status {
        case "Ready", "Installed", "Available":
            return .green
        case "Missing":
            return .secondary
        case "Needs key":
            return .orange
        default:
            return .blue
        }
    }

    var iconName: String {
        if status == "Missing" {
            return "circle.dashed"
        }
        if kind.contains("browser") {
            return "globe"
        }
        if kind.contains("catalog") {
            return "square.grid.2x2"
        }
        if kind.contains("developer") {
            return "chevron.left.forwardslash.chevron.right"
        }
        return "terminal"
    }
}

private struct IntegrationHubView: View {
    @ObservedObject var runtime: Runtime

    private var sortedItems: [IntegrationItem] {
        runtime.state.items.sorted {
            if $0.priority == $1.priority {
                return $0.name < $1.name
            }
            return $0.priority < $1.priority
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if sortedItems.isEmpty {
                Text("No integration rows")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
                    .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sortedItems) { item in
                            itemRow(item)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            pill(runtime.state.status)
            Text("read-only")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
        }
    }

    private func itemRow(_ item: IntegrationItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(item.statusColor)
                .frame(width: 26, height: 26)
                .background(item.statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(item.kind)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(item.status)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(item.statusColor)
                        .lineLimit(1)
                }
                Text(item.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                if item.command != nil {
                    iconButton("doc.on.doc", help: "Copy command") {
                        runtime.copyCommand(item)
                    }
                }
                if item.url != nil {
                    iconButton("arrow.up.right.square", help: "Open source") {
                        runtime.openURL(item)
                    }
                }
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.primary.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(.primary.opacity(0.055), in: Capsule())
    }
}
