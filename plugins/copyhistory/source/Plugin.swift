import AppKit
import Core
import Foundation
import SwiftUI

public enum Plugin {
    public static let block = Block(
        id: "copyhistory",
        title: "Copy History",
        defaultSize: GridSize(width: 8, height: 8)
    ) { context in
        Runtime(context: context)
    }
}

@MainActor
final class Runtime: ObservableObject, BlockRuntime {
    @Published private(set) var isRunning = false
    @Published private(set) var entries: [CopyHistoryEntry] = []
    @Published private(set) var status = "Ready"

    private let context: Block.Context
    private let store = CopyHistoryStore()
    private var pollTask: Task<Void, Never>?
    private var observedChangeCount = NSPasteboard.general.changeCount

    init(context: Block.Context) {
        self.context = context
    }

    func start() {
        guard !isRunning else {
            return
        }
        isRunning = true
        reload()
        guard context.allowsLiveProcesses, canWriteHistory else {
            return
        }
        observedChangeCount = NSPasteboard.general.changeCount
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.captureClipboardIfChanged()
            }
        }
    }

    func stop() {
        isRunning = false
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        reload()
        if context.allowsLiveProcesses, canWriteHistory {
            captureClipboardIfChanged()
        }
    }

    func makeView() -> AnyView {
        AnyView(ContentView(runtime: self))
    }

    func copy(_ entry: CopyHistoryEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        observedChangeCount = pasteboard.changeCount
        status = "Copied"
    }

    func clear() {
        do {
            if canWriteHistory {
                try store.save([], to: historyURL)
            }
            entries = []
            status = "Cleared"
        } catch {
            status = error.localizedDescription
        }
    }

    private func captureClipboardIfChanged(pasteboard: NSPasteboard = .general) {
        guard pasteboard.changeCount != observedChangeCount else {
            return
        }
        observedChangeCount = pasteboard.changeCount
        guard let text = CopyHistoryStore.normalizedText(from: pasteboard) else {
            return
        }
        do {
            entries = try store.add(text: text, to: historyURL)
            status = "Captured"
        } catch {
            status = error.localizedDescription
        }
    }

    private func reload() {
        do {
            entries = try store.load(from: historyURL)
            status = isRunning ? "Watching" : "Ready"
        } catch {
            entries = []
            status = error.localizedDescription
        }
    }

    private var historyURL: URL {
        if let storageDirectory = context.storageDirectory {
            return storageDirectory.appendingPathComponent("copyhistory.txt")
        }
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Surface/CopyHistory/copyhistory.txt", isDirectory: false)
    }

    private var canWriteHistory: Bool {
        context.storageDirectory != nil || context.allowsExternalWrites
    }
}

private struct ContentView: View {
    @ObservedObject var runtime: Runtime

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if runtime.entries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No copied text yet")
                        .font(.caption.weight(.semibold))
                    Text(runtime.isRunning ? "Copy text anywhere to start history." : "Copy history is stopped.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(runtime.entries) { entry in
                            Button {
                                runtime.copy(entry)
                            } label: {
                                HStack(alignment: .center, spacing: 8) {
                                    Text(entry.text)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, height: 24)
                                        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Copy item")
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(.primary.opacity(0.08))
                                    .frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(runtime.status)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(.primary.opacity(0.055), in: Capsule())

            Text("\(runtime.entries.count) \(runtime.entries.count == 1 ? "item" : "items")")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            if !runtime.entries.isEmpty {
                Button {
                    runtime.clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help("Clear history")
            }
        }
    }
}

struct CopyHistoryEntry: Identifiable, Hashable, Sendable {
    var id = UUID()
    let text: String
}

struct CopyHistoryStore: Sendable {
    private let limit: Int

    init(limit: Int = 25) {
        self.limit = max(1, limit)
    }

    func load(from url: URL) throws -> [CopyHistoryEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { CopyHistoryEntry(text: String($0)) }
    }

    func add(text: String, to url: URL) throws -> [CopyHistoryEntry] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try load(from: url)
        }

        var entries = try load(from: url)
        if entries.first?.text == trimmed {
            return entries
        }
        entries.insert(CopyHistoryEntry(text: trimmed), at: 0)
        entries = Array(entries.prefix(limit))
        try save(entries, to: url)
        return entries
    }

    func save(_ entries: [CopyHistoryEntry], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let text = entries.map(\.text).joined(separator: "\n")
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func normalizedText(from pasteboard: NSPasteboard) -> String? {
        guard let raw = pasteboard.string(forType: .string) else {
            return nil
        }
        let text = raw
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
