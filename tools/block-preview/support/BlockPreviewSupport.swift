import AppKit
import Blocks
import Core
import Foundation
import SwiftUI
import UI

public struct BlockPreviewCase: Hashable, Sendable {
    public var blockID: BlockID
    public var fixture: String
    public var size: CGSize

    public init(blockID: BlockID, fixture: String, size: CGSize) {
        self.blockID = blockID
        self.fixture = fixture
        self.size = size
    }

    public var fileName: String {
        "\(blockID.rawValue)-\(fixture).png"
    }
}

public struct BlockPreviewResult: Sendable {
    public var previewCase: BlockPreviewCase
    public var url: URL
    public var metrics: BlockPreviewMetrics
}

public struct BlockPreviewMetrics: Sendable {
    public var width: Int
    public var height: Int
    public var byteCount: Int
    public var distinctSampledColors: Int
    public var nonBackgroundSampleCount: Int

    public var isVisuallyNonBlank: Bool {
        byteCount > 1_000 && distinctSampledColors >= 8 && nonBackgroundSampleCount >= 40
    }
}

public enum BlockPreview {
    public static let defaultOutputDirectory = URL(fileURLWithPath: ".build/block-previews", isDirectory: true)
    public static let cases: [BlockPreviewCase] = [
        BlockPreviewCase(blockID: "quicksave", fixture: "empty", size: CGSize(width: 420, height: 520)),
        BlockPreviewCase(blockID: "quicksave", fixture: "notes-and-captures", size: CGSize(width: 420, height: 520)),
        BlockPreviewCase(blockID: "copyhistory", fixture: "empty", size: CGSize(width: 420, height: 420)),
        BlockPreviewCase(blockID: "copyhistory", fixture: "mixed-clipboard", size: CGSize(width: 420, height: 420)),
        BlockPreviewCase(blockID: "codexlog", fixture: "empty", size: CGSize(width: 520, height: 360)),
        BlockPreviewCase(blockID: "codexlog", fixture: "active-thread", size: CGSize(width: 520, height: 360))
    ]

    @MainActor
    public static func render(
        blockID: BlockID,
        fixture: String,
        size: CGSize,
        outputDirectory: URL = defaultOutputDirectory
    ) throws -> BlockPreviewResult {
        guard let block = Blocks.registry.block(for: blockID) else {
            throw BlockPreviewError.unknownBlock(blockID.rawValue)
        }

        let fixtureContext = try BlockPreviewFixture.make(blockID: blockID, fixture: fixture)
        let runtime = block.makeRuntime(
            Block.Context(
                storageDirectory: fixtureContext.storageDirectory,
                now: fixtureContext.now
            )
        )
        runtime.start()
        defer { runtime.stop() }

        let previewCase = BlockPreviewCase(blockID: blockID, fixture: fixture, size: size)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let url = outputDirectory.appendingPathComponent(previewCase.fileName)
        let view = BlockChrome(title: block.title) {
            runtime.makeView()
        }
        .frame(width: size.width, height: size.height)
        .background(Style.previewBackground)

        let data = try BlockImageRenderer.pngData(for: AnyView(view), size: size)
        try data.write(to: url, options: [.atomic])

        return BlockPreviewResult(
            previewCase: previewCase,
            url: url,
            metrics: try BlockPreviewMetricsReader.metrics(forPNG: url)
        )
    }

    @MainActor
    public static func renderAll(outputDirectory: URL = defaultOutputDirectory) throws -> [BlockPreviewResult] {
        try cases.map {
            try render(
                blockID: $0.blockID,
                fixture: $0.fixture,
                size: $0.size,
                outputDirectory: outputDirectory
            )
        }
    }
}

enum BlockPreviewFixture {
    static let fixedNow = Date(timeIntervalSince1970: 1_764_077_400)

    static func make(blockID: BlockID, fixture: String) throws -> FixtureContext {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("surface-block-preview", isDirectory: true)
            .appendingPathComponent(blockID.rawValue, isDirectory: true)
            .appendingPathComponent(fixture, isDirectory: true)

        try FileManager.default.removeItemIfExists(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        switch (blockID.rawValue, fixture) {
        case ("quicksave", "empty"):
            break
        case ("quicksave", "notes-and-captures"):
            try makeQuicksaveFixture(in: directory)
        case ("copyhistory", "empty"), ("copyhistory", "mixed-clipboard"):
            break
        case ("codexlog", "empty"), ("codexlog", "active-thread"):
            break
        default:
            throw BlockPreviewError.unknownFixture("\(blockID.rawValue)/\(fixture)")
        }

        return FixtureContext(storageDirectory: directory, now: fixedNow)
    }

    private static func makeQuicksaveFixture(in directory: URL) throws {
        let capture = directory.appendingPathComponent("2026-05-19T13-30-00.000Z.txt")
        let note = directory.appendingPathComponent("2026-05-19T13-30-00.000Z.note.txt")
        let standalone = directory.appendingPathComponent("2026-05-19T14-05-00.000Z-note.txt")

        try "Captured text preview from the clipboard.".write(to: capture, atomically: true, encoding: .utf8)
        try "Follow up on the captured text.".write(to: note, atomically: true, encoding: .utf8)
        try "Standalone note for the daily quicksave stream.".write(to: standalone, atomically: true, encoding: .utf8)

        for url in [capture, note, standalone] {
            try FileManager.default.setAttributes([.modificationDate: fixedNow], ofItemAtPath: url.path)
        }
    }
}

public enum BlockImageRenderer {
    @MainActor
    public static func pngData(for view: AnyView, size: CGSize) throws -> Data {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        host.setFrameSize(size)
        host.layoutSubtreeIfNeeded()

        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw BlockPreviewError.renderFailed("Could not allocate bitmap.")
        }

        bitmap.size = size
        host.cacheDisplay(in: host.bounds, to: bitmap)

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw BlockPreviewError.renderFailed("Could not encode PNG.")
        }
        return data
    }
}

public enum BlockPreviewMetricsReader {
    public static func metrics(forPNG url: URL) throws -> BlockPreviewMetrics {
        let data = try Data(contentsOf: url)
        guard let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            throw BlockPreviewError.renderFailed("Could not read PNG metrics.")
        }

        let background = sampledColor(bitmap, x: 0, y: 0)
        var colors = Set<Int>()
        var nonBackground = 0
        let stepX = max(1, bitmap.pixelsWide / 32)
        let stepY = max(1, bitmap.pixelsHigh / 32)

        for y in stride(from: 0, to: bitmap.pixelsHigh, by: stepY) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: stepX) {
                let color = sampledColor(bitmap, x: x, y: y)
                colors.insert(color)
                if colorDistance(color, background) > 18 {
                    nonBackground += 1
                }
            }
        }

        return BlockPreviewMetrics(
            width: bitmap.pixelsWide,
            height: bitmap.pixelsHigh,
            byteCount: data.count,
            distinctSampledColors: colors.count,
            nonBackgroundSampleCount: nonBackground
        )
    }

    private static func sampledColor(_ bitmap: NSBitmapImageRep, x: Int, y: Int) -> Int {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
            return 0
        }

        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return (red << 16) | (green << 8) | blue
    }

    private static func colorDistance(_ lhs: Int, _ rhs: Int) -> Int {
        let lr = (lhs >> 16) & 0xff
        let lg = (lhs >> 8) & 0xff
        let lb = lhs & 0xff
        let rr = (rhs >> 16) & 0xff
        let rg = (rhs >> 8) & 0xff
        let rb = rhs & 0xff
        return abs(lr - rr) + abs(lg - rg) + abs(lb - rb)
    }
}

public enum BlockPreviewError: Error, CustomStringConvertible {
    case unknownBlock(String)
    case unknownFixture(String)
    case renderFailed(String)

    public var description: String {
        switch self {
        case .unknownBlock(let id):
            "Unknown block: \(id)"
        case .unknownFixture(let fixture):
            "Unknown fixture: \(fixture)"
        case .renderFailed(let message):
            "Render failed: \(message)"
        }
    }
}

struct FixtureContext {
    var storageDirectory: URL
    var now: Date
}

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
    }
}
