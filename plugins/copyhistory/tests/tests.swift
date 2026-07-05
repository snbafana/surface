import Core
import Foundation
import Testing
@testable import CopyHistory

@Suite("Copy History plugin")
struct CopyHistoryTests {
    @MainActor
    @Test func blockCreatesRuntimeAndView() {
        #expect(Plugin.block.id == "copyhistory")

        let runtime = Plugin.block.makeRuntime(Block.Context())
        runtime.start()
        _ = runtime.makeView()
        runtime.stop()
    }

    @Test func storeLoadsFixtureHistoryLines() throws {
        let fixture = try CopyHistoryFixture()
        try [
            "Investor memo excerpt copied from Notes.",
            "https://example.com/surface-preview"
        ].joined(separator: "\n").write(to: fixture.historyURL, atomically: true, encoding: .utf8)

        let entries = try CopyHistoryStore().load(from: fixture.historyURL)

        #expect(entries.map(\.text) == [
            "Investor memo excerpt copied from Notes.",
            "https://example.com/surface-preview"
        ])
    }

    @Test func storeAddsNewestFirstAndDeduplicatesConsecutiveText() throws {
        let fixture = try CopyHistoryFixture()
        let store = CopyHistoryStore(limit: 2)

        _ = try store.add(text: "first", to: fixture.historyURL)
        _ = try store.add(text: "second", to: fixture.historyURL)
        _ = try store.add(text: "second", to: fixture.historyURL)
        let entries = try store.add(text: "third", to: fixture.historyURL)

        #expect(entries.map(\.text) == ["third", "second"])
        #expect(try String(contentsOf: fixture.historyURL, encoding: .utf8) == "third\nsecond")
    }
}

private struct CopyHistoryFixture {
    let rootURL: URL
    var historyURL: URL {
        rootURL.appendingPathComponent("copyhistory.txt")
    }

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("surface-copyhistory-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }
}
