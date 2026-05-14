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

    @Test func duplicateDefinitionsAreRejected() {
        let definitions = [
            BlockDefinition(id: "command", title: "Command"),
            BlockDefinition(id: "command", title: "Command Copy")
        ]

        #expect(throws: ModelError.duplicateDefinition) {
            _ = try Workspace(definitions: definitions, layout: Layout())
        }
    }

    @Test func unknownBlocksAreRejected() {
        let layout = Layout(blocks: [
            BlockInstance(id: "missing", frame: GridFrame(x: 0, y: 0, width: 4, height: 2))
        ])

        #expect(throws: ModelError.unknownBlock("missing")) {
            _ = try Workspace(definitions: [], layout: layout)
        }
    }

    @Test func blocksOutsideTheGridAreRejected() {
        let layout = Layout(grid: Grid(columns: 4, rows: 4), blocks: [
            BlockInstance(id: "command", frame: GridFrame(x: 3, y: 3, width: 2, height: 2))
        ])

        #expect(throws: ModelError.blockOutsideGrid("command")) {
            _ = try Workspace(
                definitions: [BlockDefinition(id: "command", title: "Command")],
                layout: layout
            )
        }
    }

    @Test func overlappingEnabledBlocksAreRejected() {
        let layout = Layout(blocks: [
            BlockInstance(id: "captures", frame: GridFrame(x: 0, y: 0, width: 4, height: 3)),
            BlockInstance(id: "status", frame: GridFrame(x: 2, y: 1, width: 4, height: 3))
        ])

        #expect(throws: ModelError.overlappingBlocks("captures", "status")) {
            _ = try Workspace(
                definitions: [
                    BlockDefinition(id: "captures", title: "Captures"),
                    BlockDefinition(id: "status", title: "Status")
                ],
                layout: layout
            )
        }
    }

    @Test func overlappingDisabledBlocksAreAllowed() throws {
        let workspace = try Workspace(
            definitions: [
                BlockDefinition(id: "captures", title: "Captures"),
                BlockDefinition(id: "status", title: "Status")
            ],
            layout: Layout(blocks: [
                BlockInstance(id: "captures", enabled: false, frame: GridFrame(x: 0, y: 0, width: 4, height: 3)),
                BlockInstance(id: "status", enabled: false, frame: GridFrame(x: 2, y: 1, width: 4, height: 3))
            ])
        )

        #expect(workspace.layout.blocks.count == 2)
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

    @Test func moveBlockStopsAtNearestOpenFrameBeforeOverlap() throws {
        var workspace = try Workspace(
            definitions: [
                BlockDefinition(id: "captures", title: "Captures"),
                BlockDefinition(id: "status", title: "Status")
            ],
            layout: Layout(blocks: [
                BlockInstance(id: "captures", frame: GridFrame(x: 0, y: 0, width: 4, height: 3)),
                BlockInstance(id: "status", frame: GridFrame(x: 6, y: 0, width: 4, height: 3))
            ])
        )

        try workspace.moveBlock("status", to: GridPoint(x: 2, y: 1))

        #expect(workspace.layout.blocks.first(where: { $0.id == "status" })?.frame == GridFrame(x: 4, y: 1, width: 4, height: 3))
    }

    @Test func moveBlockKeepsLastReachableFrameOnBlockedDiagonalDrag() throws {
        var workspace = try Workspace(
            definitions: [
                BlockDefinition(id: "captures", title: "Captures"),
                BlockDefinition(id: "status", title: "Status")
            ],
            layout: Layout(grid: Grid(columns: 12, rows: 8), blocks: [
                BlockInstance(id: "captures", frame: GridFrame(x: 4, y: 3, width: 4, height: 3)),
                BlockInstance(id: "status", frame: GridFrame(x: 0, y: 0, width: 3, height: 2))
            ])
        )

        try workspace.moveBlock("status", to: GridPoint(x: 5, y: 4))

        #expect(workspace.layout.blocks.first(where: { $0.id == "status" })?.frame == GridFrame(x: 1, y: 1, width: 3, height: 2))
    }

    @Test func disablingAndReenablingBlockPreservesPlacement() throws {
        var workspace = try Workspace(
            definitions: [BlockDefinition(id: "captures", title: "Captures")],
            layout: Layout(blocks: [
                BlockInstance(id: "captures", frame: GridFrame(x: 5, y: 2, width: 4, height: 3))
            ])
        )

        try workspace.setEnabled(false, for: "captures")
        try workspace.setEnabled(true, for: "captures")

        #expect(workspace.layout.blocks.count == 1)
        #expect(workspace.layout.blocks[0].enabled)
        #expect(workspace.layout.blocks[0].frame == GridFrame(x: 5, y: 2, width: 4, height: 3))
    }

    @Test func reenablingBlockMovesToOpenSlotWhenSavedPlacementIsOccupied() throws {
        var workspace = try Workspace(
            definitions: [
                BlockDefinition(id: "captures", title: "Captures"),
                BlockDefinition(id: "status", title: "Status")
            ],
            layout: Layout(grid: Grid(columns: 8, rows: 4), blocks: [
                BlockInstance(id: "captures", enabled: false, frame: GridFrame(x: 0, y: 0, width: 4, height: 2)),
                BlockInstance(id: "status", enabled: true, frame: GridFrame(x: 0, y: 0, width: 4, height: 2))
            ])
        )

        try workspace.setEnabled(true, for: "captures")

        #expect(workspace.layout.blocks.first(where: { $0.id == "captures" })?.frame == GridFrame(x: 4, y: 0, width: 4, height: 2))
    }

    @Test func disabledBlocksDoNotReserveAutoPlacementSpace() throws {
        let layout = Layout(grid: Grid(columns: 8, rows: 4), blocks: [
            BlockInstance(id: "captures", enabled: false, frame: GridFrame(x: 0, y: 0, width: 4, height: 2))
        ])

        #expect(layout.nextFrame(size: GridSize(width: 4, height: 2)) == GridFrame(x: 0, y: 0, width: 4, height: 2))
    }

    @Test func enabledBlocksReserveAutoPlacementSpace() throws {
        let layout = Layout(grid: Grid(columns: 8, rows: 4), blocks: [
            BlockInstance(id: "captures", enabled: true, frame: GridFrame(x: 0, y: 0, width: 4, height: 2))
        ])

        #expect(layout.nextFrame(size: GridSize(width: 4, height: 2)) == GridFrame(x: 4, y: 0, width: 4, height: 2))
    }

    @Test func autoPlacementWrapsToNextRowWhenWidthDoesNotFit() {
        let layout = Layout(grid: Grid(columns: 6, rows: 4), blocks: [
            BlockInstance(id: "left", enabled: true, frame: GridFrame(x: 0, y: 0, width: 4, height: 1))
        ])

        #expect(layout.nextFrame(size: GridSize(width: 3, height: 1)) == GridFrame(x: 0, y: 1, width: 3, height: 1))
    }

    @Test func autoPlacementAvoidsVerticalIntersection() {
        let layout = Layout(grid: Grid(columns: 6, rows: 4), blocks: [
            BlockInstance(id: "tall", enabled: true, frame: GridFrame(x: 0, y: 0, width: 2, height: 3))
        ])

        #expect(layout.nextFrame(size: GridSize(width: 2, height: 2)) == GridFrame(x: 2, y: 0, width: 2, height: 2))
    }

    @Test func autoPlacementClampsOversizedRequestedSize() {
        let layout = Layout(grid: Grid(columns: 5, rows: 3))

        #expect(layout.nextFrame(size: GridSize(width: 50, height: 50)) == GridFrame(x: 0, y: 0, width: 5, height: 3))
    }

    @Test func gridAndSizeValuesClampToMinimumOne() {
        let grid = Grid(columns: 0, rows: -2)
        let size = GridSize(width: 0, height: -5)

        #expect(grid.columns == 1)
        #expect(grid.rows == 1)
        #expect(size == GridSize(width: 1, height: 1))
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

    @Test func disabledBlockPlacementRoundTripsThroughJSON() throws {
        let workspace = try Workspace(
            definitions: [
                BlockDefinition(id: "captures", title: "Captures")
            ],
            layout: Layout(blocks: [
                BlockInstance(id: "captures", enabled: false, frame: GridFrame(x: 3, y: 2, width: 4, height: 3))
            ])
        )

        var decoded = try Store.decode(try Store.encode(workspace))
        try decoded.setEnabled(true, for: "captures")

        #expect(decoded.layout.blocks[0].enabled)
        #expect(decoded.layout.blocks[0].frame == GridFrame(x: 3, y: 2, width: 4, height: 3))
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
