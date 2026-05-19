import Core
import SurfaceUI
import SwiftUI

struct SurfaceView: View {
    @EnvironmentObject private var surface: Surface
    @State private var dragging: [BlockID: CGSize] = [:]
    @State private var hoveredBlock: BlockID?
    @State private var menuCorner = OverlayCorner.topLeft
    @State private var menuDrag = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            let grid = surface.workspace.layout.grid
            let cellWidth = proxy.size.width / CGFloat(grid.columns)
            let cellHeight = proxy.size.height / CGFloat(grid.rows)
            let menuSize = CGSize(width: 270, height: 150)
            let margin = CGFloat(18)
            let menuOrigin = menuCorner.origin(in: proxy.size, size: menuSize, margin: margin)

            ZStack(alignment: .topLeading) {
                if surface.mode == .edit {
                    gridCanvas(grid: grid)
                }

                controls(menuSize: menuSize)
                    .offset(x: menuOrigin.x + menuDrag.width, y: menuOrigin.y + menuDrag.height)
                    .animation(.smooth(duration: 0.16), value: menuCorner)
                    .animation(.smooth(duration: 0.12), value: menuDrag)
                    .gesture(menuDragGesture(menuOrigin: menuOrigin, menuSize: menuSize, container: proxy.size))
                    .zIndex(10)

                ForEach(surface.workspace.enabledBlocks) { block in
                    blockCard(block, cellWidth: cellWidth, cellHeight: cellHeight)
                }
            }
        }
    }

    private func gridCanvas(grid: Core.Grid) -> some View {
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
    }

    @ViewBuilder
    private func controls(menuSize: CGSize) -> some View {
        if surface.mode == .edit {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Surface")
                        .font(.headline)
                    ForEach(surface.workspace.blocks) { block in
                        Toggle(
                            block.title,
                            isOn: Binding(
                                get: {
                                    surface.workspace.layout.blocks
                                        .first(where: { $0.id == block.id })?.enabled ?? false
                                },
                                set: { surface.setBlockEnabled($0, id: block.id) }
                            )
                        )
                    }
                }
                Button("Use") {
                    withAnimation(.smooth(duration: 0.18)) {
                        dragging.removeAll()
                        hoveredBlock = nil
                        surface.show()
                    }
                }
                .buttonStyle(.bordered)
                Button("Esc") {
                    surface.hide()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.bordered)
            }
            .padding(12)
            .frame(width: menuSize.width, height: menuSize.height, alignment: .topLeading)
            .background(SurfaceStyle.panelBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(SurfaceStyle.border, lineWidth: 1)
            }
        } else {
            Button("Edit") {
                withAnimation(.smooth(duration: 0.18)) {
                    surface.edit()
                }
            }
            .buttonStyle(.bordered)
            .offset(x: 18, y: 18)
        }
    }

    private func menuDragGesture(menuOrigin: CGPoint, menuSize: CGSize, container: CGSize) -> some Gesture {
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
                    menuCorner = OverlayCorner.nearest(to: point, in: container)
                    menuDrag = .zero
                }
            }
    }

    private func blockCard(_ block: Block.Instance, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        let isDragging = dragging[block.id] != nil
        let isActive = surface.mode == .edit && (hoveredBlock == block.id || isDragging)

        return BlockChrome(
            title: title(for: block.id),
            subtitle: isActive ? "\(block.frame.origin.x), \(block.frame.origin.y) / \(block.frame.size.width)x\(block.frame.size.height)" : nil,
            isActive: isActive
        ) {
            surface.runningBlocks.view(for: block.id)
        }
        .frame(
            width: CGFloat(block.frame.size.width) * cellWidth - 8,
            height: CGFloat(block.frame.size.height) * cellHeight - 8,
            alignment: .topLeading
        )
        .overlay(alignment: .topTrailing) {
            dragHandle(isVisible: surface.mode == .edit && isDragging)
        }
        .overlay(alignment: .bottomTrailing) {
            dragHandle(isVisible: surface.mode == .edit && isDragging)
        }
        .overlay(alignment: .bottomLeading) {
            dragHandle(isVisible: surface.mode == .edit && isDragging)
        }
        .shadow(
            color: .black.opacity(isDragging ? 0.28 : 0.08),
            radius: isDragging ? 24 : 10,
            y: isDragging ? 12 : 4
        )
        .scaleEffect(isDragging ? 1.015 : 1.0)
        .offset(
            x: CGFloat(block.frame.origin.x) * cellWidth + 4,
            y: CGFloat(block.frame.origin.y) * cellHeight + 4
        )
        .offset(dragging[block.id] ?? .zero)
        .animation(.smooth(duration: 0.18), value: block.frame)
        .animation(.smooth(duration: 0.12), value: dragging[block.id] ?? .zero)
        .animation(.smooth(duration: 0.12), value: hoveredBlock)
        .onHover { isHovering in
            guard surface.mode == .edit else { return }
            hoveredBlock = isHovering ? block.id : (hoveredBlock == block.id ? nil : hoveredBlock)
        }
        .gesture(blockDragGesture(block, cellWidth: cellWidth, cellHeight: cellHeight))
    }

    @ViewBuilder
    private func dragHandle(isVisible: Bool) -> some View {
        if isVisible {
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: 8, height: 8)
                .padding(7)
        }
    }

    private func blockDragGesture(
        _ block: Block.Instance,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard surface.mode == .edit else { return }
                dragging[block.id] = value.translation
            }
            .onEnded { value in
                guard surface.mode == .edit else { return }
                let x = block.frame.origin.x + Int((value.translation.width / cellWidth).rounded())
                let y = block.frame.origin.y + Int((value.translation.height / cellHeight).rounded())
                withAnimation(.smooth(duration: 0.18)) {
                    dragging[block.id] = .zero
                    surface.moveBlock(block.id, to: GridPoint(x: x, y: y))
                }
            }
    }

    private func title(for id: BlockID) -> String {
        surface.blocks.block(for: id)?.title ?? id.rawValue
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
