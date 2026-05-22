import Core
import SwiftUI

@MainActor
final class Runtime: ObservableObject, BlockRuntime {
    @Published private(set) var isRunning = false
    @Published private(set) var snapshot = CodexSnapshot()
    private let reader: CodexStateReader
    private var refreshTask: Task<Void, Never>?

    init(reader: CodexStateReader = CodexStateReader()) {
        self.reader = reader
    }

    func start() {
        guard !isRunning else {
            return
        }
        isRunning = true
        reload()
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, self.isRunning else {
                    return
                }
                self.reload()
            }
        }
    }

    func stop() {
        isRunning = false
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        reload()
    }

    func makeView() -> AnyView {
        AnyView(PluginView(runtime: self))
    }

    func approve(_ action: CodexActionProposal) {
        try? reader.approveAction(action)
        reload()
    }

    func deny(_ action: CodexActionProposal) {
        try? reader.denyAction(action)
        reload()
    }

    func cancel(_ action: CodexActionProposal) {
        try? reader.cancelAction(action.id)
        reload()
    }

    private func reload() {
        snapshot = reader.snapshot()
    }
}
