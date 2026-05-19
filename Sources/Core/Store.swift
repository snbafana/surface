import Foundation

public enum Store {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    public static let decoder = JSONDecoder()

    public static func encode(_ layout: Layout) throws -> Data {
        try encoder.encode(layout)
    }

    public static func decode(_ data: Data) throws -> Layout {
        try decoder.decode(Layout.self, from: data)
    }
}
