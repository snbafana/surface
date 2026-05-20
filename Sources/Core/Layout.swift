import CoreGraphics
import Foundation

public struct GridPoint: Hashable, Codable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct GridSize: Hashable, Codable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
    }
}

public struct GridFrame: Hashable, Codable, Sendable {
    public var origin: GridPoint
    public var size: GridSize

    public init(x: Int, y: Int, width: Int, height: Int) {
        origin = GridPoint(x: x, y: y)
        size = GridSize(width: width, height: height)
    }

    public init(origin: GridPoint, size: GridSize) {
        self.origin = origin
        self.size = size
    }
}

public struct Grid: Hashable, Codable, Sendable {
    public var columns: Int
    public var rows: Int

    public init(columns: Int = 12, rows: Int = 8) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
    }

    public func contains(_ frame: GridFrame) -> Bool {
        frame.origin.x >= 0 &&
            frame.origin.y >= 0 &&
            frame.origin.x + frame.size.width <= columns &&
            frame.origin.y + frame.size.height <= rows
    }

    public func clamped(origin: GridPoint, size: GridSize) -> GridPoint {
        let size = clamped(size: size)
        return GridPoint(
            x: min(max(0, origin.x), max(0, columns - size.width)),
            y: min(max(0, origin.y), max(0, rows - size.height))
        )
    }

    public func clamped(size: GridSize) -> GridSize {
        GridSize(width: min(size.width, columns), height: min(size.height, rows))
    }

    public func frame(for point: GridPoint, size: GridSize) -> GridFrame {
        let size = clamped(size: size)
        return GridFrame(origin: clamped(origin: point, size: size), size: size)
    }
}

public struct Layout: Hashable, Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var grid: Grid
    public var blocks: [Block.Instance]

    public init(id: String = "default", title: String = "Default", grid: Grid = Grid(), blocks: [Block.Instance] = []) {
        self.id = id
        self.title = title
        self.grid = grid
        self.blocks = blocks
    }

    public func nextFrame(size: GridSize, excluding excludedID: BlockID? = nil) -> GridFrame {
        for y in 0..<grid.rows {
            for x in 0..<grid.columns {
                let frame = grid.frame(for: GridPoint(x: x, y: y), size: size)
                if grid.contains(frame), !intersectsEnabledBlock(frame, excluding: excludedID) {
                    return frame
                }
            }
        }
        return grid.frame(for: GridPoint(x: 0, y: 0), size: size)
    }

    func nearestFrame(from start: GridFrame, to point: GridPoint, excluding excludedID: BlockID? = nil) -> GridFrame {
        let target = grid.frame(for: point, size: start.size)
        let dx = target.origin.x - start.origin.x
        let dy = target.origin.y - start.origin.y
        let steps = max(abs(dx), abs(dy))
        guard steps > 0 else { return start }

        var nearest = start
        var seen = Set<GridPoint>()
        for step in 1...steps {
            let progress = Double(step) / Double(steps)
            let point = GridPoint(
                x: start.origin.x + Int((Double(dx) * progress).rounded()),
                y: start.origin.y + Int((Double(dy) * progress).rounded())
            )
            guard seen.insert(point).inserted else { continue }

            let frame = grid.frame(for: point, size: start.size)
            if !intersectsEnabledBlock(frame, excluding: excludedID) {
                nearest = frame
            }
        }
        return nearest
    }

    public func intersectsEnabledBlock(_ frame: GridFrame, excluding excludedID: BlockID? = nil) -> Bool {
        blocks.contains { block in
            block.enabled && block.id != excludedID && block.frame.intersects(frame)
        }
    }
}

public extension GridFrame {
    func intersects(_ other: GridFrame) -> Bool {
        origin.x < other.origin.x + other.size.width &&
            origin.x + size.width > other.origin.x &&
            origin.y < other.origin.y + other.size.height &&
            origin.y + size.height > other.origin.y
    }
}

public enum SurfaceLayout {
    public static let cardGap: CGFloat = 8
    public static let previewCanvasSize = CGSize(width: 1440, height: 900)

    public static let defaultLayout = Layout(grid: Grid(columns: 24, rows: 16), blocks: [
        Block.Instance(id: "quicksave", frame: GridFrame(x: 1, y: 1, width: 10, height: 5)),
        Block.Instance(id: "copyhistory", frame: GridFrame(x: 12, y: 1, width: 8, height: 8)),
        Block.Instance(id: "codexlog", frame: GridFrame(x: 15, y: 9, width: 8, height: 7))
    ])

    public static func workspace(registry: BlockRegistry) throws -> Workspace {
        try Workspace(blocks: registry.blocks, layout: defaultLayout)
    }

    public static func rect(for frame: GridFrame, grid: Grid, in container: CGSize) -> CGRect {
        let cellWidth = container.width / CGFloat(grid.columns)
        let cellHeight = container.height / CGFloat(grid.rows)
        return CGRect(
            x: CGFloat(frame.origin.x) * cellWidth + cardGap / 2,
            y: CGFloat(frame.origin.y) * cellHeight + cardGap / 2,
            width: CGFloat(frame.size.width) * cellWidth - cardGap,
            height: CGFloat(frame.size.height) * cellHeight - cardGap
        )
    }

    public static func rect(for instance: Block.Instance, in container: CGSize) -> CGRect {
        rect(for: instance.frame, grid: defaultLayout.grid, in: container)
    }

    public static func defaultRect(for blockID: BlockID, in container: CGSize = previewCanvasSize) -> CGRect? {
        defaultLayout.blocks
            .first { $0.id == blockID }
            .map { rect(for: $0, in: container) }
    }
}
