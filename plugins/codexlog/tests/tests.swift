import Core
import Foundation
import Testing
@testable import CodexLog

@Suite("Codex Log plugin")
struct CodexLogTests {
    @MainActor
    @Test func blockCreatesRuntimeAndView() {
        #expect(Plugin.block.id == "codexlog")

        let runtime = Plugin.block.makeRuntime(Block.Context())
        _ = runtime.makeView()
        runtime.stop()
    }

    @Test func readsThreadsAutomationsActionsAndProcessesFromCodexHome() throws {
        let fixture = try CodexLogFixture()
        let nowMilliseconds = Int(Date().timeIntervalSince1970 * 1_000)
        try fixture.writeSessionIndex([
            #"{"id":"thread-old","thread_name":"Older thread","updated_at":"\#(nowMilliseconds - 20_000)"}"#,
            #"{"id":"thread-new","thread_name":"Newer thread","updated_at":"\#(nowMilliseconds)"}"#
        ])
        try fixture.writeEmptyLogsDatabase()
        try fixture.writeAutomation(
            id: "daily-review",
            text: """
            version = 1
            id = "daily-review"
            kind = "cron"
            name = "Daily Review"
            status = "ACTIVE"
            rrule = "FREQ=DAILY"
            updated_at = 1779229000000
            """
        )
        try fixture.writeActions([
            #"{"id":"act-1","title":"Approve generated patch","detail":"Apply the proposed diff","status":"pending","thread_id":"thread-new","automation_id":"daily-review","created_at":1779229100000}"#,
            #"{"id":"act-2","title":"Already handled","status":"approved","created_at":"1779220000000"}"#
        ])

        let reader = CodexStateReader(codexHome: fixture.rootURL) { command in
            if command.first == "/bin/ps" {
                return """
                /Applications/Codex.app/Contents/MacOS/Codex
                /Applications/Codex.app/Contents/Resources/codex app-server --listen stdio://
                ./Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient mcp
                """
            }
            if command.first == "/usr/bin/sqlite3", command.last?.contains("from logs") == true {
                return """
                thread-new\t12\t1779229300
                thread-missing\t3\t1779229200
                """
            }
            return ""
        }

        let snapshot = reader.snapshot(threadLimit: 4)

        #expect(snapshot.threads.map(\.id) == ["thread-new", "thread-old"])
        #expect(snapshot.activeAutomations.map(\.id) == ["daily-review"])
        #expect(snapshot.runningThreads.map(\.id) == ["thread-new", "thread-old"])
        #expect(snapshot.runningThreads.first?.thread.title == "Newer thread")
        #expect(snapshot.runningThreads.first?.logCount == 12)
        #expect(snapshot.pendingActions.map(\.id) == ["act-1"])
        #expect(snapshot.pendingActions.first?.detail == "Apply the proposed diff")
        #expect(snapshot.pendingActions.first?.automationID == "daily-review")
        #expect(snapshot.threadsNeedingAttention.map(\.id) == ["thread-new"])
        #expect(snapshot.processes.contains(CodexProcessSummary(kind: "desktop app", count: 1)))
        #expect(snapshot.processes.contains(CodexProcessSummary(kind: "worker server", count: 1)))
        #expect(snapshot.processes.contains(CodexProcessSummary(kind: "computer use", count: 1)))
    }

    @Test func readsSQLiteThreadAndJobSummariesWhenDatabaseExists() throws {
        let fixture = try CodexLogFixture()
        try Data().write(to: fixture.rootURL.appendingPathComponent("state_5.sqlite"))
        try fixture.writeEmptyLogsDatabase()
        let nowMilliseconds = Int(Date().timeIntervalSince1970 * 1_000)
        let activeSession = try fixture.writeSessionFile(name: "active", completed: false)
        let completedSession = try fixture.writeSessionFile(name: "complete", completed: true)

        let reader = CodexStateReader(codexHome: fixture.rootURL) { command in
            guard command.first == "/usr/bin/sqlite3" else {
                return ""
            }
            let query = command.last ?? ""
            if query.contains("from threads") {
                return """
                thread-a\tActive work\t\(nowMilliseconds)\t0\t/Users/example/project\t\(activeSession)
                thread-b\tArchived work\t\(nowMilliseconds - 10_000)\t1\t/Users/example/old\t
                thread-c\tCompleted work\t\(nowMilliseconds - 20_000)\t0\t/Users/example/done\t\(completedSession)
                """
            }
            if query.contains("from logs") {
                return """
                thread-a\t42\t\(Int(Date().timeIntervalSince1970))
                thread-c\t9\t\(Int(Date().timeIntervalSince1970))
                """
            }
            if query.contains("from jobs") {
                return """
                memory_stage1\tdone\t4
                memory_stage1\terror\t2
                """
            }
            return ""
        }

        let snapshot = reader.snapshot(threadLimit: 3)

        #expect(snapshot.threads.map(\.id) == ["thread-a", "thread-b", "thread-c"])
        #expect(snapshot.activeThreads.map(\.id) == ["thread-a", "thread-c"])
        #expect(snapshot.runningThreads.map(\.id) == ["thread-a"])
        #expect(snapshot.runningThreads.first?.thread.title == "Active work")
        #expect(snapshot.runningThreads.first?.logCount == 42)
        #expect(snapshot.jobs.contains(CodexJobSummary(kind: "memory_stage1", status: "done", count: 4)))
        #expect(snapshot.failedJobs == [CodexJobSummary(kind: "memory_stage1", status: "error", count: 2)])
    }

    @Test func actionLogFoldsDecisionsAndKeepsHistory() throws {
        let fixture = try CodexLogFixture()
        try fixture.writeActions([
            #"{"id":"patch-1","title":"Review patch","status":"pending","thread_id":"thread-a","created_at":1779229000000}"#
        ])

        let reader = CodexStateReader(codexHome: fixture.rootURL) { _ in "" }

        #expect(reader.snapshot().pendingActions.map(\.id) == ["patch-1"])

        try reader.approveAction("patch-1")
        var snapshot = reader.snapshot()

        #expect(snapshot.pendingActions.isEmpty)
        #expect(snapshot.resolvedActions.map(\.status) == [.approved])

        try fixture.appendAction(#"{"id":"patch-1","status":"completed","updated_at":1779229300000}"#)
        snapshot = reader.snapshot()

        #expect(snapshot.resolvedActions.map(\.status) == [.completed])

        try reader.cancelAction("patch-1")
        snapshot = reader.snapshot()

        #expect(snapshot.resolvedActions.map(\.status) == [.cancelled])
        #expect(try String(contentsOf: fixture.actionLogURL, encoding: .utf8).split(separator: "\n").count == 4)
    }

    @Test func structuredRowsSplitIntoBiteSizedActions() throws {
        let fixture = try CodexLogFixture()
        try fixture.writeActions([
            #"{"id":"codex-bundle","status":"pending","title":"Update guidance","detail":{"target_path":"/tmp/AGENTS.md","proposed_text":"- First guardrail\n- Second guardrail"},"automation_id":"daily-codex-guidance-review","created_at":"2026-05-20T01:36:54Z"}"#,
            #"{"id":"backlink-bundle","status":"pending","title":"Add related links","detail":{"source_note_path":"Inbox/ML.md","current_related":["[[Existing]]"],"proposed_links":[{"link":"[[Existing]]"},{"link":"[[Deep Learning]]"},{"link":"[[Machine Learning Trends]]"}]},"automation_id":"daily-obsidian-backlink-proposals","created_at":"2026-05-20T01:34:13Z"}"#,
            #"{"id":"idea-bundle","status":"pending","title":"Add ideas","detail":{"target_path":"Future Lists/Genuine Ideas List.md","addition_text":"- First idea\n- Second idea with \'taste\'"},"automation_id":"daily-note-to-genuine-ideas","created_at":"2026-05-20T01:33:01Z"}"#
        ])

        let reader = CodexStateReader(codexHome: fixture.rootURL) { _ in "" }
        let snapshot = reader.snapshot()

        let codexActions = snapshot.pendingActions.filter { $0.automationID == "daily-codex-guidance-review" }
        let backlinkActions = snapshot.pendingActions.filter { $0.automationID == "daily-obsidian-backlink-proposals" }
        let ideaActions = snapshot.pendingActions.filter { $0.automationID == "daily-note-to-genuine-ideas" }

        #expect(codexActions.count == 2)
        #expect(codexActions.allSatisfy { $0.targetPath == "/tmp/AGENTS.md" })
        #expect(codexActions.contains { $0.detail == "First guardrail" })
        #expect(backlinkActions.count == 2)
        #expect(backlinkActions.allSatisfy { $0.targetPath == "Inbox/ML.md" })
        #expect(backlinkActions.contains { $0.title.contains("[[Deep Learning]]") })
        #expect(ideaActions.count == 2)
        #expect(ideaActions.contains { $0.detail == "Second idea with 'taste'" })
        #expect(snapshot.pendingActions.allSatisfy { $0.createdAt != nil })

        let action = try #require(codexActions.first)
        try reader.approveAction(action)
        let log = try String(contentsOf: fixture.actionLogURL, encoding: .utf8)
        #expect(log.contains(#""target_path":"/tmp/AGENTS.md""#))
        #expect(log.contains(#""text":"#))
    }
}

private struct CodexLogFixture {
    let rootURL: URL
    var actionLogURL: URL {
        rootURL.appendingPathComponent("codexlog-actions.jsonl")
    }

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("surface-codexlog-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func writeSessionIndex(_ lines: [String]) throws {
        try lines.joined(separator: "\n").write(
            to: rootURL.appendingPathComponent("session_index.jsonl"),
            atomically: true,
            encoding: .utf8
        )
    }

    func writeAutomation(id: String, text: String) throws {
        let directory = rootURL
            .appendingPathComponent("automations", isDirectory: true)
            .appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(to: directory.appendingPathComponent("automation.toml"), atomically: true, encoding: .utf8)
    }

    func writeActions(_ lines: [String]) throws {
        try lines.joined(separator: "\n").write(
            to: actionLogURL,
            atomically: true,
            encoding: .utf8
        )
    }

    func writeSessionFile(name: String, completed: Bool) throws -> String {
        let directory = rootURL.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).jsonl")
        var lines = [
            #"{"timestamp":"2026-05-20T20:00:00Z","type":"turn_context","payload":{}}"#,
            #"{"timestamp":"2026-05-20T20:00:01Z","type":"response_item","payload":{"type":"message"}}"#
        ]
        if completed {
            lines.append(#"{"timestamp":"2026-05-20T20:00:02Z","type":"event_msg","payload":{"type":"task_complete"}}"#)
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return url.path
    }

    func appendAction(_ line: String) throws {
        var text = try String(contentsOf: actionLogURL, encoding: .utf8)
        if !text.hasSuffix("\n") {
            text.append("\n")
        }
        text.append(line)
        text.append("\n")
        try text.write(to: actionLogURL, atomically: true, encoding: .utf8)
    }

    func writeEmptyLogsDatabase() throws {
        try Data().write(to: rootURL.appendingPathComponent("logs_2.sqlite"))
    }
}
