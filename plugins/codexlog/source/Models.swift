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

struct CodexSessionTail {
    var state: CodexThreadRunState
    var lastEvent: String?
}
