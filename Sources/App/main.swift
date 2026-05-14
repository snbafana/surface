import Core
import SwiftUI

@main
struct MainApp: App {
    var body: some Scene {
        WindowGroup {
            SurfacePreviewView(document: DemoSurface.document)
                .frame(minWidth: 900, minHeight: 560)
        }
    }
}

struct SurfacePreviewView: View {
    let document: Document

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(0.86), .blue.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Surface")
                    .font(.largeTitle)
                Text("v0 model preview")
                    .foregroundStyle(.secondary)

                GeometryReader { proxy in
                    let cellWidth = proxy.size.width / CGFloat(document.layout.grid.columns)
                    let cellHeight = proxy.size.height / CGFloat(document.layout.grid.rows)

                    ZStack(alignment: .topLeading) {
                        ForEach(document.enabledBlocks) { block in
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                                .overlay(alignment: .topLeading) {
                                    Text(title(for: block.id))
                                        .font(.headline)
                                        .padding()
                                }
                                .frame(
                                    width: CGFloat(block.frame.size.width) * cellWidth - 8,
                                    height: CGFloat(block.frame.size.height) * cellHeight - 8
                                )
                                .offset(
                                    x: CGFloat(block.frame.origin.x) * cellWidth + 4,
                                    y: CGFloat(block.frame.origin.y) * cellHeight + 4
                                )
                        }
                    }
                }
            }
            .padding(32)
        }
    }

    private func title(for id: BlockID) -> String {
        document.definitions.first(where: { $0.id == id })?.title ?? id.rawValue
    }
}

enum DemoSurface {
    static let document: Document = {
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
        return try! Document(definitions: definitions, layout: layout)
    }()
}
