import Foundation

public enum LocalCommand {
    public enum Failure: Error, Equatable {
        case emptyCommand
        case missingExecutable(String)
        case commandFailed(Int32)
    }

    public static func run(_ arguments: [String]) throws -> String {
        guard let command = arguments.first else {
            throw Failure.emptyCommand
        }
        guard let executable = executablePath(command) else {
            throw Failure.missingExecutable(command)
        }

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(arguments.dropFirst())
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure.commandFailed(process.terminationStatus)
        }
        return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    public static func executablePath(_ name: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        if name.contains("/") {
            return FileManager.default.isExecutableFile(atPath: name) ? name : nil
        }

        for directory in searchDirectories(environment: environment) {
            let path = URL(fileURLWithPath: directory).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private static func searchDirectories(environment: [String: String]) -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fixed = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        let path = environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []
        return unique(fixed + path)
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
