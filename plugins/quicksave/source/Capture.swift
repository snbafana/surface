import AppKit
import Foundation

struct CaptureResult: Sendable {
    let savedURLs: [URL]

    var firstSavedURL: URL? {
        savedURLs.first
    }
}

final class ClipboardCapture {
    private enum PasteboardType {
        static let pdf = NSPasteboard.PasteboardType("com.adobe.pdf")
        static let fileURL = NSPasteboard.PasteboardType("public.file-url")
        static let html = NSPasteboard.PasteboardType("public.html")
        static let rtf = NSPasteboard.PasteboardType("public.rtf")
        static let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.heic")
        ]
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func captureClipboard(to inboxDirectory: URL, pasteboard: NSPasteboard = .general) throws -> CaptureResult {
        try fileManager.createDirectory(at: inboxDirectory, withIntermediateDirectories: true)

        let items = pasteboard.pasteboardItems ?? []
        var saved: [URL] = []

        for (offset, item) in items.enumerated() {
            if let url = try saveItem(item, itemIndex: offset + 1, itemCount: items.count, to: inboxDirectory) {
                saved.append(url)
            }
        }

        if saved.isEmpty {
            throw ClipboardCaptureError.noSupportedClipboardContent
        }

        return CaptureResult(savedURLs: saved)
    }

    private func saveItem(_ item: NSPasteboardItem, itemIndex: Int, itemCount: Int, to inboxDirectory: URL) throws -> URL? {
        let stem = fileStem(itemIndex: itemIndex, itemCount: itemCount)

        if let fileURL = fileURL(from: item) {
            let destination = FileNaming.uniqueURL(
                in: inboxDirectory,
                preferredName: "\(stem)-\(fileURL.lastPathComponent)",
                fileManager: fileManager
            )
            try fileManager.copyItem(at: fileURL, to: destination)
            return destination
        }

        if let pdf = item.data(forType: PasteboardType.pdf), !pdf.isEmpty {
            let destination = FileNaming.uniqueURL(
                in: inboxDirectory,
                preferredName: "\(stem).pdf",
                fileManager: fileManager
            )
            try pdf.write(to: destination, options: [.atomic])
            return destination
        }

        if let image = image(from: item), let png = pngData(from: image) {
            let destination = FileNaming.uniqueURL(
                in: inboxDirectory,
                preferredName: "\(stem).png",
                fileManager: fileManager
            )
            try png.write(to: destination, options: [.atomic])
            return destination
        }

        if let text = text(from: item), !text.value.isEmpty {
            let destination = FileNaming.uniqueURL(
                in: inboxDirectory,
                preferredName: "\(stem).\(text.fileExtension)",
                fileManager: fileManager
            )
            try Data(text.value.utf8).write(to: destination, options: [.atomic])
            return destination
        }

        return nil
    }

    private func text(from item: NSPasteboardItem) -> CapturedText? {
        if let markdown = markdownText(from: item), !markdown.isEmpty {
            return CapturedText(value: markdown, fileExtension: "md")
        }
        if let text = item.string(forType: .string), !text.isEmpty {
            return CapturedText(value: text, fileExtension: "txt")
        }
        if let url = item.string(forType: .URL), !url.isEmpty {
            return CapturedText(value: url, fileExtension: "txt")
        }
        return nil
    }

    private func markdownText(from item: NSPasteboardItem) -> String? {
        if let html = item.data(forType: PasteboardType.html),
           let attributed = attributedString(from: html, type: .html) {
            return markdown(from: attributed)
        }

        if let rtf = item.data(forType: PasteboardType.rtf),
           let attributed = attributedString(from: rtf, type: .rtf) {
            return markdown(from: attributed)
        }

        return nil
    }

    private func attributedString(from data: Data, type: NSAttributedString.DocumentType) -> NSAttributedString? {
        try? NSAttributedString(
            data: data,
            options: [
                .documentType: type,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }

    private func markdown(from attributed: NSAttributedString) -> String {
        var result = ""
        let range = NSRange(location: 0, length: attributed.length)

        attributed.enumerateAttributes(in: range) { attributes, range, _ in
            let text = attributed.attributedSubstring(from: range).string
            guard !text.isEmpty else {
                return
            }

            if let link = attributes[.link] {
                result += "[\(text)](\(link))"
            } else {
                result += text
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fileURL(from item: NSPasteboardItem) -> URL? {
        if let string = item.string(forType: .fileURL), let url = URL(string: string), url.isFileURL {
            return url
        }

        if let string = item.string(forType: PasteboardType.fileURL),
           let url = URL(string: string),
           url.isFileURL {
            return url
        }

        return nil
    }

    private func image(from item: NSPasteboardItem) -> NSImage? {
        for type in PasteboardType.imageTypes {
            if let data = item.data(forType: type), let image = NSImage(data: data) {
                return image
            }
        }

        return nil
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func fileStem(itemIndex: Int, itemCount: Int) -> String {
        let timestamp = FileNaming.timestamp()
        if itemCount <= 1 {
            return timestamp
        }
        return "\(timestamp)-\(String(format: "%02d", itemIndex))"
    }
}

private struct CapturedText {
    let value: String
    let fileExtension: String
}

enum ClipboardCaptureError: LocalizedError {
    case noSupportedClipboardContent

    var errorDescription: String? {
        switch self {
        case .noSupportedClipboardContent:
            "No supported clipboard content found."
        }
    }
}

enum FileNaming {
    static func timestamp(_ date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date).replacingOccurrences(of: ":", with: "-")
    }

    static func uniqueURL(in directory: URL, preferredName: String, fileManager: FileManager = .default) -> URL {
        let cleanName = sanitizeFileName(preferredName)
        var candidate = directory.appendingPathComponent(cleanName)
        let pathExtension = candidate.pathExtension
        let stem = candidate.deletingPathExtension().lastPathComponent
        var counter = 2

        while fileManager.fileExists(atPath: candidate.path) {
            let name = pathExtension.isEmpty ? "\(stem)-\(counter)" : "\(stem)-\(counter).\(pathExtension)"
            candidate = directory.appendingPathComponent(name)
            counter += 1
        }

        return candidate
    }

    private static func sanitizeFileName(_ raw: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:")
        let scalars = raw.unicodeScalars.map { illegal.contains($0) ? Character("-") : Character($0) }
        let value = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "capture" : value
    }
}
