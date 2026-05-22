import AppKit
import Blocks
import Core
import UI
import SwiftUI

@MainActor
final class Surface: ObservableObject {
    @Published var isVisible = false
    @Published var mode = SurfaceMode.use
    @Published var workspace: Workspace

    let blocks: BlockRegistry
    let keyboardShortcuts: KeyboardShortcuts
    let runningBlocks: RunningBlocks

    private weak var panel: SurfacePanel?

    init(blocks: BlockRegistry = Blocks.registry) {
        let keyboardShortcuts = KeyboardShortcuts()
        self.blocks = blocks
        self.keyboardShortcuts = keyboardShortcuts
        workspace = try! SurfaceLayout.workspace(registry: blocks)
        runningBlocks = RunningBlocks(
            blocks: blocks,
            context: Block.Context(keyboardShortcuts: keyboardShortcuts)
        )
        runningBlocks.sync(with: workspace.enabledBlocks)
    }

    func attach(panel: SurfacePanel) {
        self.panel = panel
        applyVisibility()
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        isVisible = true
        mode = .use
        refreshRunningBlocks()
        applyVisibility()
    }

    func edit() {
        isVisible = true
        mode = .edit
        refreshRunningBlocks()
        applyVisibility()
    }

    func hide() {
        isVisible = false
        mode = .use
        applyVisibility()
    }

    func setBlockEnabled(_ enabled: Bool, id: BlockID) {
        try? workspace.setEnabled(enabled, for: id)
        runningBlocks.sync(with: workspace.enabledBlocks)
    }

    func moveBlock(_ id: BlockID, to origin: GridPoint) {
        try? workspace.moveBlock(id, to: origin)
        runningBlocks.sync(with: workspace.enabledBlocks)
    }

    private func applyVisibility() {
        guard let panel else { return }
        if isVisible {
            panel.prepareForDisplay()
            NSApp.activate(ignoringOtherApps: true)
            panel.orderFrontRegardless()
            panel.makeKey()
        } else {
            panel.orderOut(nil)
        }
    }

    private func refreshRunningBlocks() {
        runningBlocks.sync(with: workspace.enabledBlocks)
        Task {
            await runningBlocks.refreshAll()
        }
    }
}

@MainActor
final class RunningBlocks: ObservableObject {
    private let blocks: BlockRegistry
    private let context: Block.Context
    private var runtimes: [BlockID: any BlockRuntime] = [:]

    init(blocks: BlockRegistry, context: Block.Context = Block.Context()) {
        self.blocks = blocks
        self.context = context
    }

    func sync(with enabledBlocks: [Block.Instance]) {
        let enabledIDs = Set(enabledBlocks.map(\.id))
        for id in Array(runtimes.keys) where !enabledIDs.contains(id) {
            runtimes[id]?.stop()
            runtimes[id] = nil
        }

        for block in enabledBlocks {
            _ = runtime(for: block.id)
        }
    }

    func view(for id: BlockID) -> AnyView {
        guard let runtime = runtime(for: id) else {
            return AnyView(PlaceholderBlockView(text: "Missing block runtime"))
        }
        return runtime.makeView()
    }

    func refreshAll() async {
        for runtime in runtimes.values {
            await runtime.refresh()
        }
    }

    private func runtime(for id: BlockID) -> (any BlockRuntime)? {
        if let runtime = runtimes[id] {
            return runtime
        }
        guard let block = blocks.block(for: id) else {
            return nil
        }

        let runtime = block.makeRuntime(context)
        runtimes[id] = runtime
        runtime.start()
        return runtime
    }
}

enum SurfaceMode {
    case edit
    case use
}
