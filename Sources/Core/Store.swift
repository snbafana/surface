import Foundation

public enum Store {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    public static let decoder = JSONDecoder()

    public static func encode(_ document: Document) throws -> Data {
        try encoder.encode(document)
    }

    public static func decode(_ data: Data) throws -> Document {
        try decoder.decode(Document.self, from: data)
    }
}
