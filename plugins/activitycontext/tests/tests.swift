import Core
import Foundation
import Testing
@testable import ActivityContext

@Suite("Activity Context plugin")
struct ActivityContextTests {
    @MainActor
    @Test func blockCreatesRuntimeAndView() {
        #expect(Plugin.block.id == "activitycontext")

        let runtime = Plugin.block.makeRuntime(Block.Context())
        runtime.start()
        _ = runtime.makeView()
        runtime.stop()
    }

    @Test func readsFixtureSnapshot() throws {
        let fixture = try Fixture()
        try """
        {
          "status": "Fixture",
          "source": "Coast",
          "capturedAt": "2026-07-04T19:00:00Z",
          "current": { "id": "now", "time": "19:00", "duration": "now", "app": "Codex", "domain": null, "url": null, "title": "Surface" },
          "topApps": [{ "name": "Codex", "time": "20m" }],
          "segments": [{ "id": "1", "time": "18:50", "duration": "3m", "app": "Surface", "domain": null, "url": null, "title": "Alt-E" }]
        }
        """.write(to: fixture.url, atomically: true, encoding: .utf8)

        let snapshot = ActivityContextReader(
            context: Block.Context(storageDirectory: fixture.rootURL, now: nil)
        ).snapshot()

        #expect(snapshot.status == "Fixture")
        #expect(snapshot.current?.app == "Codex")
        #expect(snapshot.topApps.map(\.name) == ["Codex"])
        #expect(snapshot.segments.map(\.app) == ["Surface"])
    }

    @Test func parsesLiveCoastCompactOutput() {
        let reader = ActivityContextReader(
            context: Block.Context(
                storageDirectory: nil,
                now: Date(timeIntervalSince1970: 1_783_209_000),
                allowsLiveProcesses: true,
                allowsExternalWrites: false
            ),
            command: { command in
                if command.contains("top-applications") {
                    return """
                    name\ttime
                    Codex\t23m 30s
                    Surface\t4m 56s
                    """
                }
                if command.contains("sample") {
                    return """
                    2 segments with representative frames
                    id\ttime\tdur\tapp\tdomain\turl\ttitle
                    33260\t19:23\t3m 41s\tSurface\t-\t-\tAlt-E overlay test
                    """
                }
                return "path: /tmp/screen.jpg\ttime: 2026-07-04T23:53:24Z\tapp: com.snbafana.Surface"
            }
        )

        let snapshot = reader.snapshot()

        #expect(snapshot.status == "Live")
        #expect(snapshot.topApps.first?.name == "Codex")
        #expect(snapshot.segments.first?.title == "Alt-E overlay test")
        #expect(snapshot.current?.app == "com.snbafana.Surface")
    }
}

private struct Fixture {
    let rootURL: URL
    var url: URL {
        rootURL.appendingPathComponent("activitycontext.json")
    }

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("surface-activitycontext-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }
}
