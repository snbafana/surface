import Foundation

public struct BlockID: Hashable, Codable, RawRepresentable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }
}

public struct BlockDefinition: Hashable, Codable, Identifiable, Sendable {
    public let id: BlockID
    public var title: String
    public var defaultSize: GridSize

    public init(id: BlockID, title: String, defaultSize: GridSize = GridSize(width: 4, height: 3)) {
        self.id = id
        self.title = title
        self.defaultSize = defaultSize
    }
}

public struct BlockInstance: Hashable, Codable, Identifiable, Sendable {
    public var id: BlockID
    public var enabled: Bool
    public var frame: GridFrame

    public init(id: BlockID, enabled: Bool = true, frame: GridFrame) {
        self.id = id
        self.enabled = enabled
        self.frame = frame
    }
}

public struct SurfaceDocument: Hashable, Codable, Sendable {
    public var definitions: [BlockDefinition]
    public var layout: SurfaceLayout

    public init(definitions: [BlockDefinition], layout: SurfaceLayout) throws {
        self.definitions = definitions
        self.layout = layout
        try validate()
    }

    public var enabledBlocks: [BlockInstance] {
        layout.blocks.filter(\.enabled)
    }

    public mutating func setEnabled(_ enabled: Bool, for id: BlockID) throws {
        guard let definition = definitions.first(where: { $0.id == id }) else {
            throw SurfaceModelError.unknownBlock(id.rawValue)
        }

        if let index = layout.blocks.firstIndex(where: { $0.id == id }) {
            layout.blocks[index].enabled = enabled
        } else {
            let frame = layout.nextFrame(size: definition.defaultSize)
            layout.blocks.append(BlockInstance(id: id, enabled: enabled, frame: frame))
        }
        try validate()
    }

    public mutating func moveBlock(_ id: BlockID, to origin: GridPoint) throws {
        guard let index = layout.blocks.firstIndex(where: { $0.id == id }) else {
            throw SurfaceModelError.unknownBlock(id.rawValue)
        }
        layout.blocks[index].frame = layout.grid.frame(for: origin, size: layout.blocks[index].frame.size)
        try validate()
    }

    public func validate() throws {
        let knownIDs = Set(definitions.map(\.id))
        guard knownIDs.count == definitions.count else {
            throw SurfaceModelError.duplicateDefinition
        }

        var instanceIDs = Set<BlockID>()
        for block in layout.blocks {
            guard knownIDs.contains(block.id) else {
                throw SurfaceModelError.unknownBlock(block.id.rawValue)
            }
            guard instanceIDs.insert(block.id).inserted else {
                throw SurfaceModelError.duplicateBlock(block.id.rawValue)
            }
            guard layout.grid.contains(block.frame) else {
                throw SurfaceModelError.blockOutsideGrid(block.id.rawValue)
            }
        }
    }
}

public enum SurfaceModelError: Error, Equatable, LocalizedError {
    case duplicateDefinition
    case duplicateBlock(String)
    case unknownBlock(String)
    case blockOutsideGrid(String)

    public var errorDescription: String? {
        switch self {
        case .duplicateDefinition:
            return "Block definitions must be unique."
        case .duplicateBlock(let id):
            return "Block `\(id)` appears more than once in the layout."
        case .unknownBlock(let id):
            return "Block `\(id)` has no definition."
        case .blockOutsideGrid(let id):
            return "Block `\(id)` is outside the layout grid."
        }
    }
}
