import AppKit
import Core
import Foundation
import SwiftUI

public enum Plugin {
    public static let block = Block(
        id: "activitycontext",
        title: "Activity Context",
        defaultSize: GridSize(width: 7, height: 6)
    ) { context in
        Runtime(context: context)
    }
}

@MainActor
final class Runtime: ObservableObject, BlockRuntime {
    @Published private(set) var snapshot = ActivitySnapshot.empty(status: "Ready")

    private let context: Block.Context
    private let reader: ActivityContextReader
    private var reloadTask: Task<Void, Never>?

    init(context: Block.Context, reader: ActivityContextReader? = nil) {
        self.context = context
        self.reader = reader ?? ActivityContextReader(context: context)
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
        AnyView(ActivityContextView(runtime: self))
    }

    func copySummary() {
        guard context.allowsExternalWrites else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snapshot.markdownSummary, forType: .string)
    }

    private func refreshNow() {
        if context.storageDirectory != nil || !context.allowsLiveProcesses {
            reload()
        } else {
            statusWhileLoading()
            reloadTask?.cancel()
            let reader = reader
            reloadTask = Task.detached {
                let snapshot = reader.snapshot()
                guard !Task.isCancelled else {
                    return
                }
                await MainActor.run {
                    self.snapshot = snapshot
                }
            }
        }
    }

    private func statusWhileLoading() {
        snapshot = ActivitySnapshot.empty(source: "Coast", status: "Loading")
    }

    private func reload() {
        snapshot = reader.snapshot()
    }
}

struct ActivityContextReader: Sendable {
    var context: Block.Context
    var command: @Sendable ([String]) throws -> String = ActivityContextReader.runCommand

    func snapshot() -> ActivitySnapshot {
        if let storageDirectory = context.storageDirectory {
            return fixtureSnapshot(in: storageDirectory)
        }
        guard context.allowsLiveProcesses else {
            return .empty(status: "Live activity disabled")
        }
        return liveSnapshot()
    }

    private func fixtureSnapshot(in directory: URL) -> ActivitySnapshot {
        let url = directory.appendingPathComponent("activitycontext.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .empty(source: "fixture", status: "No activity fixture")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ActivitySnapshot.self, from: data)
        } catch {
            return .empty(source: "fixture", status: error.localizedDescription)
        }
    }

    private func liveSnapshot() -> ActivitySnapshot {
        let now = context.now ?? Date()
        let date = Self.dayString(for: now)
        do {
            let topAppsText = try command([coastPath, "usage", "top-applications", "--tr", date, "--limit", "5"])
            let sampleText = try command([coastPath, "query", "sample", "--tr", date, "--min-seg-len", "30"])
            let currentText = try? command([coastPath, "grab-screen"])
            return ActivitySnapshot(
                status: "Live",
                source: "Coast",
                capturedAt: Self.clockString(for: now),
                current: parseCurrentScreen(currentText ?? ""),
                topApps: parseTopApps(topAppsText),
                segments: parseSegments(sampleText)
            )
        } catch {
            return .empty(source: "Coast", status: "Coast unavailable")
        }
    }

    private var coastPath: String {
        let local = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/coast")
            .path
        return FileManager.default.isExecutableFile(atPath: local) ? local : "coast"
    }

    private func parseTopApps(_ text: String) -> [ActivityApp] {
        text.split(separator: "\n")
            .dropFirst()
            .compactMap { line in
                let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return nil }
                return ActivityApp(name: parts[0], time: parts[1])
            }
    }

    private func parseSegments(_ text: String) -> [ActivityFrame] {
        text.split(separator: "\n")
            .dropFirst(2)
            .compactMap { line in
                let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard parts.count >= 7 else { return nil }
                return ActivityFrame(
                    id: parts[0],
                    time: parts[1],
                    duration: parts[2],
                    app: parts[3],
                    domain: parts[4] == "-" ? nil : parts[4],
                    url: parts[5] == "-" ? nil : parts[5],
                    title: parts[6].isEmpty ? nil : parts[6]
                )
            }
    }

    private func parseCurrentScreen(_ text: String) -> ActivityFrame? {
        guard !text.isEmpty else { return nil }
        let fields = text
            .split(separator: "\t")
            .reduce(into: [String: String]()) { result, part in
                let pieces = part.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if pieces.count == 2 {
                    result[pieces[0]] = pieces[1]
                }
            }
        guard let app = fields["app"] else { return nil }
        return ActivityFrame(
            id: nil,
            time: fields["time"],
            duration: nil,
            app: app,
            domain: nil,
            url: fields["path"],
            title: "Current screen"
        )
    }

    private static func runCommand(_ command: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = URL(fileURLWithPath: command[0])
        process.arguments = Array(command.dropFirst())
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ActivityContextError.commandFailed
        }
        return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    private static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func clockString(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

enum ActivityContextError: Error {
    case commandFailed
}

struct ActivitySnapshot: Codable, Equatable, Sendable {
    var status: String
    var source: String
    var capturedAt: String?
    var current: ActivityFrame?
    var topApps: [ActivityApp]
    var segments: [ActivityFrame]

    static func empty(source: String = "Surface", status: String) -> ActivitySnapshot {
        ActivitySnapshot(status: status, source: source, capturedAt: nil, current: nil, topApps: [], segments: [])
    }

    var markdownSummary: String {
        var lines = ["# Activity Context", "- Source: \(source)", "- Status: \(status)"]
        if let current {
            lines.append("- Current: \(current.displayTitle)")
        }
        for segment in segments.prefix(3) {
            lines.append("- \(segment.time ?? "") \(segment.displayTitle)")
        }
        return lines.joined(separator: "\n")
    }
}

struct ActivityApp: Codable, Equatable, Identifiable, Sendable {
    var id: String { name }
    var name: String
    var time: String
}

struct ActivityFrame: Codable, Equatable, Identifiable, Sendable {
    var id: String?
    var time: String?
    var duration: String?
    var app: String
    var domain: String?
    var url: String?
    var title: String?

    var displayTitle: String {
        [app, title, domain].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " - ")
    }
}

private struct ActivityContextView: View {
    @ObservedObject var runtime: Runtime

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            current
            sections
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            pill(runtime.snapshot.status)
            Text(runtime.snapshot.source)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Button {
                runtime.copySummary()
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 26, height: 26)
                    .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("Copy activity summary")
        }
    }

    @ViewBuilder
    private var current: some View {
        if let current = runtime.snapshot.current {
            VStack(alignment: .leading, spacing: 4) {
                Text(current.app)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(current.title ?? current.url ?? "Current screen")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var sections: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Top Apps")
                    .font(.caption.weight(.semibold))
                ForEach(runtime.snapshot.topApps.prefix(4)) { app in
                    row(title: app.name, detail: app.time)
                }
                if runtime.snapshot.topApps.isEmpty {
                    empty("No app totals")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Recent")
                    .font(.caption.weight(.semibold))
                ForEach(runtime.snapshot.segments.prefix(4)) { frame in
                    row(title: frame.app, detail: frame.title ?? frame.duration ?? frame.time ?? "")
                }
                if runtime.snapshot.segments.isEmpty {
                    empty("No segments")
                }
            }
        }
    }

    private func row(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
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
