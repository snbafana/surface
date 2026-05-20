import Core
import SwiftUI

public enum Plugin {
    public static let block = Block(
        id: "codexlog",
        title: "Codex Log",
        defaultSize: GridSize(width: 10, height: 8)
    ) { context in
        let codexHome = context.storageDirectory ?? CodexStateReader.defaultCodexHome
        return Runtime(
            reader: CodexStateReader(
                codexHome: codexHome,
                includeProcesses: context.storageDirectory == nil
            )
        )
    }
}

@MainActor
final class Runtime: ObservableObject, BlockRuntime {
    @Published private(set) var isRunning = false
    @Published private(set) var snapshot = CodexSnapshot()
    private let reader: CodexStateReader

    init(reader: CodexStateReader = CodexStateReader()) {
        self.reader = reader
    }

    func start() {
        isRunning = true
        reload()
    }

    func stop() {
        isRunning = false
    }

    func refresh() async {
        reload()
    }

    func makeView() -> AnyView {
        AnyView(ContentView(runtime: self))
    }

    func approve(_ action: CodexActionProposal) {
        try? reader.approveAction(action.id)
        reload()
    }

    func deny(_ action: CodexActionProposal) {
        try? reader.denyAction(action.id)
        reload()
    }

    func cancel(_ action: CodexActionProposal) {
        try? reader.cancelAction(action.id)
        reload()
    }

    private func reload() {
        snapshot = reader.snapshot()
    }
}

private struct ContentView: View {
    @ObservedObject var runtime: Runtime

    private var snapshot: CodexSnapshot {
        runtime.snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if runtime.isRunning && !snapshot.runningThreads.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.65)
                }
                Text(runtime.isRunning ? "Reading local Codex" : "Stopped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(snapshot.processes.reduce(0) { $0 + $1.count }) procs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            section("Running Now", count: snapshot.runningThreads.count) {
                if snapshot.runningThreads.isEmpty {
                    Text("No running threads detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.runningThreads.prefix(3)) { runningThread in
                        HStack(spacing: 6) {
                            Text(runningThread.thread.title)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(runningThread.logCount)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            section("Needs Attention", count: snapshot.threadsNeedingAttention.count + snapshot.failedJobs.count) {
                if snapshot.threadsNeedingAttention.isEmpty && snapshot.failedJobs.isEmpty {
                    Text("No failed jobs or pending thread actions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.threadsNeedingAttention.prefix(2)) { thread in
                        Text(thread.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    ForEach(snapshot.failedJobs.prefix(2)) { job in
                        Text("\(job.kind): \(job.count) \(job.status)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            section("Jobs", count: snapshot.runningJobs.count + snapshot.finishedJobs.count + snapshot.jobsNeedingAttention.count) {
                HStack(spacing: 8) {
                    jobPill("Running", snapshot.runningJobs.reduce(0) { $0 + $1.count }, systemImage: "arrow.triangle.2.circlepath")
                    jobPill("Done", snapshot.finishedJobs.reduce(0) { $0 + $1.count }, systemImage: "checkmark.circle")
                    jobPill("Look", snapshot.jobsNeedingAttention.reduce(0) { $0 + $1.count }, systemImage: "exclamationmark.triangle")
                }
            }

            section("Action Queue", count: snapshot.pendingActions.count) {
                if let action = snapshot.pendingActions.first {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(action.title)
                            .font(.caption)
                            .lineLimit(2)
                        if let detail = action.detail {
                            Text(detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        HStack(spacing: 8) {
                            actionButton("Approve", systemImage: "checkmark") {
                                runtime.approve(action)
                            }
                            actionButton("Deny", systemImage: "xmark") {
                                runtime.deny(action)
                            }
                            actionButton("Cancel", systemImage: "stop") {
                                runtime.cancel(action)
                            }
                        }
                    }
                } else {
                    Text("No proposed actions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(snapshot.activeAutomations.count) active automations")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func section<Content: View>(
        _ title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    private func jobPill(_ title: String, _ count: Int, systemImage: String) -> some View {
        Label("\(count)", systemImage: systemImage)
            .font(.caption2)
            .help(title)
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(.borderless)
        .help(title)
    }
}
