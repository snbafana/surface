import Foundation

struct QuicksaveSettings {
    private static let inboxPathKey = "inboxPath"

    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "com.snbafana.quicksave") ?? .standard
    }

    static func defaultInboxURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Quicksave Inbox", isDirectory: true)
    }

    static func inboxURL(defaults: UserDefaults = QuicksaveSettings.sharedDefaults()) -> URL {
        storedURL(forKey: inboxPathKey, defaultURL: defaultInboxURL(), defaults: defaults)
    }

    static func setInboxURL(_ url: URL, defaults: UserDefaults = QuicksaveSettings.sharedDefaults()) {
        defaults.set(url.path, forKey: inboxPathKey)
    }

    private static func storedURL(forKey key: String, defaultURL: URL, defaults: UserDefaults) -> URL {
        guard let path = defaults.string(forKey: key), !path.isEmpty else {
            return defaultURL
        }
        return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: true)
    }
}

final class ContextNoteWriter {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    static func isNoteFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasSuffix(".note.txt") || name.hasSuffix("-note.txt") {
            return true
        }
        return name.range(of: #"(\.note|-note)-\d+\.txt$"#, options: .regularExpression) != nil
    }

    static func noteText(for captureURL: URL, fileManager: FileManager = .default) throws -> String? {
        let sidecars = try noteURLs(for: captureURL, fileManager: fileManager)
        let notes = try sidecars.map { try String(contentsOf: $0, encoding: .utf8) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !notes.isEmpty else {
            return nil
        }
        return notes.joined(separator: "\n\n")
    }

    static func noteURLs(for captureURL: URL, fileManager: FileManager = .default) throws -> [URL] {
        let directory = captureURL.deletingLastPathComponent()
        let stem = captureURL.deletingPathExtension().lastPathComponent
        let prefix = "\(stem).note"
        let sidecarPattern = #"^\#(NSRegularExpression.escapedPattern(for: prefix))(-\d+)?\.txt$"#

        let regex = try NSRegularExpression(pattern: sidecarPattern)
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            let name = url.lastPathComponent
            let range = NSRange(location: 0, length: (name as NSString).length)
            return regex.firstMatch(in: name, range: range) != nil
        }
        .sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if lhsDate == rhsDate {
                return lhs.lastPathComponent < rhs.lastPathComponent
            }
            return lhsDate < rhsDate
        }
    }

    func save(note: String, for savedURLs: [URL], in inboxDirectory: URL, now: Date = Date()) throws -> URL {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ContextNoteError.emptyNote
        }

        try fileManager.createDirectory(at: inboxDirectory, withIntermediateDirectories: true)
        let destination = FileNaming.uniqueURL(
            in: inboxDirectory,
            preferredName: noteFileName(for: savedURLs, now: now),
            fileManager: fileManager
        )
        try Data(trimmed.utf8).write(to: destination, options: [.atomic])
        try fileManager.setAttributes([.modificationDate: now], ofItemAtPath: destination.path)
        return destination
    }

    private func noteFileName(for savedURLs: [URL], now: Date) -> String {
        guard savedURLs.count == 1, let target = savedURLs.first else {
            return "\(FileNaming.timestamp(now))-note.txt"
        }

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: target.path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue {
            return "\(target.lastPathComponent).note.txt"
        }

        let stem = target.deletingPathExtension().lastPathComponent
        return "\(stem).note.txt"
    }
}

enum ContextNoteError: LocalizedError {
    case emptyNote

    var errorDescription: String? {
        switch self {
        case .emptyNote:
            "No note entered."
        }
    }
}

struct QuicksaveNote: Identifiable, Equatable, Sendable {
    var id: URL { url }
    let url: URL
    let text: String
    let modifiedAt: Date
    let captureName: String?
    let captureURL: URL?
    let captureKind: String?
}

struct QuicksaveHistory {
    private let fileManager: FileManager
    private let calendar: Calendar

    init(fileManager: FileManager = .default, calendar: Calendar = .current) {
        self.fileManager = fileManager
        self.calendar = calendar
    }

    func todayNotes(in inboxDirectory: URL, now: Date = Date()) throws -> [QuicksaveNote] {
        guard fileManager.fileExists(atPath: inboxDirectory.path) else {
            return []
        }

        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now

        return try noteFiles(in: inboxDirectory)
            .filter { $0.modifiedAt >= start && $0.modifiedAt < end }
            .sorted { lhs, rhs in
                if lhs.modifiedAt == rhs.modifiedAt {
                    return lhs.url.lastPathComponent < rhs.url.lastPathComponent
                }
                return lhs.modifiedAt > rhs.modifiedAt
            }
    }

    private func noteFiles(in inboxDirectory: URL) throws -> [QuicksaveNote] {
        try fileManager.contentsOfDirectory(
            at: inboxDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter(ContextNoteWriter.isNoteFile)
        .compactMap { url in
            guard let modifiedAt = modificationDate(for: url),
                  let text = try? String(contentsOf: url, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return nil
            }
            let captureName = captureName(for: url)
            let captureURL = captureURL(in: inboxDirectory, captureName: captureName)
            return QuicksaveNote(
                url: url,
                text: text,
                modifiedAt: modifiedAt,
                captureName: captureName,
                captureURL: captureURL,
                captureKind: captureURL.map(captureKind)
            )
        }
    }

    private func modificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func captureName(for noteURL: URL) -> String? {
        let name = noteURL.lastPathComponent
        if name.hasSuffix(".note.txt") {
            return String(name.dropLast(".note.txt".count))
        }
        if let range = name.range(of: #"\.note-\d+\.txt$"#, options: .regularExpression) {
            return String(name[..<range.lowerBound])
        }
        return nil
    }

    private func captureURL(in inboxDirectory: URL, captureName: String?) -> URL? {
        guard let captureName else {
            return nil
        }

        return try? fileManager.contentsOfDirectory(
            at: inboxDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .first { url in
            !ContextNoteWriter.isNoteFile(url) && url.deletingPathExtension().lastPathComponent == captureName
        }
    }

    private func captureKind(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "heic", "tiff":
            return "image"
        case "pdf":
            return "pdf"
        case "md":
            return "markdown"
        case "txt":
            return "text"
        default:
            return url.pathExtension.isEmpty ? "file" : url.pathExtension.lowercased()
        }
    }
}
