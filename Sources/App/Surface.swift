import AppKit
import Blocks
import Core
import SurfaceUI
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
        workspace = DemoSurface.workspace(blocks: blocks)
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
        applyVisibility()
    }

    func edit() {
        isVisible = true
        mode = .edit
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

@MainActor
enum DemoSurface {
    static func workspace(blocks: BlockRegistry = Blocks.registry) -> Workspace {
        let layout = Layout(grid: Grid(columns: 24, rows: 16), blocks: [
            Block.Instance(id: "quicksave", frame: GridFrame(x: 1, y: 1, width: 8, height: 8)),
            Block.Instance(id: "copyhistory", frame: GridFrame(x: 10, y: 1, width: 8, height: 8)),
            Block.Instance(id: "codexlog", frame: GridFrame(x: 5, y: 10, width: 10, height: 5))
        ])
        return try! Workspace(blocks: blocks.blocks, layout: layout)
    }
}
