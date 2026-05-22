import Foundation

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
        try actionLog.appendDecision(id: id, action: nil, status: .approved)
    }

    func approveAction(_ action: CodexActionProposal) throws {
        try actionLog.appendDecision(id: action.id, action: action, status: .approved)
    }

    func denyAction(_ id: String) throws {
        try actionLog.appendDecision(id: id, action: nil, status: .denied)
    }

    func denyAction(_ action: CodexActionProposal) throws {
        try actionLog.appendDecision(id: action.id, action: action, status: .denied)
    }

    func cancelAction(_ id: String) throws {
        try actionLog.appendDecision(id: id, action: nil, status: .cancelled)
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
        actionLog.read()
    }

    private var actionLog: ActionLog {
        ActionLog(codexHome: codexHome, fileManager: fileManager)
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
