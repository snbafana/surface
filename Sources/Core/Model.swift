import Foundation
import SwiftUI

public struct BlockID: Hashable, Codable, RawRepresentable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }
}

public struct Block: Identifiable, Sendable {
    public struct Context: @unchecked Sendable {
        public weak var keyboardShortcuts: (any KeyboardShortcutRegistrar)?

        public init(keyboardShortcuts: (any KeyboardShortcutRegistrar)? = nil) {
            self.keyboardShortcuts = keyboardShortcuts
        }
    }

    public let id: BlockID
    public let title: String
    public let defaultSize: GridSize
    public let makeRuntime: @MainActor @Sendable (Context) -> any BlockRuntime

    public init(
        id: BlockID,
        title: String,
        defaultSize: GridSize = GridSize(width: 4, height: 3),
        makeRuntime: @escaping @MainActor @Sendable (Context) -> any BlockRuntime
    ) {
        self.id = id
        self.title = title
        self.defaultSize = defaultSize
        self.makeRuntime = makeRuntime
    }
}

public extension Block {
    struct Instance: Hashable, Codable, Identifiable, Sendable {
        public var id: BlockID
        public var enabled: Bool
        public var frame: GridFrame

        public init(id: BlockID, enabled: Bool = true, frame: GridFrame) {
            self.id = id
            self.enabled = enabled
            self.frame = frame
        }
    }
}

public struct KeyboardShortcut: Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public struct KeyboardShortcutToken: Hashable, Sendable {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

@MainActor
public protocol KeyboardShortcutRegistrar: AnyObject {
    @discardableResult
    func registerKeyboardShortcut(
        _ shortcut: KeyboardShortcut,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> KeyboardShortcutToken?

    func unregisterKeyboardShortcut(_ token: KeyboardShortcutToken)
}

@MainActor
public protocol BlockRuntime: AnyObject {
    func start()
    func stop()
    func refresh() async
    func makeView() -> AnyView
}

public struct BlockRegistry: Sendable {
    public let blocks: [Block]

    public init(_ blocks: [Block]) throws {
        var ids = Set<BlockID>()
        for block in blocks {
            guard ids.insert(block.id).inserted else {
                throw ModelError.duplicateBlock(block.id.rawValue)
            }
        }
        self.blocks = blocks
    }

    public func block(for id: BlockID) -> Block? {
        blocks.first { $0.id == id }
    }
}

public struct Workspace: Sendable {
    public var blocks: [Block]
    public var layout: Layout

    public init(blocks: [Block], layout: Layout) throws {
        self.blocks = blocks
        self.layout = layout
        try validate()
    }

    public var enabledBlocks: [Block.Instance] {
        layout.blocks.filter(\.enabled)
    }

    public mutating func setEnabled(_ enabled: Bool, for id: BlockID) throws {
        guard let block = blocks.first(where: { $0.id == id }) else {
            throw ModelError.unknownBlock(id.rawValue)
        }

        if let index = layout.blocks.firstIndex(where: { $0.id == id }) {
            layout.blocks[index].enabled = enabled
            if enabled && layout.intersectsEnabledBlock(layout.blocks[index].frame, excluding: id) {
                layout.blocks[index].frame = layout.nextFrame(size: layout.blocks[index].frame.size, excluding: id)
            }
        } else {
            let frame = layout.nextFrame(size: block.defaultSize)
            layout.blocks.append(Block.Instance(id: id, enabled: enabled, frame: frame))
        }
        try validate()
    }

    public mutating func moveBlock(_ id: BlockID, to origin: GridPoint) throws {
        guard let index = layout.blocks.firstIndex(where: { $0.id == id }) else {
            throw ModelError.unknownBlock(id.rawValue)
        }
        layout.blocks[index].frame = layout.nearestFrame(
            from: layout.blocks[index].frame,
            to: origin,
            excluding: id
        )
        try validate()
    }

    public func validate() throws {
        var knownIDs = Set<BlockID>()
        for block in blocks {
            guard knownIDs.insert(block.id).inserted else {
                throw ModelError.duplicateBlock(block.id.rawValue)
            }
        }

        var instanceIDs = Set<BlockID>()
        for block in layout.blocks {
            guard knownIDs.contains(block.id) else {
                throw ModelError.unknownBlock(block.id.rawValue)
            }
            guard instanceIDs.insert(block.id).inserted else {
                throw ModelError.duplicateBlock(block.id.rawValue)
            }
            guard layout.grid.contains(block.frame) else {
                throw ModelError.blockOutsideGrid(block.id.rawValue)
            }
        }

        let enabledBlocks = layout.blocks.filter(\.enabled)
        for index in enabledBlocks.indices {
            for otherIndex in enabledBlocks.indices.dropFirst(index + 1) {
                if enabledBlocks[index].frame.intersects(enabledBlocks[otherIndex].frame) {
                    throw ModelError.overlappingBlocks(
                        enabledBlocks[index].id.rawValue,
                        enabledBlocks[otherIndex].id.rawValue
                    )
                }
            }
        }
    }
}

public enum ModelError: Error, Equatable, LocalizedError {
    case duplicateBlock(String)
    case unknownBlock(String)
    case blockOutsideGrid(String)
    case overlappingBlocks(String, String)

    public var errorDescription: String? {
        switch self {
        case .duplicateBlock(let id):
            return "Block `\(id)` appears more than once."
        case .unknownBlock(let id):
            return "Block `\(id)` has no definition."
        case .blockOutsideGrid(let id):
            return "Block `\(id)` is outside the layout grid."
        case .overlappingBlocks(let first, let second):
            return "Blocks `\(first)` and `\(second)` overlap."
        }
    }
}
