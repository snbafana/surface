import Foundation

struct CodexThreadSummary: Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var cwd: String?
    var updatedAt: Date?
    var isArchived: Bool
    var rolloutPath: String?
    var source: String?
    var threadSource: String?
    var agentNickname: String?
    var agentRole: String?
}

struct CodexAutomationSummary: Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var kind: String
    var status: String
    var rrule: String?
    var targetThreadID: String?
    var updatedAt: Date?

    var isActive: Bool {
        status.uppercased() == "ACTIVE"
    }
}

struct CodexJobSummary: Equatable, Identifiable, Sendable {
    var kind: String
    var status: String
    var count: Int

    var id: String {
        "\(kind):\(status)"
    }
}

struct CodexProcessSummary: Equatable, Identifiable, Sendable {
    var kind: String
    var count: Int

    var id: String { kind }
}

struct CodexRunningThread: Equatable, Identifiable, Sendable {
    var thread: CodexThreadSummary
    var logCount: Int
    var lastSeenAt: Date?
    var state: CodexThreadRunState
    var lastEvent: String?
    var childThreadCount: Int

    var id: String {
        thread.id
    }
}

enum CodexThreadRunState: String, Sendable {
    case running
    case interrupted
    case complete
    case unknown
}

enum CodexActionStatus: String, Codable, Sendable {
    case pending
    case approved
    case denied
    case cancelled
    case completed
    case failed
}

struct CodexActionProposal: Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var detail: String?
    var status: CodexActionStatus
    var threadID: String?
    var automationID: String?
    var jobID: String?
    var targetPath: String?
    var createdAt: Date?
    var updatedAt: Date?
}

struct CodexSnapshot: Equatable, Sendable {
    var threads: [CodexThreadSummary] = []
    var runningThreads: [CodexRunningThread] = []
    var automations: [CodexAutomationSummary] = []
    var jobs: [CodexJobSummary] = []
    var processes: [CodexProcessSummary] = []
    var actions: [CodexActionProposal] = []

    var activeThreads: [CodexThreadSummary] {
        threads.filter { !$0.isArchived }
    }

    var threadsNeedingAttention: [CodexThreadSummary] {
        let threadIDs = Set(pendingActions.compactMap(\.threadID))
        return activeThreads.filter { threadIDs.contains($0.id) }
    }

    var activeAutomations: [CodexAutomationSummary] {
        automations.filter(\.isActive)
    }

    var pendingActions: [CodexActionProposal] {
        actions.filter { $0.status == .pending }
    }

    var resolvedActions: [CodexActionProposal] {
        actions.filter { $0.status != .pending }
    }

    var runningJobs: [CodexJobSummary] {
        jobs.filter { ["active", "in_progress", "leased", "pending", "processing", "running", "started"].contains($0.status.lowercased()) }
    }

    var finishedJobs: [CodexJobSummary] {
        jobs.filter { ["completed", "done", "success", "succeeded"].contains($0.status.lowercased()) }
    }

    var failedJobs: [CodexJobSummary] {
        jobs.filter { $0.status.lowercased() == "error" || $0.status.lowercased() == "failed" }
    }

    var jobsNeedingAttention: [CodexJobSummary] {
        failedJobs + jobs.filter { $0.status.lowercased() == "blocked" || $0.status.lowercased() == "needs_attention" }
    }
}

struct CodexStateReader {
    typealias CommandRunner = ([String]) throws -> String

    static let defaultCodexHome = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex", isDirectory: true)

    var codexHome: URL
    var includeProcesses: Bool
    var runCommand: CommandRunner
    var fileManager: FileManager

    init(
        codexHome: URL = Self.defaultCodexHome,
        includeProcesses: Bool = true,
        fileManager: FileManager = .default,
        runCommand: @escaping CommandRunner = ProcessRunner.run
    ) {
        self.codexHome = codexHome
        self.includeProcesses = includeProcesses
        self.fileManager = fileManager
        self.runCommand = runCommand
    }

    func snapshot(threadLimit: Int = 8, runningWindowSeconds: Int = 900) -> CodexSnapshot {
        let threads = readThreads(limit: max(threadLimit, 50))
        return CodexSnapshot(
            threads: Array(threads.prefix(max(1, threadLimit))),
            runningThreads: readRunningThreads(
                knownThreads: threads,
                limit: threadLimit,
                windowSeconds: runningWindowSeconds
            ),
            automations: readAutomations(),
            jobs: readJobs(),
            processes: includeProcesses ? readProcessSummary() : [],
            actions: readActionProposals()
        )
    }

    func approveAction(_ id: String) throws {
        try appendActionDecision(id: id, action: nil, status: .approved)
    }

    func approveAction(_ action: CodexActionProposal) throws {
        try appendActionDecision(id: action.id, action: action, status: .approved)
    }

    func denyAction(_ id: String) throws {
        try appendActionDecision(id: id, action: nil, status: .denied)
    }

    func denyAction(_ action: CodexActionProposal) throws {
        try appendActionDecision(id: action.id, action: action, status: .denied)
    }

    func cancelAction(_ id: String) throws {
        try appendActionDecision(id: id, action: nil, status: .cancelled)
    }

    private func readThreads(limit: Int) -> [CodexThreadSummary] {
        let database = codexHome.appendingPathComponent("state_5.sqlite")
        if fileManager.fileExists(atPath: database.path) {
            let query = """
            select id,
                   replace(title, char(9), ' '),
                   coalesce(updated_at_ms, updated_at * 1000),
                   archived,
                   replace(cwd, char(9), ' '),
                   replace(rollout_path, char(9), ' '),
                   source,
                   coalesce(thread_source, ''),
                   coalesce(agent_nickname, ''),
                   coalesce(agent_role, '')
            from threads
            order by coalesce(updated_at_ms, updated_at * 1000) desc
            limit \(max(1, limit));
            """
            if let output = try? runCommand(["/usr/bin/sqlite3", "-separator", "\t", database.path, query]) {
                let threads = parseSQLiteThreads(output)
                if !threads.isEmpty {
                    return threads
                }
            }
        }

        return readSessionIndex(limit: limit)
    }

    private func readRunningThreads(
        knownThreads: [CodexThreadSummary],
        limit: Int,
        windowSeconds: Int
    ) -> [CodexRunningThread] {
        let windowSeconds = max(1, windowSeconds)
        let cutoff = Date().addingTimeInterval(-TimeInterval(windowSeconds))
        let logActivity = readRecentLogActivity(windowSeconds: windowSeconds)
        let childCounts = readChildThreadCounts()

        return knownThreads
            .filter { !$0.isArchived }
            .compactMap { thread in
                let sessionURL = rolloutURL(for: thread.rolloutPath)
                let sessionModifiedAt = sessionURL.flatMap(modificationDate)
                let sessionTail = sessionTail(for: sessionURL)
                let logSeenAt = logActivity[thread.id]?.lastSeenAt
                let lastSeenAt = latestDate(thread.updatedAt, sessionModifiedAt, logSeenAt)

                guard let lastSeenAt, lastSeenAt >= cutoff else {
                    return nil
                }
                guard sessionTail.state != .complete else {
                    return nil
                }

                return CodexRunningThread(
                    thread: thread,
                    logCount: logActivity[thread.id]?.count ?? 0,
                    lastSeenAt: lastSeenAt,
                    state: sessionTail.state,
                    lastEvent: sessionTail.lastEvent,
                    childThreadCount: childCounts[thread.id] ?? 0
                )
            }
            .sorted {
                ($0.lastSeenAt ?? .distantPast) > ($1.lastSeenAt ?? .distantPast)
            }
            .prefix(max(1, limit))
            .map { $0 }
    }

    private func parseSQLiteThreads(_ output: String) -> [CodexThreadSummary] {
        output
            .split(separator: "\n")
            .compactMap { line in
                let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard columns.count >= 5 else { return nil }
                return CodexThreadSummary(
                    id: columns[0],
                    title: columns[1].isEmpty ? "Untitled" : columns[1],
                    cwd: columns[4].isEmpty ? nil : columns[4],
                    updatedAt: millisecondsDate(columns[2]),
                    isArchived: columns[3] == "1",
                    rolloutPath: columns.count > 5 && !columns[5].isEmpty ? columns[5] : nil,
                    source: columns.count > 6 && !columns[6].isEmpty ? columns[6] : nil,
                    threadSource: columns.count > 7 && !columns[7].isEmpty ? columns[7] : nil,
                    agentNickname: columns.count > 8 && !columns[8].isEmpty ? columns[8] : nil,
                    agentRole: columns.count > 9 && !columns[9].isEmpty ? columns[9] : nil
                )
            }
    }

    private func readSessionIndex(limit: Int) -> [CodexThreadSummary] {
        let url = codexHome.appendingPathComponent("session_index.jsonl")
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }

        return text
            .split(separator: "\n")
            .compactMap { line -> CodexThreadSummary? in
                guard let data = String(line).data(using: .utf8),
                      let row = try? JSONDecoder().decode(SessionIndexRow.self, from: data) else {
                    return nil
                }
                return CodexThreadSummary(
                    id: row.id,
                    title: row.threadName,
                    cwd: nil,
                    updatedAt: row.updatedAt.flatMap(timestampDate),
                    isArchived: false,
                    rolloutPath: nil,
                    source: nil,
                    threadSource: nil,
                    agentNickname: nil,
                    agentRole: nil
                )
            }
            .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            .prefix(max(1, limit))
            .map { $0 }
    }

    private func readRecentLogActivity(windowSeconds: Int) -> [String: (count: Int, lastSeenAt: Date?)] {
        let database = codexHome.appendingPathComponent("logs_2.sqlite")
        guard fileManager.fileExists(atPath: database.path),
              let output = try? runCommand([
                  "/usr/bin/sqlite3",
                  "-separator",
                  "\t",
                  database.path,
                  """
                  select thread_id, count(*), max(ts)
                  from logs
                  where thread_id is not null
                    and thread_id != ''
                    and ts >= strftime('%s','now') - \(max(1, windowSeconds))
                  group by thread_id;
                  """
              ]) else {
            return [:]
        }

        var activity: [String: (count: Int, lastSeenAt: Date?)] = [:]
        for line in output.split(separator: "\n") {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count == 3, let count = Int(columns[1]) else {
                continue
            }
            activity[columns[0]] = (count: count, lastSeenAt: secondsDate(columns[2]))
        }
        return activity
    }

    private func readChildThreadCounts() -> [String: Int] {
        let database = codexHome.appendingPathComponent("state_5.sqlite")
        guard fileManager.fileExists(atPath: database.path),
              let output = try? runCommand([
                  "/usr/bin/sqlite3",
                  "-separator",
                  "\t",
                  database.path,
                  """
                  select parent_thread_id, count(*)
                  from thread_spawn_edges
                  group by parent_thread_id;
                  """
              ]) else {
            return [:]
        }

        var counts: [String: Int] = [:]
        for line in output.split(separator: "\n") {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count == 2, let count = Int(columns[1]) else {
                continue
            }
            counts[columns[0]] = count
        }
        return counts
    }

    private func rolloutURL(for path: String?) -> URL? {
        guard let path, !path.isEmpty else {
            return nil
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return URL(fileURLWithPath: expandedPath)
        }
        return codexHome.appendingPathComponent(expandedPath)
    }

    private func modificationDate(for url: URL) -> Date? {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }

    private func sessionTail(for url: URL?) -> CodexSessionTail {
        guard let url, let text = recentSessionText(at: url) else {
            return CodexSessionTail(state: .unknown, lastEvent: nil)
        }

        var lastEvent: String?
        for line in text.split(separator: "\n").reversed() {
            if lastEvent == nil {
                lastEvent = sessionEventLabel(for: line)
            }
            if line.contains(#""type":"turn_context""#) {
                return CodexSessionTail(state: .running, lastEvent: lastEvent)
            }
            if line.contains(#""type":"turn_aborted""#) {
                return CodexSessionTail(state: .interrupted, lastEvent: lastEvent ?? "interrupted")
            }
            if line.contains(#""type":"task_complete""#) {
                return CodexSessionTail(state: .complete, lastEvent: lastEvent ?? "complete")
            }
        }
        return CodexSessionTail(state: .unknown, lastEvent: lastEvent)
    }

    private func sessionEventLabel(for line: Substring) -> String? {
        if line.contains(#""type":"token_count""#) || line.contains(#""type":"session_meta""#) {
            return nil
        }
        if line.contains(#""type":"task_complete""#) {
            return "complete"
        }
        if line.contains(#""type":"turn_aborted""#) {
            return "interrupted"
        }
        if line.contains(#""type":"agent_message""#) {
            return "message"
        }
        if line.contains(#""type":"user_message""#) {
            return "user input"
        }
        if line.contains(#""type":"function_call_output""#) {
            return "tool output"
        }
        if line.contains(#""type":"function_call""#) {
            return "tool call"
        }
        if line.contains(#""type":"web_search_call""#) || line.contains(#""type":"web_search_end""#) {
            return "web search"
        }
        if line.contains(#""type":"reasoning""#) {
            return "reasoning"
        }
        if line.contains(#""type":"turn_context""#) {
            return "running"
        }
        return nil
    }

    private func recentSessionText(at url: URL, byteLimit: UInt64 = 65_536) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }

        let size = ((try? fileManager.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.uint64Value ?? 0
        if size > byteLimit {
            try? handle.seek(toOffset: size - byteLimit)
        }
        guard let data = try? handle.readToEnd() else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func readAutomations() -> [CodexAutomationSummary] {
        let directory = codexHome.appendingPathComponent("automations", isDirectory: true)
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .map { $0.appendingPathComponent("automation.toml") }
            .compactMap(readAutomation)
            .sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive {
                    return lhs.isActive && !rhs.isActive
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func readAutomation(_ url: URL) -> CodexAutomationSummary? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let fields = tomlFields(in: text)
        guard let id = fields["id"] ?? url.deletingLastPathComponent().lastPathComponent.nilIfEmpty else {
            return nil
        }

        return CodexAutomationSummary(
            id: id,
            name: fields["name"] ?? id,
            kind: fields["kind"] ?? "unknown",
            status: fields["status"] ?? "UNKNOWN",
            rrule: fields["rrule"],
            targetThreadID: fields["target_thread_id"],
            updatedAt: fields["updated_at"].flatMap(millisecondsDate)
        )
    }

    private func tomlFields(in text: String) -> [String: String] {
        var fields: [String: String] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let equals = line.firstIndex(of: "=") else {
                continue
            }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            let rawValue = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            fields[String(key)] = unquote(rawValue)
        }
        return fields
    }

    private func readJobs() -> [CodexJobSummary] {
        let database = codexHome.appendingPathComponent("state_5.sqlite")
        guard fileManager.fileExists(atPath: database.path) else {
            return []
        }

        var summaries: [CodexJobSummary] = []
        if let output = try? runCommand([
            "/usr/bin/sqlite3",
            "-separator",
            "\t",
            database.path,
            "select kind, status, count(*) from jobs group by kind, status order by kind, status;"
        ]) {
            summaries.append(contentsOf: parseJobSummaries(output))
        }
        if let output = try? runCommand([
            "/usr/bin/sqlite3",
            "-separator",
            "\t",
            database.path,
            "select 'agent jobs', status, count(*) from agent_jobs group by status order by status;"
        ]) {
            summaries.append(contentsOf: parseJobSummaries(output))
        }
        if let output = try? runCommand([
            "/usr/bin/sqlite3",
            "-separator",
            "\t",
            database.path,
            "select 'agent job items', status, count(*) from agent_job_items group by status order by status;"
        ]) {
            summaries.append(contentsOf: parseJobSummaries(output))
        }
        return summaries
    }

    private func parseJobSummaries(_ output: String) -> [CodexJobSummary] {
        output
            .split(separator: "\n")
            .compactMap { line in
                let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard columns.count == 3, let count = Int(columns[2]) else {
                    return nil
                }
                return CodexJobSummary(kind: columns[0], status: columns[1], count: count)
            }
    }

    private func readProcessSummary() -> [CodexProcessSummary] {
        guard let output = try? runCommand(["/bin/ps", "ax", "-o", "command="]) else {
            return []
        }

        var counts: [String: Int] = [:]
        for line in output.split(separator: "\n").map(String.init) {
            guard line.localizedCaseInsensitiveContains("codex") else {
                continue
            }
            counts[processKind(for: line), default: 0] += 1
        }

        return counts
            .map { CodexProcessSummary(kind: $0.key, count: $0.value) }
            .sorted { $0.kind < $1.kind }
    }

    private func processKind(for command: String) -> String {
        if command.contains("codex app-server --listen") {
            return "worker server"
        }
        if command.contains("codex app-server") {
            return "app server"
        }
        if command.contains("node_repl") {
            return "node repl"
        }
        if command.contains("SkyComputerUseClient") {
            return "computer use"
        }
        if command.contains("/Codex.app/Contents/MacOS/Codex") {
            return "desktop app"
        }
        if command.contains("Codex Helper") {
            return "desktop helper"
        }
        return "other"
    }

    private func readActionProposals() -> [CodexActionProposal] {
        guard let data = try? Data(contentsOf: actionLogURL),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }

        var actions: [String: CodexActionProposal] = [:]
        for line in text
            .split(separator: "\n")
        {
            guard let row = decodeActionRow(String(line)) else {
                continue
            }

            for candidate in actionCandidates(from: row) {
                let existing = actions[candidate.id]
                actions[candidate.id] = CodexActionProposal(
                    id: candidate.id,
                    title: candidate.title ?? existing?.title ?? row.title ?? row.id,
                    detail: candidate.detail ?? existing?.detail ?? row.detail?.displayText,
                    status: row.status.flatMap(CodexActionStatus.init(rawValue:)) ?? existing?.status ?? .pending,
                    threadID: row.threadID ?? existing?.threadID,
                    automationID: row.automationID ?? existing?.automationID,
                    jobID: row.jobID ?? existing?.jobID,
                    targetPath: candidate.targetPath ?? existing?.targetPath ?? row.detail?.targetPath,
                    createdAt: row.createdAt?.date ?? existing?.createdAt,
                    updatedAt: row.updatedAt?.date ?? row.createdAt?.date ?? existing?.updatedAt
                )
            }
        }

        return actions.values
            .sorted {
                let lhs = $0.updatedAt ?? $0.createdAt ?? .distantPast
                let rhs = $1.updatedAt ?? $1.createdAt ?? .distantPast
                if lhs == rhs {
                    return $0.id < $1.id
                }
                return lhs > rhs
            }
    }

    private var actionLogURL: URL {
        codexHome.appendingPathComponent("codexlog-actions.jsonl")
    }

    private func decodeActionRow(_ line: String) -> ActionRow? {
        let decoder = JSONDecoder()
        if let data = line.data(using: .utf8),
           let row = try? decoder.decode(ActionRow.self, from: data) {
            return row
        }

        let sanitized = line.replacingOccurrences(of: #"\'"#, with: "'")
        guard sanitized != line,
              let data = sanitized.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(ActionRow.self, from: data)
    }

    private func actionCandidates(from row: ActionRow) -> [ActionCandidate] {
        guard let detail = row.detail,
              detail.objectValue != nil else {
            return [ActionCandidate(
                id: row.id,
                title: row.title,
                detail: row.detail?.displayText,
                targetPath: row.detail?.targetPath
            )]
        }

        let expanded: [ActionCandidate]
        switch row.automationID {
        case "daily-codex-guidance-review":
            expanded = codexGuidanceCandidates(from: row, detail: detail)
        case "daily-obsidian-backlink-proposals":
            expanded = backlinkCandidates(from: row, detail: detail)
        case "daily-note-to-genuine-ideas":
            expanded = ideaCandidates(from: row, detail: detail)
        default:
            expanded = []
        }

        if expanded.isEmpty {
            return [ActionCandidate(
                id: row.id,
                title: row.title,
                detail: row.detail?.displayText,
                targetPath: row.detail?.targetPath
            )]
        }
        return expanded
    }

    private func codexGuidanceCandidates(from row: ActionRow, detail: JSONValue) -> [ActionCandidate] {
        let targetPath = detail.string(for: "target_path") ?? detail.string(for: "path")
        let text = detail.string(for: "proposed_text")
            ?? detail.string(for: "proposed_initial_contents")
            ?? detail.string(for: "replace_with")
        guard let text else {
            return []
        }

        return approvalChunks(from: text).map { chunk in
            ActionCandidate(
                id: childID(parentID: row.id, kind: "point", scope: targetPath, value: chunk),
                title: "\(fileTitle(targetPath)): \(oneLine(chunk, limit: 76))",
                detail: chunk,
                targetPath: targetPath
            )
        }
    }

    private func backlinkCandidates(from row: ActionRow, detail: JSONValue) -> [ActionCandidate] {
        let targetPath = detail.string(for: "source_note_path") ?? detail.object(for: "approval_patch")?.string(for: "path")
        let currentLinks = Set(detail.stringArray(for: "current_related"))
        let proposedLinks = detail.array(for: "proposed_links")?
            .compactMap { proposedLink in
                proposedLink.objectValue?.string(for: "link") ?? proposedLink.stringValue
            } ?? []
        let newLinks = proposedLinks.filter { !currentLinks.contains($0) }

        return newLinks.map { link in
            ActionCandidate(
                id: childID(parentID: row.id, kind: "link", scope: targetPath, value: link),
                title: "Add Related link: \(link)",
                detail: "Add \(link) to \(fileTitle(targetPath)).",
                targetPath: targetPath
            )
        }
    }

    private func ideaCandidates(from row: ActionRow, detail: JSONValue) -> [ActionCandidate] {
        let targetPath = detail.string(for: "target_path")
        let ideas = detail.array(for: "ideas")?.compactMap(ideaText) ?? []
        let chunks = ideas.isEmpty
            ? approvalChunks(from: detail.string(for: "addition_text") ?? "")
            : ideas

        return chunks.map { idea in
            ActionCandidate(
                id: childID(parentID: row.id, kind: "idea", scope: targetPath, value: idea),
                title: row.title ?? "Add idea: \(oneLine(idea, limit: 72))",
                detail: idea,
                targetPath: targetPath
            )
        }
    }

    private func ideaText(_ value: JSONValue) -> String? {
        if let string = value.stringValue {
            return string
        }
        return value.objectValue?.string(for: "text")
            ?? value.objectValue?.string(for: "idea")
            ?? value.objectValue?.string(for: "addition_text")
    }

    private func approvalChunks(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var chunks: [String] = []
        var current: [String] = []
        var foundMarkedPoint = false

        func flush() {
            let value = current.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                chunks.append(value)
            }
            current = []
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                continue
            }
            if let point = strippedPointMarker(line) {
                foundMarkedPoint = true
                flush()
                current = [point]
            } else if foundMarkedPoint, !current.isEmpty {
                current.append(line)
            }
        }

        if foundMarkedPoint {
            flush()
            return chunks
        }

        return lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func strippedPointMarker(_ line: String) -> String? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }

        guard let dot = line.firstIndex(of: ".") else {
            return nil
        }
        let prefix = line[..<dot]
        guard !prefix.isEmpty,
              prefix.count <= 3,
              prefix.allSatisfy(\.isNumber) else {
            return nil
        }
        return String(line[line.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
    }

    private func childID(parentID: String, kind: String, scope: String?, value: String) -> String {
        "\(parentID)::\(kind)::\(stableFingerprint("\(scope ?? "")\n\(value)"))"
    }

    private func stableFingerprint(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private func fileTitle(_ path: String?) -> String {
        guard let path, !path.isEmpty else {
            return "File"
        }
        return URL(fileURLWithPath: path).lastPathComponent.nilIfEmpty ?? path
    }

    private func oneLine(_ text: String, limit: Int) -> String {
        let collapsed = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard collapsed.count > limit else {
            return collapsed
        }
        return String(collapsed.prefix(limit - 1)) + "..."
    }

    private func appendActionDecision(id: String, action: CodexActionProposal?, status: CodexActionStatus) throws {
        try fileManager.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let row = ActionRow(
            id: id,
            title: action?.title,
            detail: action.flatMap(decisionDetail),
            status: status.rawValue,
            threadID: action?.threadID,
            automationID: action?.automationID,
            jobID: action?.jobID,
            createdAt: nil,
            updatedAt: FlexibleTimestamp(date: Date())
        )
        var data = Data()
        if let existing = try? Data(contentsOf: actionLogURL), !existing.isEmpty, existing.last != 10 {
            data.append(10)
        }
        data.append(try JSONEncoder().encode(row))
        data.append(10)

        if fileManager.fileExists(atPath: actionLogURL.path) {
            let handle = try FileHandle(forWritingTo: actionLogURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } else {
            try data.write(to: actionLogURL, options: [.atomic])
        }
    }

    private func decisionDetail(for action: CodexActionProposal) -> JSONValue? {
        var object: [String: JSONValue] = [:]
        if let targetPath = action.targetPath {
            object["target_path"] = .string(targetPath)
        }
        if let detail = action.detail {
            object["text"] = .string(detail)
        }
        return object.isEmpty ? nil : .object(object)
    }

    private func unquote(_ value: String) -> String {
        var value = value
        if let comment = value.firstIndex(of: "#") {
            value = String(value[..<comment]).trimmingCharacters(in: .whitespaces)
        }
        guard value.count >= 2, value.first == "\"", value.last == "\"" else {
            return value
        }
        return String(value.dropFirst().dropLast())
    }

    private func millisecondsDate(_ raw: String) -> Date? {
        guard let milliseconds = Double(raw) else {
            return nil
        }
        return Date(timeIntervalSince1970: milliseconds / 1_000)
    }

    private func secondsDate(_ raw: String) -> Date? {
        guard let seconds = Double(raw) else {
            return nil
        }
        return Date(timeIntervalSince1970: seconds)
    }

    private func timestampDate(_ raw: String) -> Date? {
        if let value = Double(raw) {
            let seconds = value > 10_000_000_000 ? value / 1_000 : value
            return Date(timeIntervalSince1970: seconds)
        }
        return ISO8601DateFormatter().date(from: raw)
    }

    private func latestDate(_ dates: Date?...) -> Date? {
        dates.compactMap { $0 }.max()
    }
}

private enum ProcessRunner {
    static func run(_ arguments: [String]) throws -> String {
        guard let executable = arguments.first else {
            return ""
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(arguments.dropFirst())

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return String(data: data, encoding: .utf8) ?? ""
    }
}

private struct SessionIndexRow: Decodable {
    var id: String
    var threadName: String
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case threadName = "thread_name"
        case updatedAt = "updated_at"
    }
}

private struct ActionRow: Codable {
    var id: String
    var title: String?
    var detail: JSONValue?
    var status: String?
    var threadID: String?
    var automationID: String?
    var jobID: String?
    var createdAt: FlexibleTimestamp?
    var updatedAt: FlexibleTimestamp?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case status
        case threadID = "thread_id"
        case automationID = "automation_id"
        case jobID = "job_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct ActionCandidate {
    var id: String
    var title: String?
    var detail: String?
    var targetPath: String?
}

private struct CodexSessionTail {
    var state: CodexThreadRunState
    var lastEvent: String?
}

private enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    var stringValue: String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case let .object(value) = self {
            return value
        }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case let .array(value) = self {
            return value
        }
        return nil
    }

    var displayText: String? {
        switch self {
        case let .string(value):
            return value
        case let .object(value):
            return value.string(for: "addition_text")
                ?? value.string(for: "proposed_text")
                ?? value.string(for: "proposed_initial_contents")
                ?? value.string(for: "text")
                ?? value.string(for: "rationale")
                ?? value.string(for: "source_context")
        case let .array(values):
            let strings = values.compactMap(\.stringValue)
            guard !strings.isEmpty else {
                return nil
            }
            return strings.prefix(3).joined(separator: ", ")
        case .number, .bool, .null:
            return nil
        }
    }

    var targetPath: String? {
        guard let object = objectValue else {
            return nil
        }
        return object.string(for: "target_path")
            ?? object.string(for: "source_note_path")
            ?? object.string(for: "path")
            ?? object.object(for: "approval_patch")?.string(for: "path")
    }

    func string(for key: String) -> String? {
        objectValue?.string(for: key)
    }

    func stringArray(for key: String) -> [String] {
        objectValue?.stringArray(for: key) ?? []
    }

    func object(for key: String) -> [String: JSONValue]? {
        objectValue?.object(for: key)
    }

    func array(for key: String) -> [JSONValue]? {
        objectValue?.array(for: key)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

private extension [String: JSONValue] {
    func string(for key: String) -> String? {
        self[key]?.stringValue
    }

    func stringArray(for key: String) -> [String] {
        self[key]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    func object(for key: String) -> [String: JSONValue]? {
        self[key]?.objectValue
    }

    func array(for key: String) -> [JSONValue]? {
        self[key]?.arrayValue
    }
}

private struct FlexibleTimestamp: Codable, Equatable {
    var rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(date: Date) {
        rawValue = String(Int(date.timeIntervalSince1970 * 1_000))
    }

    var date: Date? {
        if let value = Double(rawValue) {
            let seconds = value > 10_000_000_000 ? value / 1_000 : value
            return Date(timeIntervalSince1970: seconds)
        }
        return ISO8601DateFormatter().date(from: rawValue)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            rawValue = string
        } else if let integer = try? container.decode(Int.self) {
            rawValue = String(integer)
        } else {
            rawValue = String(try container.decode(Double.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
