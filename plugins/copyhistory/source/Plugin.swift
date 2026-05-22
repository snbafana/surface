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
final class Runtime: BlockRuntime {
    private let context: Block.Context
    private var isRunning = false
    private var entries: [CopyHistoryEntry] = []

    init(context: Block.Context) {
        self.context = context
    }

    func start() {
        isRunning = true
        reload()
    }

    func stop() {
        isRunning = false
    }

    func refresh() async {
        reload()
    }

    func makeView() -> AnyView {
        AnyView(ContentView(isRunning: isRunning, entries: entries))
    }

    private func reload() {
        guard let historyURL = context.storageDirectory?.appendingPathComponent("copyhistory.txt"),
              let text = try? String(contentsOf: historyURL, encoding: .utf8) else {
            entries = []
            return
        }

        entries = text
            .split(separator: "\n")
            .map { line in
                CopyHistoryEntry(text: String(line))
            }
    }
}

private struct ContentView: View {
    let isRunning: Bool
    let entries: [CopyHistoryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entries.isEmpty {
                Text(isRunning ? "Watching is ready" : "Stopped")
                    .font(.body)
            } else {
                ForEach(entries) { entry in
                    Text(entry.text)
                        .font(.caption)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(.primary.opacity(0.08))
                                .frame(height: 1)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct CopyHistoryEntry: Identifiable {
    var id: String { text }
    let text: String
}
