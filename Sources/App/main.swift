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
    @State private var dragging: [BlockID: CGSize] = [:]
    @State private var hoveredBlock: BlockID?
    @State private var menuCorner = OverlayCorner.topLeft
    @State private var menuDrag = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            let grid = workspace.layout.grid
            let cellWidth = proxy.size.width / CGFloat(grid.columns)
            let cellHeight = proxy.size.height / CGFloat(grid.rows)
            let menuSize = CGSize(width: 270, height: 150)
            let margin = CGFloat(18)
            let menuOrigin = menuCorner.origin(in: proxy.size, size: menuSize, margin: margin)

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
                    context.stroke(path, with: .color(.white.opacity(0.10)), lineWidth: 1)
                }
                .ignoresSafeArea()

                HStack(alignment: .top, spacing: 10) {
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
                    Button("Esc") {
                        NSApp.terminate(nil)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.bordered)
                }
                .padding(12)
                .frame(width: menuSize.width, height: menuSize.height, alignment: .topLeading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
                .offset(x: menuOrigin.x + menuDrag.width, y: menuOrigin.y + menuDrag.height)
                .animation(.smooth(duration: 0.16), value: menuCorner)
                .animation(.smooth(duration: 0.12), value: menuDrag)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            menuDrag = value.translation
                        }
                        .onEnded { value in
                            let point = CGPoint(
                                x: menuOrigin.x + value.translation.width + menuSize.width / 2,
                                y: menuOrigin.y + value.translation.height + menuSize.height / 2
                            )
                            withAnimation(.smooth(duration: 0.18)) {
                                menuCorner = OverlayCorner.nearest(to: point, in: proxy.size)
                                menuDrag = .zero
                            }
                        }
                )

                ForEach(workspace.enabledBlocks) { block in
                    let isActive = hoveredBlock == block.id || dragging[block.id] != nil

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title(for: block.id))
                            .font(.headline)
                        if isActive {
                            Text("\(block.frame.origin.x), \(block.frame.origin.y) / \(block.frame.size.width)x\(block.frame.size.height)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(
                        width: CGFloat(block.frame.size.width) * cellWidth - 8,
                        height: CGFloat(block.frame.size.height) * cellHeight - 8,
                        alignment: .topLeading
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(isActive ? 0.30 : 0.14), lineWidth: 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isActive {
                            Circle()
                                .fill(.white.opacity(0.85))
                                .frame(width: 8, height: 8)
                                .padding(7)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if isActive {
                            Circle()
                                .fill(.white.opacity(0.85))
                                .frame(width: 8, height: 8)
                                .padding(7)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if isActive {
                            Circle()
                                .fill(.white.opacity(0.85))
                                .frame(width: 8, height: 8)
                                .padding(7)
                        }
                    }
                    .shadow(color: .black.opacity(isActive ? 0.28 : 0.08), radius: isActive ? 24 : 10, y: isActive ? 12 : 4)
                    .scaleEffect(dragging[block.id] != nil ? 1.015 : 1.0)
                    .offset(
                        x: CGFloat(block.frame.origin.x) * cellWidth + 4,
                        y: CGFloat(block.frame.origin.y) * cellHeight + 4
                    )
                    .offset(dragging[block.id] ?? .zero)
                    .animation(.smooth(duration: 0.18), value: block.frame)
                    .animation(.smooth(duration: 0.12), value: dragging[block.id] ?? .zero)
                    .animation(.smooth(duration: 0.12), value: hoveredBlock)
                    .onHover { isHovering in
                        hoveredBlock = isHovering ? block.id : (hoveredBlock == block.id ? nil : hoveredBlock)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragging[block.id] = value.translation
                            }
                            .onEnded { value in
                                let x = block.frame.origin.x + Int((value.translation.width / cellWidth).rounded())
                                let y = block.frame.origin.y + Int((value.translation.height / cellHeight).rounded())
                                withAnimation(.smooth(duration: 0.18)) {
                                    dragging[block.id] = .zero
                                    try? workspace.moveBlock(block.id, to: GridPoint(x: x, y: y))
                                }
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

enum OverlayCorner {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    func origin(in container: CGSize, size: CGSize, margin: CGFloat) -> CGPoint {
        switch self {
        case .topLeft:
            CGPoint(x: margin, y: margin)
        case .topRight:
            CGPoint(x: container.width - size.width - margin, y: margin)
        case .bottomLeft:
            CGPoint(x: margin, y: container.height - size.height - margin)
        case .bottomRight:
            CGPoint(x: container.width - size.width - margin, y: container.height - size.height - margin)
        }
    }

    static func nearest(to point: CGPoint, in container: CGSize) -> OverlayCorner {
        switch (point.x >= container.width / 2, point.y >= container.height / 2) {
        case (false, false):
            .topLeft
        case (true, false):
            .topRight
        case (false, true):
            .bottomLeft
        case (true, true):
            .bottomRight
        }
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
        isMovable = false
        isMovableByWindowBackground = false
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        styleMask = [.borderless, .fullSizeContentView]
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        setFrame(targetScreen.visibleFrame, display: true)
    }
}

enum DemoSurface {
    static let workspace: Workspace = {
        let definitions = [
            BlockDefinition(id: "command", title: "Command", defaultSize: GridSize(width: 16, height: 4)),
            BlockDefinition(id: "captures", title: "Captures", defaultSize: GridSize(width: 8, height: 8)),
            BlockDefinition(id: "status", title: "Status", defaultSize: GridSize(width: 8, height: 4))
        ]
        let layout = Layout(grid: Grid(columns: 24, rows: 16), blocks: [
            BlockInstance(id: "command", frame: GridFrame(x: 4, y: 1, width: 16, height: 4)),
            BlockInstance(id: "captures", frame: GridFrame(x: 1, y: 6, width: 8, height: 8)),
            BlockInstance(id: "status", frame: GridFrame(x: 15, y: 6, width: 8, height: 4))
        ])
        return try! Workspace(definitions: definitions, layout: layout)
    }()
}
