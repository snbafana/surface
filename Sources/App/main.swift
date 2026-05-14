import AppKit
import Core
import SwiftUI

@main
struct MainApp: App {
    var body: some Scene {
        WindowGroup {
            SurfaceEditorView()
                .background(.clear)
                .onAppear {
                    DispatchQueue.main.async {
                        NSApp.windows.first?.makeSurfaceEditorOverlay()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct SurfaceEditorView: View {
    @State private var workspace = DemoSurface.workspace

    var body: some View {
        GeometryReader { proxy in
            let grid = workspace.layout.grid
            let cellWidth = proxy.size.width / CGFloat(grid.columns)
            let cellHeight = proxy.size.height / CGFloat(grid.rows)

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    var path = Path()
                    for column in 0...grid.columns {
                        let x = size.width * CGFloat(column) / CGFloat(grid.columns)
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for row in 0...grid.rows {
                        let y = size.height * CGFloat(row) / CGFloat(grid.rows)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(.white.opacity(0.22)), lineWidth: 1)
                }
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Surface")
                        .font(.headline)
                    ForEach(workspace.definitions) { definition in
                        Toggle(
                            definition.title,
                            isOn: Binding(
                                get: { workspace.layout.blocks.first(where: { $0.id == definition.id })?.enabled ?? false },
                                set: { isEnabled in try? workspace.setEnabled(isEnabled, for: definition.id) }
                            )
                        )
                    }
                }
                .padding(12)
                .frame(width: 210, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
                .padding(18)

                ForEach(workspace.enabledBlocks) { block in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title(for: block.id))
                            .font(.headline)
                        Text("\(block.frame.origin.x), \(block.frame.origin.y) / \(block.frame.size.width)x\(block.frame.size.height)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(
                        width: CGFloat(block.frame.size.width) * cellWidth - 8,
                        height: CGFloat(block.frame.size.height) * cellHeight - 8,
                        alignment: .topLeading
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
                    .offset(
                        x: CGFloat(block.frame.origin.x) * cellWidth + 4,
                        y: CGFloat(block.frame.origin.y) * cellHeight + 4
                    )
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                let x = block.frame.origin.x + Int((value.translation.width / cellWidth).rounded())
                                let y = block.frame.origin.y + Int((value.translation.height / cellHeight).rounded())
                                try? workspace.moveBlock(block.id, to: GridPoint(x: x, y: y))
                            }
                    )
                }
            }
        }
    }

    private func title(for id: BlockID) -> String {
        workspace.definitions.first(where: { $0.id == id })?.title ?? id.rawValue
    }
}

extension NSWindow {
    func makeSurfaceEditorOverlay() {
        guard let targetScreen = screen ?? NSScreen.main else {
            return
        }
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        styleMask.insert(.fullSizeContentView)
        setFrame(targetScreen.frame, display: true)
    }
}

enum DemoSurface {
    static let workspace: Workspace = {
        let definitions = [
            BlockDefinition(id: "command", title: "Command", defaultSize: GridSize(width: 8, height: 2)),
            BlockDefinition(id: "captures", title: "Captures", defaultSize: GridSize(width: 4, height: 4)),
            BlockDefinition(id: "status", title: "Status", defaultSize: GridSize(width: 4, height: 2))
        ]
        let layout = Layout(blocks: [
            BlockInstance(id: "command", frame: GridFrame(x: 2, y: 0, width: 8, height: 2)),
            BlockInstance(id: "captures", frame: GridFrame(x: 0, y: 2, width: 4, height: 4)),
            BlockInstance(id: "status", frame: GridFrame(x: 8, y: 2, width: 4, height: 2))
        ])
        return try! Workspace(definitions: definitions, layout: layout)
    }()
}
