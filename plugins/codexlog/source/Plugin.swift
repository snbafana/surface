import Core
import SwiftUI

public enum Plugin {
    public static let block = Block(
        id: "codexlog",
        title: "Codex Log",
        defaultSize: GridSize(width: 10, height: 8)
    ) { context in
        Runtime(context: context)
    }
}

@MainActor
final class Runtime: BlockRuntime {
    private var isRunning = false

    init(context: Block.Context) {
        _ = context
    }

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func refresh() async {}

    func makeView() -> AnyView {
        AnyView(ContentView(isRunning: isRunning))
    }
}

private struct ContentView: View {
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Codex Log")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(isRunning ? "Ready to index" : "Stopped")
                .font(.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
