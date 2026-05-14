import Foundation

public enum SurfaceStore {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    public static let decoder = JSONDecoder()

    public static func encode(_ document: SurfaceDocument) throws -> Data {
        try encoder.encode(document)
    }

    public static func decode(_ data: Data) throws -> SurfaceDocument {
        try decoder.decode(SurfaceDocument.self, from: data)
    }
}
