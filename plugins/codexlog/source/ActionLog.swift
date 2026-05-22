import Foundation

struct ActionLog {
    var codexHome: URL
    var fileManager: FileManager

    func read() -> [CodexActionProposal] {
        guard let data = try? Data(contentsOf: actionLogURL),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }

        var actions: [String: CodexActionProposal] = [:]
        for line in text.split(separator: "\n") {
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

    func appendDecision(id: String, action: CodexActionProposal?, status: CodexActionStatus) throws {
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
        let status = row.status.flatMap(CodexActionStatus.init(rawValue:)) ?? .pending
        guard status == .pending else {
            return [directCandidate(from: row)]
        }

        guard let automationID = row.automationID else {
            return [directCandidate(from: row)]
        }

        switch automationID {
        case "daily-codex-guidance-review":
            guard let detail = row.detail, detail.objectValue != nil else {
                return []
            }
            return codexGuidanceCandidates(from: row, detail: detail)
        case "daily-obsidian-backlink-proposals":
            guard let detail = row.detail, detail.objectValue != nil else {
                return []
            }
            return backlinkCandidates(from: row, detail: detail)
        case "daily-note-to-genuine-ideas":
            guard let detail = row.detail, detail.objectValue != nil else {
                return []
            }
            return ideaCandidates(from: row, detail: detail)
        default:
            return [directCandidate(from: row)]
        }
    }

    private func directCandidate(from row: ActionRow) -> ActionCandidate {
        ActionCandidate(
            id: row.id,
            title: row.title,
            detail: row.detail?.displayText,
            targetPath: row.detail?.targetPath
        )
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
        var proposedLinks = detail.array(for: "proposed_links")?
            .compactMap { proposedLink in
                proposedLink.objectValue?.string(for: "link") ?? proposedLink.stringValue
            } ?? []
        if let link = detail.string(for: "link") {
            proposedLinks.append(link)
        }
        let newLinks = proposedLinks.filter { !currentLinks.contains($0) }

        return newLinks.map { link in
            ActionCandidate(
                id: childID(parentID: row.id, kind: "link", scope: targetPath, value: link),
                title: "\(fileTitle(targetPath)): Related += \(link)",
                detail: backlinkDetail(
                    sourcePath: targetPath,
                    link: link,
                    rationale: detail.string(for: "rationale"),
                    approvalPatch: detail.object(for: "approval_patch")
                ),
                targetPath: targetPath
            )
        }
    }

    private func backlinkDetail(
        sourcePath: String?,
        link: String,
        rationale: String?,
        approvalPatch: [String: JSONValue]?
    ) -> String {
        var lines = [
            "Add to Related:",
            "\(fileTitle(sourcePath)) -> \(link)"
        ]

        if let insert = approvalPatch?.string(for: "insert") {
            lines.append("Patch: \(insert.trimmingCharacters(in: .whitespacesAndNewlines))")
        } else {
            lines.append("Patch: Related += \"\(link)\"")
        }

        if let rationale, !rationale.isEmpty {
            lines.append("Why: \(rationale)")
        }
        return lines.joined(separator: "\n")
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
