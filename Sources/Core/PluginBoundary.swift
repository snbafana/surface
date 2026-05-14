import Foundation

public struct ProviderDescriptor: Hashable, Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var blockIDs: [BlockID]

    public init(id: String, title: String, blockIDs: [BlockID]) {
        self.id = id
        self.title = title
        self.blockIDs = blockIDs
    }
}

public struct Catalog: Hashable, Codable, Sendable {
    public var providers: [ProviderDescriptor]
    public var blocks: [BlockDefinition]

    public init(providers: [ProviderDescriptor], blocks: [BlockDefinition]) {
        self.providers = providers
        self.blocks = blocks
    }
}
