import Foundation
import Testing
@testable import SurfaceCore

@Suite("Surface block model")
struct SurfaceCoreTests {
    @Test func documentAllowsOneInstancePerBlockDefinition() throws {
        let definitions = [
            BlockDefinition(id: "command", title: "Command")
        ]
        let layout = SurfaceLayout(blocks: [
            BlockInstance(id: "command", frame: GridFrame(x: 0, y: 0, width: 4, height: 2))
        ])

        let document = try SurfaceDocument(definitions: definitions, layout: layout)

        #expect(document.enabledBlocks.map(\.id) == ["command"])
    }

    @Test func duplicateBlockInstancesAreRejected() throws {
        let definitions = [
            BlockDefinition(id: "command", title: "Command")
        ]
        let layout = SurfaceLayout(blocks: [
            BlockInstance(id: "command", frame: GridFrame(x: 0, y: 0, width: 4, height: 2)),
            BlockInstance(id: "command", frame: GridFrame(x: 4, y: 0, width: 4, height: 2))
        ])

        #expect(throws: SurfaceModelError.duplicateBlock("command")) {
            _ = try SurfaceDocument(definitions: definitions, layout: layout)
        }
    }

    @Test func enablingBlockCreatesAClampedInstance() throws {
        var document = try SurfaceDocument(
            definitions: [BlockDefinition(id: "status", title: "Status", defaultSize: GridSize(width: 20, height: 20))],
            layout: SurfaceLayout(grid: SurfaceGrid(columns: 12, rows: 8))
        )

        try document.setEnabled(true, for: "status")

        #expect(document.layout.blocks.count == 1)
        #expect(document.layout.blocks[0].frame.origin == GridPoint(x: 0, y: 0))
        #expect(document.layout.blocks[0].frame.size == GridSize(width: 12, height: 8))
    }

    @Test func moveBlockSnapsInsideGridBounds() throws {
        var document = try SurfaceDocument(
            definitions: [BlockDefinition(id: "captures", title: "Captures", defaultSize: GridSize(width: 4, height: 3))],
            layout: SurfaceLayout(blocks: [
                BlockInstance(id: "captures", frame: GridFrame(x: 0, y: 0, width: 4, height: 3))
            ])
        )

        try document.moveBlock("captures", to: GridPoint(x: 99, y: 99))

        #expect(document.layout.blocks[0].frame.origin == GridPoint(x: 8, y: 5))
    }

    @Test func documentRoundTripsThroughJSON() throws {
        let document = try SurfaceDocument(
            definitions: [
                BlockDefinition(id: "command", title: "Command", defaultSize: GridSize(width: 8, height: 2))
            ],
            layout: SurfaceLayout(blocks: [
                BlockInstance(id: "command", enabled: true, frame: GridFrame(x: 2, y: 1, width: 8, height: 2))
            ])
        )

        let data = try SurfaceStore.encode(document)
        let decoded = try SurfaceStore.decode(data)

        #expect(decoded == document)
    }

    @Test func pluginBoundaryIsOnlyADescriptorInV0c() {
        let catalog = SurfaceCatalog(
            providers: [SurfaceProviderDescriptor(id: "quicksave", title: "Quicksave", blockIDs: ["captures"])],
            blocks: [BlockDefinition(id: "captures", title: "Captures")]
        )

        #expect(catalog.providers[0].blockIDs == ["captures"])
        #expect(catalog.blocks[0].id == "captures")
    }
}
