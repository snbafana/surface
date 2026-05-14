import Foundation

public struct SurfaceProviderDescriptor: Hashable, Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var blockIDs: [BlockID]

    public init(id: String, title: String, blockIDs: [BlockID]) {
        self.id = id
        self.title = title
        self.blockIDs = blockIDs
    }
}

public struct SurfaceCatalog: Hashable, Codable, Sendable {
    public var providers: [SurfaceProviderDescriptor]
    public var blocks: [BlockDefinition]

    public init(providers: [SurfaceProviderDescriptor], blocks: [BlockDefinition]) {
        self.providers = providers
        self.blocks = blocks
    }
}
