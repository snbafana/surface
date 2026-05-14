import Foundation

public enum Store {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    public static let decoder = JSONDecoder()

    public static func encode(_ workspace: Workspace) throws -> Data {
        try encoder.encode(workspace)
    }

    public static func decode(_ data: Data) throws -> Workspace {
        try decoder.decode(Workspace.self, from: data)
    }
}
