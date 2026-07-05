import AppKit
import Core
import Foundation
import SwiftUI

public enum Plugin {
    public static let block = Block(
        id: "githubqueue",
        title: "GitHub Queue",
        defaultSize: GridSize(width: 8, height: 5)
    ) { context in
        Runtime(context: context)
    }
}

@MainActor
final class Runtime: ObservableObject, BlockRuntime {
    @Published private(set) var status = "Ready"
    @Published private(set) var pullRequests: [GitHubPullRequest] = []

    private let context: Block.Context
    private let reader: GitHubQueueReader
    private var reloadTask: Task<Void, Never>?

    init(context: Block.Context, reader: GitHubQueueReader? = nil) {
        self.context = context
        self.reader = reader ?? GitHubQueueReader(context: context)
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
        AnyView(GitHubQueueView(runtime: self))
    }

    func copyURL(_ pullRequest: GitHubPullRequest) {
        copy(pullRequest.url)
    }

    func copyCheckout(_ pullRequest: GitHubPullRequest) {
        copy("gh pr checkout \(pullRequest.number)")
    }

    func open(_ pullRequest: GitHubPullRequest) {
        guard context.allowsExternalWrites, let url = URL(string: pullRequest.url) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func copy(_ text: String) {
        guard context.allowsExternalWrites else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func refreshNow() {
        if context.storageDirectory != nil || !context.allowsLiveProcesses {
            reload()
        } else {
            status = "Loading"
            pullRequests = []
            reloadTask?.cancel()
            let reader = reader
            reloadTask = Task.detached {
                let state = reader.state()
                guard !Task.isCancelled else {
                    return
                }
                await MainActor.run {
                    self.status = state.status
                    self.pullRequests = state.pullRequests
                }
            }
        }
    }

    private func reload() {
        let state = reader.state()
        status = state.status
        pullRequests = state.pullRequests
    }
}

struct GitHubQueueReader: Sendable {
    var context: Block.Context
    var command: @Sendable ([String]) throws -> String = LocalCommand.run

    func state() -> GitHubQueueState {
        if let storageDirectory = context.storageDirectory {
            return fixtureState(in: storageDirectory)
        }
        guard context.allowsLiveProcesses else {
            return GitHubQueueState(status: "Live GitHub disabled", pullRequests: [])
        }
        return liveState()
    }

    private func fixtureState(in directory: URL) -> GitHubQueueState {
        let url = directory.appendingPathComponent("githubqueue-prs.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return GitHubQueueState(status: "No fixture", pullRequests: [])
        }
        do {
            let data = try Data(contentsOf: url)
            return try Self.decoder.decode(GitHubQueueState.self, from: data)
        } catch {
            return GitHubQueueState(status: error.localizedDescription, pullRequests: [])
        }
    }

    private func liveState() -> GitHubQueueState {
        do {
            let output = try command([
                "gh",
                "pr",
                "list",
                "--json",
                "number,title,url,headRefName,baseRefName,author,isDraft,reviewDecision,updatedAt",
                "--limit",
                "12"
            ])
            let data = output.data(using: .utf8) ?? Data()
            let pullRequests = try Self.decoder.decode([GitHubPullRequest].self, from: data)
            return GitHubQueueState(
                status: pullRequests.isEmpty ? "No PRs" : "Live gh",
                pullRequests: pullRequests
            )
        } catch {
            return GitHubQueueState(status: "GitHub unavailable", pullRequests: [])
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

struct GitHubQueueState: Codable, Equatable, Sendable {
    var status: String
    var pullRequests: [GitHubPullRequest]
}

struct GitHubPullRequest: Codable, Equatable, Identifiable, Sendable {
    var id: Int { number }
    var number: Int
    var title: String
    var url: String
    var headRefName: String
    var baseRefName: String
    var author: GitHubUser
    var isDraft: Bool
    var reviewDecision: String?
    var updatedAt: Date?
    var checkSummary: GitHubCheckSummary?

    var stateLabel: String {
        if isDraft {
            return "Draft"
        }
        if let checkSummary, checkSummary.failing > 0 {
            return "Failing"
        }
        if let reviewDecision, !reviewDecision.isEmpty {
            return reviewDecision.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return "Open"
    }

    var stateColor: Color {
        switch stateLabel {
        case "Failing":
            return .red
        case "Draft":
            return .secondary
        case "Approved":
            return .green
        default:
            return .orange
        }
    }
}

struct GitHubUser: Codable, Equatable, Sendable {
    var login: String
}

struct GitHubCheckSummary: Codable, Equatable, Sendable {
    var passing: Int
    var failing: Int
    var pending: Int
}

private struct GitHubQueueView: View {
    @ObservedObject var runtime: Runtime
    @State private var selectedNumber: Int?
    @State private var dragOffset: CGFloat = 0

    private var selected: GitHubPullRequest? {
        if let selectedNumber,
           let pullRequest = runtime.pullRequests.first(where: { $0.number == selectedNumber }) {
            return pullRequest
        }
        return runtime.pullRequests.first
    }

    private var selectedIndex: Int {
        guard let selected,
              let index = runtime.pullRequests.firstIndex(where: { $0.number == selected.number }) else {
            return 0
        }
        return index
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if let selected {
                card(selected)
                    .id(selected.number)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                Text("No pull requests in this repo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
                    .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear {
            selectedNumber = selected?.number
        }
        .onChange(of: runtime.pullRequests.map(\.number)) { _, _ in
            if selectedNumber == nil || selected == nil {
                selectedNumber = runtime.pullRequests.first?.number
            }
        }
        .animation(.snappy(duration: 0.2), value: selected?.number)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            pill(runtime.status)
            Text("\(runtime.pullRequests.count) PRs")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            if !runtime.pullRequests.isEmpty {
                Text("\(selectedIndex + 1) of \(runtime.pullRequests.count)")
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            arrowButton("chevron.left") { move(-1) }
            arrowButton("chevron.right") { move(1) }
        }
    }

    private func card(_ pullRequest: GitHubPullRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("#\(pullRequest.number)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Text(pullRequest.stateLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(pullRequest.stateColor)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(pullRequest.stateColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            }

            Text(pullRequest.title)
                .font(.caption.weight(.semibold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(pullRequest.author.login)  \(pullRequest.headRefName) -> \(pullRequest.baseRefName)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let checkSummary = pullRequest.checkSummary {
                Text("\(checkSummary.passing) pass / \(checkSummary.failing) fail / \(checkSummary.pending) pending")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                actionButton("Open", systemImage: "arrow.up.right.square") {
                    runtime.open(pullRequest)
                }
                actionButton("Copy URL", systemImage: "link") {
                    runtime.copyURL(pullRequest)
                }
                actionButton("Checkout", systemImage: "terminal") {
                    runtime.copyCheckout(pullRequest)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(pullRequest.stateColor.opacity(abs(dragOffset) > 0 ? 0.11 : 0.05), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(pullRequest.stateColor.opacity(abs(dragOffset) > 0 ? 0.34 : 0.14), lineWidth: 1)
        }
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset / 54)))
        .gesture(
            DragGesture(minimumDistance: 16)
                .onChanged { value in dragOffset = value.translation.width }
                .onEnded { value in
                    if abs(value.translation.width) > 90 {
                        move(value.translation.width > 0 ? 1 : -1)
                    }
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                        dragOffset = 0
                    }
                }
        )
    }

    private func move(_ offset: Int) {
        guard !runtime.pullRequests.isEmpty else { return }
        let next = min(max(selectedIndex + offset, 0), runtime.pullRequests.count - 1)
        selectedNumber = runtime.pullRequests[next].number
    }

    private func arrowButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 24, height: 24)
                .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
        }
        .buttonStyle(.plain)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
        .help(title)
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
