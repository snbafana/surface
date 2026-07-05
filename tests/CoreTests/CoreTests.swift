import Foundation
import SwiftUI
import Testing
@testable import Core

@Suite("Surface block model")
struct CoreTests {
    @Test func workspaceAllowsOneInstancePerBlock() throws {
        let workspace = try Workspace(
            blocks: [testBlock(id: "quicksave")],
            layout: Layout(blocks: [
                Block.Instance(id: "quicksave", frame: GridFrame(x: 0, y: 0, width: 4, height: 2))
            ])
        )

        #expect(workspace.enabledBlocks.map(\.id) == ["quicksave"])
    }

    @Test func duplicateBlockInstancesAreRejected() throws {
        let layout = Layout(blocks: [
            Block.Instance(id: "quicksave", frame: GridFrame(x: 0, y: 0, width: 4, height: 2)),
            Block.Instance(id: "quicksave", frame: GridFrame(x: 4, y: 0, width: 4, height: 2))
        ])

        #expect(throws: ModelError.duplicateBlock("quicksave")) {
            _ = try Workspace(blocks: [testBlock(id: "quicksave")], layout: layout)
        }
    }

    @Test func duplicateBlocksAreRejectedByRegistry() {
        #expect(throws: ModelError.duplicateBlock("quicksave")) {
            _ = try BlockRegistry([
                testBlock(id: "quicksave"),
                testBlock(id: "quicksave", title: "Quicksave Copy")
            ])
        }
    }

    @Test func duplicateBlocksAreRejectedByWorkspace() {
        #expect(throws: ModelError.duplicateBlock("quicksave")) {
            _ = try Workspace(
                blocks: [
                    testBlock(id: "quicksave"),
                    testBlock(id: "quicksave", title: "Quicksave Copy")
                ],
                layout: Layout()
            )
        }
    }

    @Test func unknownBlocksAreRejected() {
        let layout = Layout(blocks: [
            Block.Instance(id: "missing", frame: GridFrame(x: 0, y: 0, width: 4, height: 2))
        ])

        #expect(throws: ModelError.unknownBlock("missing")) {
            _ = try Workspace(blocks: [], layout: layout)
        }
    }

    @Test func blocksOutsideTheGridAreRejected() {
        let layout = Layout(grid: Grid(columns: 4, rows: 4), blocks: [
            Block.Instance(id: "quicksave", frame: GridFrame(x: 3, y: 3, width: 2, height: 2))
        ])

        #expect(throws: ModelError.blockOutsideGrid("quicksave")) {
            _ = try Workspace(blocks: [testBlock(id: "quicksave")], layout: layout)
        }
    }

    @Test func overlappingEnabledBlocksAreRejected() {
        let layout = Layout(blocks: [
            Block.Instance(id: "copyhistory", frame: GridFrame(x: 0, y: 0, width: 4, height: 3)),
            Block.Instance(id: "codexlog", frame: GridFrame(x: 2, y: 1, width: 4, height: 3))
        ])

        #expect(throws: ModelError.overlappingBlocks("copyhistory", "codexlog")) {
            _ = try Workspace(
                blocks: [
                    testBlock(id: "copyhistory"),
                    testBlock(id: "codexlog")
                ],
                layout: layout
            )
        }
    }

    @Test func overlappingDisabledBlocksAreAllowed() throws {
        let workspace = try Workspace(
            blocks: [
                testBlock(id: "copyhistory"),
                testBlock(id: "codexlog")
            ],
            layout: Layout(blocks: [
                Block.Instance(id: "copyhistory", enabled: false, frame: GridFrame(x: 0, y: 0, width: 4, height: 3)),
                Block.Instance(id: "codexlog", enabled: false, frame: GridFrame(x: 2, y: 1, width: 4, height: 3))
            ])
        )

        #expect(workspace.layout.blocks.count == 2)
    }

    @Test func enablingBlockCreatesAClampedInstance() throws {
        var workspace = try Workspace(
            blocks: [testBlock(id: "codexlog", defaultSize: GridSize(width: 20, height: 20))],
            layout: Layout(grid: Grid(columns: 12, rows: 8))
        )

        try workspace.setEnabled(true, for: "codexlog")

        #expect(workspace.layout.blocks.count == 1)
        #expect(workspace.layout.blocks[0].frame.origin == GridPoint(x: 0, y: 0))
        #expect(workspace.layout.blocks[0].frame.size == GridSize(width: 12, height: 8))
    }

    @Test func moveBlockSnapsInsideGridBounds() throws {
        var workspace = try Workspace(
            blocks: [testBlock(id: "copyhistory", defaultSize: GridSize(width: 4, height: 3))],
            layout: Layout(blocks: [
                Block.Instance(id: "copyhistory", frame: GridFrame(x: 0, y: 0, width: 4, height: 3))
            ])
        )

        try workspace.moveBlock("copyhistory", to: GridPoint(x: 99, y: 99))

        #expect(workspace.layout.blocks[0].frame.origin == GridPoint(x: 8, y: 5))
    }

    @Test func moveBlockStopsAtNearestOpenFrameBeforeOverlap() throws {
        var workspace = try Workspace(
            blocks: [
                testBlock(id: "copyhistory"),
                testBlock(id: "codexlog")
            ],
            layout: Layout(blocks: [
                Block.Instance(id: "copyhistory", frame: GridFrame(x: 0, y: 0, width: 4, height: 3)),
                Block.Instance(id: "codexlog", frame: GridFrame(x: 6, y: 0, width: 4, height: 3))
            ])
        )

        try workspace.moveBlock("codexlog", to: GridPoint(x: 2, y: 1))

        #expect(workspace.layout.blocks.first(where: { $0.id == "codexlog" })?.frame == GridFrame(x: 4, y: 1, width: 4, height: 3))
    }

    @Test func moveBlockKeepsLastReachableFrameOnBlockedDiagonalDrag() throws {
        var workspace = try Workspace(
            blocks: [
                testBlock(id: "copyhistory"),
                testBlock(id: "codexlog", defaultSize: GridSize(width: 3, height: 2))
            ],
            layout: Layout(grid: Grid(columns: 12, rows: 8), blocks: [
                Block.Instance(id: "copyhistory", frame: GridFrame(x: 4, y: 3, width: 4, height: 3)),
                Block.Instance(id: "codexlog", frame: GridFrame(x: 0, y: 0, width: 3, height: 2))
            ])
        )

        try workspace.moveBlock("codexlog", to: GridPoint(x: 5, y: 4))

        #expect(workspace.layout.blocks.first(where: { $0.id == "codexlog" })?.frame == GridFrame(x: 1, y: 1, width: 3, height: 2))
    }

    @Test func disablingAndReenablingBlockPreservesPlacement() throws {
        var workspace = try Workspace(
            blocks: [testBlock(id: "copyhistory")],
            layout: Layout(blocks: [
                Block.Instance(id: "copyhistory", frame: GridFrame(x: 5, y: 2, width: 4, height: 3))
            ])
        )

        try workspace.setEnabled(false, for: "copyhistory")
        try workspace.setEnabled(true, for: "copyhistory")

        #expect(workspace.layout.blocks.count == 1)
        #expect(workspace.layout.blocks[0].enabled)
        #expect(workspace.layout.blocks[0].frame == GridFrame(x: 5, y: 2, width: 4, height: 3))
    }

    @Test func reenablingBlockMovesToOpenSlotWhenSavedPlacementIsOccupied() throws {
        var workspace = try Workspace(
            blocks: [
                testBlock(id: "copyhistory"),
                testBlock(id: "codexlog")
            ],
            layout: Layout(grid: Grid(columns: 8, rows: 4), blocks: [
                Block.Instance(id: "copyhistory", enabled: false, frame: GridFrame(x: 0, y: 0, width: 4, height: 2)),
                Block.Instance(id: "codexlog", enabled: true, frame: GridFrame(x: 0, y: 0, width: 4, height: 2))
            ])
        )

        try workspace.setEnabled(true, for: "copyhistory")

        #expect(workspace.layout.blocks.first(where: { $0.id == "copyhistory" })?.frame == GridFrame(x: 4, y: 0, width: 4, height: 2))
    }

    @Test func disabledBlocksDoNotReserveAutoPlacementSpace() throws {
        let layout = Layout(grid: Grid(columns: 8, rows: 4), blocks: [
            Block.Instance(id: "copyhistory", enabled: false, frame: GridFrame(x: 0, y: 0, width: 4, height: 2))
        ])

        #expect(layout.nextFrame(size: GridSize(width: 4, height: 2)) == GridFrame(x: 0, y: 0, width: 4, height: 2))
    }

    @Test func enabledBlocksReserveAutoPlacementSpace() throws {
        let layout = Layout(grid: Grid(columns: 8, rows: 4), blocks: [
            Block.Instance(id: "copyhistory", enabled: true, frame: GridFrame(x: 0, y: 0, width: 4, height: 2))
        ])

        #expect(layout.nextFrame(size: GridSize(width: 4, height: 2)) == GridFrame(x: 4, y: 0, width: 4, height: 2))
    }

    @Test func autoPlacementWrapsToNextRowWhenWidthDoesNotFit() {
        let layout = Layout(grid: Grid(columns: 6, rows: 4), blocks: [
            Block.Instance(id: "left", enabled: true, frame: GridFrame(x: 0, y: 0, width: 4, height: 1))
        ])

        #expect(layout.nextFrame(size: GridSize(width: 3, height: 1)) == GridFrame(x: 0, y: 1, width: 3, height: 1))
    }

    @Test func autoPlacementAvoidsVerticalIntersection() {
        let layout = Layout(grid: Grid(columns: 6, rows: 4), blocks: [
            Block.Instance(id: "tall", enabled: true, frame: GridFrame(x: 0, y: 0, width: 2, height: 3))
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

    @Test func layoutRoundTripsThroughJSON() throws {
        let layout = Layout(blocks: [
            Block.Instance(id: "quicksave", enabled: true, frame: GridFrame(x: 2, y: 1, width: 8, height: 2))
        ])

        let data = try Store.encode(layout)
        let decoded = try Store.decode(data)

        #expect(decoded == layout)
    }

    @Test func disabledBlockPlacementRoundTripsThroughJSON() throws {
        let layout = Layout(blocks: [
            Block.Instance(id: "copyhistory", enabled: false, frame: GridFrame(x: 3, y: 2, width: 4, height: 3))
        ])

        var workspace = try Workspace(
            blocks: [testBlock(id: "copyhistory")],
            layout: try Store.decode(try Store.encode(layout))
        )
        try workspace.setEnabled(true, for: "copyhistory")

        #expect(workspace.layout.blocks[0].enabled)
        #expect(workspace.layout.blocks[0].frame == GridFrame(x: 3, y: 2, width: 4, height: 3))
    }

    @Test func localCommandFindsExecutablesFromPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("surface-local-command-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("surface-test-tool")
        try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        #expect(LocalCommand.executablePath("surface-test-tool", environment: ["PATH": directory.path]) == executable.path)
    }

    @Test func localCommandRunsAndReportsMissingExecutables() throws {
        #expect(try LocalCommand.run(["/bin/echo", "surface"]) == "surface\n")
        #expect(throws: LocalCommand.Failure.missingExecutable("surface-definitely-missing-command")) {
            try LocalCommand.run(["surface-definitely-missing-command"])
        }
    }
}

private func testBlock(id: BlockID, title: String? = nil, defaultSize: GridSize = GridSize(width: 4, height: 3)) -> Block {
    Block(id: id, title: title ?? id.rawValue, defaultSize: defaultSize) { _ in
        TestRuntime()
    }
}

@MainActor
private final class TestRuntime: BlockRuntime {
    func start() {}
    func stop() {}
    func refresh() async {}
    func makeView() -> AnyView {
        AnyView(EmptyView())
    }
}
