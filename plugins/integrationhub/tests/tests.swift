import Core
import Foundation
import Testing
@testable import IntegrationHub

@Suite("Integration Hub plugin")
struct IntegrationHubTests {
    @MainActor
    @Test func blockCreatesRuntimeAndView() {
        #expect(Plugin.block.id == "integrationhub")

        let runtime = Plugin.block.makeRuntime(Block.Context())
        runtime.start()
        _ = runtime.makeView()
        runtime.stop()
    }

    @Test func readsFixtureItems() throws {
        let fixture = try Fixture()
        try """
        {
          "status": "Fixture",
          "items": [
            {
              "id": "browserbase-browse",
              "name": "Browserbase Browse",
              "kind": "browser automation",
              "status": "Needs key",
              "detail": "Browse CLI installed.",
              "command": "browse status",
              "url": "https://docs.browserbase.com/integrations/skills/browse-cli",
              "priority": 1
            }
          ]
        }
        """.write(to: fixture.url, atomically: true, encoding: .utf8)

        let state = IntegrationHubReader(
            context: Block.Context(storageDirectory: fixture.rootURL, now: nil)
        ).state()

        #expect(state.status == "Fixture")
        #expect(state.items.first?.id == "browserbase-browse")
        #expect(state.items.first?.status == "Needs key")
        #expect(state.items.first?.command == "browse status")
    }

    @Test func liveStateClassifiesInstalledCLIsAndBrowserbaseKey() {
        let installed = [
            "browse": "/opt/homebrew/bin/browse",
            "coast": "/Users/example/.local/bin/coast",
            "cued": "/Users/example/.local/bin/cued",
            "gh": "/opt/homebrew/bin/gh",
            "oracle": "/opt/homebrew/bin/oracle"
        ]
        let reader = IntegrationHubReader(
            context: Block.Context(
                storageDirectory: nil,
                now: nil,
                allowsLiveProcesses: true,
                allowsExternalWrites: false
            ),
            environment: ["BROWSERBASE_API_KEY": "bb_test"],
            executablePath: { installed[$0] }
        )

        let state = reader.state()
        let byID = Dictionary(uniqueKeysWithValues: state.items.map { ($0.id, $0) })

        #expect(state.status == "6 of 7 ready")
        #expect(byID["browserbase-browse"]?.status == "Ready")
        #expect(byID["browserbase-bb"]?.status == "Optional")
        #expect(byID["integrations-sh"]?.status == "Available")
        #expect(byID["coast"]?.status == "Ready")
        #expect(byID["cued"]?.status == "Ready")
        #expect(byID["gh"]?.status == "Ready")
        #expect(byID["steipete-toolbelt"]?.status == "1 installed")
    }

    @Test func liveStateShowsMissingBrowserbaseKeySeparatelyFromInstall() throws {
        let reader = IntegrationHubReader(
            context: Block.Context(
                storageDirectory: nil,
                now: nil,
                allowsLiveProcesses: true,
                allowsExternalWrites: false
            ),
            environment: [:],
            executablePath: { $0 == "browse" ? "/opt/homebrew/bin/browse" : nil }
        )

        let state = reader.state()
        let browserbase = try #require(state.items.first { $0.id == "browserbase-browse" })

        #expect(browserbase.status == "Needs key")
        #expect(browserbase.command == "browse status")
        #expect(browserbase.detail.contains("BROWSERBASE_API_KEY"))
    }
}

private struct Fixture {
    let rootURL: URL
    var url: URL {
        rootURL.appendingPathComponent("integrationhub-items.json")
    }

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("surface-integrationhub-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }
}
