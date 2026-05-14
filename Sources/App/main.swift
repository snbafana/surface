import Core
import SwiftUI

@main
struct MainApp: App {
    var body: some Scene {
        WindowGroup {
            SurfacePreviewView()
                .frame(minWidth: 980, minHeight: 620)
        }
    }
}

struct SurfacePreviewView: View {
    @State private var workspace = DemoSurface.workspace

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(0.86), .blue.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Surface")
                            .font(.largeTitle)
                        Text("editable block layout")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
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
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                    Spacer()
                }
                .frame(width: 220)

                GeometryReader { proxy in
                    let grid = workspace.layout.grid
                    let cellWidth = proxy.size.width / CGFloat(grid.columns)
                    let cellHeight = proxy.size.height / CGFloat(grid.rows)

                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(.white.opacity(0.045))
                            .overlay {
                                Canvas { context, size in
                                    var path = Path()
                                    for column in 1..<grid.columns {
                                        let x = size.width * CGFloat(column) / CGFloat(grid.columns)
                                        path.move(to: CGPoint(x: x, y: 0))
                                        path.addLine(to: CGPoint(x: x, y: size.height))
                                    }
                                    for row in 1..<grid.rows {
                                        let y = size.height * CGFloat(row) / CGFloat(grid.rows)
                                        path.move(to: CGPoint(x: 0, y: y))
                                        path.addLine(to: CGPoint(x: size.width, y: y))
                                    }
                                    context.stroke(path, with: .color(.white.opacity(0.10)), lineWidth: 1)
                                }
                            }

                        ForEach(workspace.enabledBlocks) { block in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(title(for: block.id))
                                    .font(.headline)
                                Text("\(block.frame.origin.x), \(block.frame.origin.y) / \(block.frame.size.width)x\(block.frame.size.height)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(
                                width: CGFloat(block.frame.size.width) * cellWidth - 8,
                                height: CGFloat(block.frame.size.height) * cellHeight - 8,
                                alignment: .topLeading
                            )
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
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
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(32)
        }
    }

    private func title(for id: BlockID) -> String {
        workspace.definitions.first(where: { $0.id == id })?.title ?? id.rawValue
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
