import SwiftUI

struct PluginView: View {
    @ObservedObject var runtime: Runtime
    @State private var selectedActionID: String?
    @FocusState private var hasKeyboardFocus: Bool

    private var snapshot: CodexSnapshot {
        runtime.snapshot
    }

    private var pendingActions: [CodexActionProposal] {
        snapshot.pendingActions
    }

    private var selectedAction: CodexActionProposal? {
        if let selectedActionID,
           let action = pendingActions.first(where: { $0.id == selectedActionID }) {
            return action
        }
        return pendingActions.first
    }

    private var selectedActionIndex: Int? {
        guard let selectedAction else {
            return nil
        }
        return pendingActions.firstIndex { $0.id == selectedAction.id }
    }

    private var actionIDs: [String] {
        pendingActions.map(\.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            statusStrip
            actionQueue
            liveThreads
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .focusable()
        .focused($hasKeyboardFocus)
        .focusEffectDisabled()
        .onAppear {
            hasKeyboardFocus = true
            syncSelectedAction()
        }
        .onChange(of: actionIDs) { _, _ in
            syncSelectedAction()
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                denySelectedAction()
            case .right:
                approveSelectedAction()
            case .up:
                moveSelection(-1)
            case .down:
                moveSelection(1)
            default:
                break
            }
        }
        .animation(.snappy(duration: 0.22), value: actionIDs)
    }

    private var statusStrip: some View {
        HStack(spacing: 8) {
            StatusPill(title: "Queue", value: "\(pendingActions.count)")
            StatusPill(title: "Active", value: "\(snapshot.runningThreads.count)")
            StatusPill(
                title: "Issues",
                value: "\(issueCount)",
                tint: issueCount > 0 ? .red : .secondary,
                isEmphasized: issueCount > 0
            )
        }
    }

    private var liveThreads: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: "Running Threads",
                value: "\(snapshot.runningThreads.count) active"
            )

            if snapshot.runningThreads.isEmpty {
                EmptyLine(text: "No active Codex threads")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(snapshot.runningThreads.prefix(2)) { runningThread in
                        RunningThreadRow(
                            runningThread: runningThread,
                            referenceDate: snapshot.generatedAt
                        )
                    }
                }
            }
        }
    }

    private var actionQueue: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: "Action Queue",
                value: actionQueueValue
            )

            if pendingActions.isEmpty {
                EmptyLine(text: "No approvals pending")
            } else if let selectedAction {
                ActionCard(
                    action: selectedAction,
                    threadTitle: threadTitle(for: selectedAction.threadID),
                    queuePosition: selectedActionIndex.map { "\($0 + 1) of \(pendingActions.count)" },
                    referenceDate: snapshot.generatedAt,
                    approve: {
                        approve(selectedAction)
                    },
                    deny: {
                        deny(selectedAction)
                    }
                )
                .id(selectedAction.id)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                EmptyLine(text: "No approvals pending")
            }
        }
    }

    private var actionQueueValue: String {
        "\(pendingActions.count) pending"
    }

    private var issueCount: Int {
        snapshot.jobsNeedingAttention.reduce(0) { $0 + $1.count }
    }

    private func threadTitle(for threadID: String?) -> String? {
        guard let threadID else {
            return nil
        }
        return snapshot.threads.first { $0.id == threadID }?.title
    }

    private func syncSelectedAction() {
        guard !pendingActions.isEmpty else {
            selectedActionID = nil
            return
        }
        if let selectedActionID,
           pendingActions.contains(where: { $0.id == selectedActionID }) {
            return
        }
        selectedActionID = pendingActions.first?.id
    }

    private func moveSelection(_ offset: Int) {
        guard !pendingActions.isEmpty else {
            return
        }
        let currentIndex = selectedActionIndex ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), pendingActions.count - 1)
        selectedActionID = pendingActions[nextIndex].id
    }

    private func approveSelectedAction() {
        guard let selectedAction else {
            return
        }
        approve(selectedAction)
    }

    private func denySelectedAction() {
        guard let selectedAction else {
            return
        }
        deny(selectedAction)
    }

    private func approve(_ action: CodexActionProposal) {
        withAnimation(.snappy(duration: 0.22)) {
            runtime.approve(action)
        }
        syncSelectedAction()
    }

    private func deny(_ action: CodexActionProposal) {
        withAnimation(.snappy(duration: 0.22)) {
            runtime.deny(action)
        }
        syncSelectedAction()
    }
}
