import Foundation

struct CodexThreadSummary: Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var cwd: String?
    var updatedAt: Date?
    var isArchived: Bool
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

    var id: String {
        thread.id
    }
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

    func snapshot(threadLimit: Int = 8, runningWindowSeconds: Int = 300) -> CodexSnapshot {
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
        try appendActionDecision(id: id, status: .approved)
    }

    func denyAction(_ id: String) throws {
        try appendActionDecision(id: id, status: .denied)
    }

    func cancelAction(_ id: String) throws {
        try appendActionDecision(id: id, status: .cancelled)
    }

    private func readThreads(limit: Int) -> [CodexThreadSummary] {
        let database = codexHome.appendingPathComponent("state_5.sqlite")
        if fileManager.fileExists(atPath: database.path) {
            let query = """
            select id, replace(title, char(9), ' '), updated_at_ms, archived, replace(cwd, char(9), ' ')
            from threads
            order by updated_at_ms desc
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
                    and ts >= strftime('%s','now') - \(max(1, windowSeconds))
                  group by thread_id
                  order by max(ts) desc
                  limit \(max(1, limit));
                  """
              ]) else {
            return []
        }

        let threadsByID = Dictionary(uniqueKeysWithValues: knownThreads.map { ($0.id, $0) })
        return output
            .split(separator: "\n")
            .compactMap { line in
                let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard columns.count == 3, let logCount = Int(columns[1]) else {
                    return nil
                }

                let id = columns[0]
                let lastSeenAt = secondsDate(columns[2])
                let thread = threadsByID[id] ?? CodexThreadSummary(
                    id: id,
                    title: id,
                    cwd: nil,
                    updatedAt: lastSeenAt,
                    isArchived: false
                )
                return CodexRunningThread(
                    thread: thread,
                    logCount: logCount,
                    lastSeenAt: lastSeenAt
                )
            }
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
                    isArchived: columns[3] == "1"
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
                    updatedAt: row.updatedAt.flatMap(millisecondsDate),
                    isArchived: false
                )
            }
            .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            .prefix(max(1, limit))
            .map { $0 }
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
        guard fileManager.fileExists(atPath: database.path),
              let output = try? runCommand([
                  "/usr/bin/sqlite3",
                  "-separator",
                  "\t",
                  database.path,
                  "select kind, status, count(*) from jobs group by kind, status order by kind, status;"
              ]) else {
            return []
        }

        return output
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
            guard let data = String(line).data(using: .utf8),
                  let row = try? JSONDecoder().decode(ActionRow.self, from: data) else {
                continue
            }

            let existing = actions[row.id]
            actions[row.id] = CodexActionProposal(
                id: row.id,
                title: row.title ?? existing?.title ?? row.id,
                detail: row.detail ?? existing?.detail,
                status: row.status.flatMap(CodexActionStatus.init(rawValue:)) ?? existing?.status ?? .pending,
                threadID: row.threadID ?? existing?.threadID,
                automationID: row.automationID ?? existing?.automationID,
                jobID: row.jobID ?? existing?.jobID,
                createdAt: row.createdAt?.date ?? existing?.createdAt,
                updatedAt: row.updatedAt?.date ?? row.createdAt?.date ?? existing?.updatedAt
            )
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

    private func appendActionDecision(id: String, status: CodexActionStatus) throws {
        try fileManager.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let row = ActionRow(
            id: id,
            title: nil,
            detail: nil,
            status: status.rawValue,
            threadID: nil,
            automationID: nil,
            jobID: nil,
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
    var detail: String?
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

private struct FlexibleTimestamp: Codable, Equatable {
    var rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(date: Date) {
        rawValue = String(Int(date.timeIntervalSince1970 * 1_000))
    }

    var date: Date? {
        guard let value = Double(rawValue) else {
            return nil
        }
        let seconds = value > 10_000_000_000 ? value / 1_000 : value
        return Date(timeIntervalSince1970: seconds)
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
