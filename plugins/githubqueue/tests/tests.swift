import Core
import Foundation
import Testing
@testable import GitHubQueue

@Suite("GitHub Queue plugin")
struct GitHubQueueTests {
    @MainActor
    @Test func blockCreatesRuntimeAndView() {
        #expect(Plugin.block.id == "githubqueue")

        let runtime = Plugin.block.makeRuntime(Block.Context())
        runtime.start()
        _ = runtime.makeView()
        runtime.stop()
    }

    @Test func readsFixturePullRequests() throws {
        let fixture = try Fixture()
        try """
        {
          "status": "Fixture gh",
          "pullRequests": [
            {
              "number": 7,
              "title": "Review Surface block",
              "url": "https://github.com/example/surface/pull/7",
              "headRefName": "feature",
              "baseRefName": "main",
              "author": { "login": "agent" },
              "isDraft": false,
              "reviewDecision": "APPROVED",
              "updatedAt": "2026-07-04T19:00:00Z",
              "checkSummary": { "passing": 4, "failing": 0, "pending": 0 }
            }
          ]
        }
        """.write(to: fixture.url, atomically: true, encoding: .utf8)

        let state = GitHubQueueReader(
            context: Block.Context(storageDirectory: fixture.rootURL, now: nil)
        ).state()

        #expect(state.status == "Fixture gh")
        #expect(state.pullRequests.first?.number == 7)
        #expect(state.pullRequests.first?.stateLabel == "Approved")
    }

    @Test func decodesLiveGhListArray() {
        let reader = GitHubQueueReader(
            context: Block.Context(
                storageDirectory: nil,
                now: nil,
                allowsLiveProcesses: true,
                allowsExternalWrites: false
            ),
            command: { _ in
                """
                [
                  {
                    "number": 8,
                    "title": "Failing checks",
                    "url": "https://github.com/example/surface/pull/8",
                    "headRefName": "checks",
                    "baseRefName": "main",
                    "author": { "login": "reviewer" },
                    "isDraft": false,
                    "reviewDecision": null,
                    "updatedAt": "2026-07-04T19:00:00Z",
                    "checkSummary": { "passing": 1, "failing": 2, "pending": 0 }
                  }
                ]
                """
            }
        )

        let state = reader.state()

        #expect(state.status == "Live gh")
        #expect(state.pullRequests.first?.stateLabel == "Failing")
    }
}

private struct Fixture {
    let rootURL: URL
    var url: URL {
        rootURL.appendingPathComponent("githubqueue-prs.json")
    }

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("surface-githubqueue-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }
}
