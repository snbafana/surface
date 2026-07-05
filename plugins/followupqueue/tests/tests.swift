import Core
import Foundation
import Testing
@testable import FollowUpQueue

@Suite("Follow Up Queue plugin")
struct FollowUpQueueTests {
    @MainActor
    @Test func blockCreatesRuntimeAndView() {
        #expect(Plugin.block.id == "followupqueue")

        let runtime = Plugin.block.makeRuntime(Block.Context())
        runtime.start()
        _ = runtime.makeView()
        runtime.stop()
    }

    @Test func readsFixtureItems() throws {
        let fixture = try Fixture()
        try """
        {
          "status": "Fixture Cued",
          "items": [
            {
              "id": "conversation-a",
              "platform": "imessage",
              "person": "Ada",
              "last_message_at": "2026-07-04 15:32:55",
              "is_from_me": false,
              "unread_count": 2,
              "preview": "Can you look?"
            }
          ]
        }
        """.write(to: fixture.url, atomically: true, encoding: .utf8)

        let state = FollowUpReader(
            context: Block.Context(storageDirectory: fixture.rootURL, now: nil)
        ).state()

        #expect(state.status == "Fixture Cued")
        #expect(state.items.first?.person == "Ada")
        #expect(state.items.first?.kind == "Unread")
    }

    @Test func decodesCuedRowsFromLiveSQLShape() {
        let reader = FollowUpReader(
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
                    "conversation_id": "conversation-b",
                    "platform": "imessage",
                    "person": "Grace",
                    "last_message_at": "2026-07-01 09:00:00",
                    "is_from_me": 1,
                    "unread_count": 0,
                    "preview": "Following up here."
                  }
                ]
                """
            }
        )

        let state = reader.state()

        #expect(state.status == "Live Cued")
        #expect(state.items.first?.id == "conversation-b")
        #expect(state.items.first?.kind == "Follow up")
    }
}

private struct Fixture {
    let rootURL: URL
    var url: URL {
        rootURL.appendingPathComponent("followupqueue-items.json")
    }

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("surface-followupqueue-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }
}
