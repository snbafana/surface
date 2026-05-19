import Core
import SwiftUI

public enum Plugin {
    public static let block = Block(
        id: "copyhistory",
        title: "Copy History",
        defaultSize: GridSize(width: 8, height: 8)
    ) { _ in
        Runtime()
    }
}

@MainActor
final class Runtime: BlockRuntime {
    private var isRunning = false

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
            Text("Copy History")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(isRunning ? "Watching is ready" : "Stopped")
                .font(.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
