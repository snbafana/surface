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

public struct SurfacePreviewResult: Sendable {
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
    private static let caseFixtures: [(BlockID, [String])] = [
        ("quicksave", ["empty", "notes-and-captures"]),
        ("copyhistory", ["empty", "mixed-clipboard"]),
        ("codexlog", ["empty", "active-thread"])
    ]

    private static let surfaceFixtures: [BlockID: String] = [
        "quicksave": "notes-and-captures",
        "copyhistory": "mixed-clipboard",
        "codexlog": "active-thread"
    ]

    public static let cases: [BlockPreviewCase] = caseFixtures.flatMap { blockID, fixtures in
        fixtures.map { fixture in
            BlockPreviewCase(blockID: blockID, fixture: fixture, size: defaultSize(for: blockID))
        }
    }

    public static func defaultSize(for blockID: BlockID, in container: CGSize = SurfaceLayout.previewCanvasSize) -> CGSize {
        SurfaceLayout.defaultRect(for: blockID, in: container)?.size ?? CGSize(width: 420, height: 420)
    }

    public static func liveCanvasSize() -> CGSize {
        NSScreen.main?.visibleFrame.size ?? SurfaceLayout.previewCanvasSize
    }

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

    @MainActor
    public static func renderSurface(
        size: CGSize = liveCanvasSize(),
        outputDirectory: URL = defaultOutputDirectory
    ) throws -> SurfacePreviewResult {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let url = outputDirectory.appendingPathComponent("surface-active.png")
        var runtimes: [any BlockRuntime] = []
        defer {
            for runtime in runtimes {
                runtime.stop()
            }
        }

        let blocks = try SurfaceLayout.defaultLayout.blocks.compactMap { instance -> SurfacePreviewBlock? in
            guard instance.enabled,
                  let block = Blocks.registry.block(for: instance.id) else {
                return nil
            }

            let fixture = surfaceFixtures[instance.id] ?? "empty"
            let fixtureContext = try BlockPreviewFixture.make(blockID: instance.id, fixture: fixture)
            let runtime = block.makeRuntime(
                Block.Context(
                    storageDirectory: fixtureContext.storageDirectory,
                    now: fixtureContext.now
                )
            )
            runtime.start()
            runtimes.append(runtime)

            return SurfacePreviewBlock(
                id: instance.id,
                title: block.title,
                rect: SurfaceLayout.rect(for: instance.frame, grid: SurfaceLayout.defaultLayout.grid, in: size),
                content: runtime.makeView()
            )
        }

        let view = SurfacePreviewCanvas(blocks: blocks, size: size)
        let data = try BlockImageRenderer.pngData(
            for: AnyView(view),
            size: size
        )
        try data.write(to: url, options: [.atomic])

        return SurfacePreviewResult(
            url: url,
            metrics: try BlockPreviewMetricsReader.metrics(forPNG: url)
        )
    }
}

private struct SurfacePreviewBlock: Identifiable {
    var id: BlockID
    var title: String
    var rect: CGRect
    var content: AnyView
}

private struct SurfacePreviewCanvas: View {
    var blocks: [SurfacePreviewBlock]
    var size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            Style.previewBackground
                .ignoresSafeArea()

            ForEach(blocks) { block in
                BlockChrome(title: block.title) {
                    block.content
                }
                .frame(width: block.rect.width, height: block.rect.height, alignment: .topLeading)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                .offset(x: block.rect.minX, y: block.rect.minY)
            }
        }
        .frame(
            width: size.width,
            height: size.height,
            alignment: .topLeading
        )
        .background(Style.previewBackground)
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
        case ("codexlog", "empty"):
            break
        case ("codexlog", "active-thread"):
            try makeCodexLogFixture(in: directory)
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

    private static func makeCodexLogFixture(in directory: URL) throws {
        let nowSeconds = Int(Date().timeIntervalSince1970)
        let nowMilliseconds = nowSeconds * 1_000
        let sessionsDirectory = directory.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        let reviewSession = sessionsDirectory.appendingPathComponent("review.jsonl")
        let notesSession = sessionsDirectory.appendingPathComponent("notes.jsonl")
        let quietSession = sessionsDirectory.appendingPathComponent("quiet.jsonl")

        try [
            #"{"timestamp":"2026-05-20T20:00:00Z","type":"turn_context","payload":{}}"#,
            #"{"timestamp":"2026-05-20T20:00:01Z","type":"response_item","payload":{"type":"function_call"}}"#
        ].joined(separator: "\n").write(to: reviewSession, atomically: true, encoding: .utf8)
        try [
            #"{"timestamp":"2026-05-20T20:00:00Z","type":"turn_context","payload":{}}"#,
            #"{"timestamp":"2026-05-20T20:00:01Z","type":"response_item","payload":{"type":"reasoning"}}"#
        ].joined(separator: "\n").write(to: notesSession, atomically: true, encoding: .utf8)
        try [
            #"{"timestamp":"2026-05-20T20:00:00Z","type":"turn_context","payload":{}}"#,
            #"{"timestamp":"2026-05-20T20:00:01Z","type":"event_msg","payload":{"type":"task_complete"}}"#
        ].joined(separator: "\n").write(to: quietSession, atomically: true, encoding: .utf8)

        try [
            #"{"id":"thread-review","thread_name":"Review generated AGENTS.md change","updated_at":"\#(nowMilliseconds)"}"#,
            #"{"id":"thread-notes","thread_name":"Daily note idea extraction","updated_at":"\#(nowMilliseconds - 20_000)"}"#,
            #"{"id":"thread-quiet","thread_name":"Finished background thread","updated_at":"\#(nowMilliseconds - 120_000)"}"#
        ]
        .joined(separator: "\n")
        .write(
            to: directory.appendingPathComponent("session_index.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let stateDatabase = directory.appendingPathComponent("state_5.sqlite")
        try runSQLite(
            database: stateDatabase,
            statements: """
            create table threads(
                id text,
                title text,
                updated_at integer,
                updated_at_ms integer,
                archived integer,
                cwd text,
                rollout_path text,
                source text,
                thread_source text,
                agent_nickname text,
                agent_role text
            );
            create table jobs(kind text, status text);
            create table agent_jobs(status text);
            create table agent_job_items(status text);
            create table thread_spawn_edges(parent_thread_id text, child_thread_id text);
            insert into threads(id, title, updated_at, updated_at_ms, archived, cwd, rollout_path, source, thread_source, agent_nickname, agent_role) values
                ('thread-review', 'Review generated AGENTS.md change', \(nowSeconds), \(nowMilliseconds), 0, '/Users/snbafana/Documents/personal/Scratch/projects/surface', '\(reviewSession.path)', 'vscode', 'user', '', ''),
                ('thread-notes', 'Daily note idea extraction', \(nowSeconds - 20), \(nowMilliseconds - 20_000), 0, '/Users/snbafana/Documents/personal/Obsidian-Vault', '\(notesSession.path)', 'vscode', 'user', '', ''),
                ('thread-quiet', 'Finished background thread', \(nowSeconds - 120), \(nowMilliseconds - 120_000), 0, '/Users/snbafana/Documents/personal/Scratch', '\(quietSession.path)', 'vscode', 'user', '', '');
            insert into jobs(kind, status) values
                ('memory_stage1', 'done'),
                ('memory_stage1', 'error');
            insert into thread_spawn_edges(parent_thread_id, child_thread_id) values
                ('thread-review', 'thread-review-child-1');
            """
        )

        let logsDatabase = directory.appendingPathComponent("logs_2.sqlite")
        try runSQLite(
            database: logsDatabase,
            statements: """
            create table logs(thread_id text, ts integer);
            insert into logs(thread_id, ts) values
                ('thread-review', \(nowSeconds - 20)),
                ('thread-review', \(nowSeconds - 10)),
                ('thread-notes', \(nowSeconds - 80));
            """
        )

        try [
            #"{"id":"daily-codex-guidance-review-001","title":"Apply AGENTS.md wording update","detail":{"target_path":"/Users/snbafana/Documents/personal/Scratch/projects/surface/AGENTS.md","proposed_text":"- When the user says they reverted or requests just push this, stop analysis and refactors immediately. Confirm branch and remote, then run only the minimal commands needed to push the current state.\n- Keep preview rendering on the real BlockRuntime path."},"status":"pending","thread_id":"thread-review","automation_id":"daily-codex-guidance-review","created_at":\#(nowMilliseconds - 30_000)}"#,
            #"{"id":"daily-obsidian-backlink-proposals-001","title":"Add Related links","detail":{"source_note_path":"Inbox/How to Understand ML Papers Quickly.md","current_related":["[[Machine Learning Trends]]"],"proposed_links":[{"link":"[[Machine Learning Trends]]"},{"link":"[[Deep Learning]]"},{"link":"[[MIT Deep Learning]]"}]},"status":"pending","thread_id":"thread-notes","automation_id":"daily-obsidian-backlink-proposals","created_at":\#(nowMilliseconds - 50_000)}"#,
            #"{"id":"daily-note-to-genuine-ideas-001","title":"Add Genuine Ideas candidates","detail":{"target_path":"Future Lists/Genuine Ideas List.md","addition_text":"- Local approval queues for long-running agents.\n- A checklist for reading ML papers quickly."},"status":"pending","thread_id":"thread-notes","automation_id":"daily-note-to-genuine-ideas","created_at":\#(nowMilliseconds - 40_000)}"#
        ]
        .joined(separator: "\n")
        .write(
            to: directory.appendingPathComponent("codexlog-actions.jsonl"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func runSQLite(database: URL, statements: String) throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [database.path, statements]
        process.standardOutput = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: errorData, encoding: .utf8) ?? "unknown sqlite3 error"
            throw BlockPreviewError.renderFailed(error)
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
