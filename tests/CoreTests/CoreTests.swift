import Foundation
import Testing
@testable import Core

@Suite("Surface block model")
struct CoreTests {
    @Test func workspaceAllowsOneInstancePerBlockDefinition() throws {
        let definitions = [
            BlockDefinition(id: "command", title: "Command")
        ]
        let layout = Layout(blocks: [
            BlockInstance(id: "command", frame: GridFrame(x: 0, y: 0, width: 4, height: 2))
        ])

        let workspace = try Workspace(definitions: definitions, layout: layout)

        #expect(workspace.enabledBlocks.map(\.id) == ["command"])
    }

    @Test func duplicateBlockInstancesAreRejected() throws {
        let definitions = [
            BlockDefinition(id: "command", title: "Command")
        ]
        let layout = Layout(blocks: [
            BlockInstance(id: "command", frame: GridFrame(x: 0, y: 0, width: 4, height: 2)),
            BlockInstance(id: "command", frame: GridFrame(x: 4, y: 0, width: 4, height: 2))
        ])

        #expect(throws: ModelError.duplicateBlock("command")) {
            _ = try Workspace(definitions: definitions, layout: layout)
        }
    }

    @Test func enablingBlockCreatesAClampedInstance() throws {
        var workspace = try Workspace(
            definitions: [BlockDefinition(id: "status", title: "Status", defaultSize: GridSize(width: 20, height: 20))],
            layout: Layout(grid: Grid(columns: 12, rows: 8))
        )

        try workspace.setEnabled(true, for: "status")

        #expect(workspace.layout.blocks.count == 1)
        #expect(workspace.layout.blocks[0].frame.origin == GridPoint(x: 0, y: 0))
        #expect(workspace.layout.blocks[0].frame.size == GridSize(width: 12, height: 8))
    }

    @Test func moveBlockSnapsInsideGridBounds() throws {
        var workspace = try Workspace(
            definitions: [BlockDefinition(id: "captures", title: "Captures", defaultSize: GridSize(width: 4, height: 3))],
            layout: Layout(blocks: [
                BlockInstance(id: "captures", frame: GridFrame(x: 0, y: 0, width: 4, height: 3))
            ])
        )

        try workspace.moveBlock("captures", to: GridPoint(x: 99, y: 99))

        #expect(workspace.layout.blocks[0].frame.origin == GridPoint(x: 8, y: 5))
    }

    @Test func workspaceRoundTripsThroughJSON() throws {
        let workspace = try Workspace(
            definitions: [
                BlockDefinition(id: "command", title: "Command", defaultSize: GridSize(width: 8, height: 2))
            ],
            layout: Layout(blocks: [
                BlockInstance(id: "command", enabled: true, frame: GridFrame(x: 2, y: 1, width: 8, height: 2))
            ])
        )

        let data = try Store.encode(workspace)
        let decoded = try Store.decode(data)

        #expect(decoded == workspace)
    }

    @Test func pluginBoundaryIsOnlyADescriptorInV0c() {
        let catalog = Catalog(
            providers: [ProviderDescriptor(id: "quicksave", title: "Quicksave", blockIDs: ["captures"])],
            blocks: [BlockDefinition(id: "captures", title: "Captures")]
        )

        #expect(catalog.providers[0].blockIDs == ["captures"])
        #expect(catalog.blocks[0].id == "captures")
    }
}
