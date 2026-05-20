import Core
import Foundation
import SwiftUI

public enum Plugin {
    public static let block = Block(
        id: "codexlog",
        title: "Codex Log",
        defaultSize: GridSize(width: 8, height: 10)
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
    private var refreshTask: Task<Void, Never>?

    init(reader: CodexStateReader = CodexStateReader()) {
        self.reader = reader
    }

    func start() {
        guard !isRunning else {
            return
        }
        isRunning = true
        reload()
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, self.isRunning else {
                    return
                }
                self.reload()
            }
        }
    }

    func stop() {
        isRunning = false
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        reload()
    }

    func makeView() -> AnyView {
        AnyView(ContentView(runtime: self))
    }

    func approve(_ action: CodexActionProposal) {
        try? reader.approveAction(action)
        reload()
    }

    func deny(_ action: CodexActionProposal) {
        try? reader.denyAction(action)
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
        VStack(alignment: .leading, spacing: 10) {
            actionQueue
            Divider().opacity(0.45)
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
                        RunningThreadRow(runningThread: runningThread)
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

private struct SectionHeader: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
            Spacer()
            Text(value)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct RunningThreadRow: View {
    let runningThread: CodexRunningThread

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(.green)
                .frame(width: 7, height: 7)
            Text(runningThread.thread.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(lastSeenText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var lastSeenText: String {
        guard let lastSeenAt = runningThread.lastSeenAt else {
            return "active"
        }
        return Self.relativeDateFormatter.localizedString(for: lastSeenAt, relativeTo: Date())
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

private struct ActionCard: View {
    let action: CodexActionProposal
    let threadTitle: String?
    let queuePosition: String?
    let approve: () -> Void
    let deny: () -> Void
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(action.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let queuePosition {
                    Text(queuePosition)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            metadataView

            if let detail = action.detail {
                Divider().opacity(0.35)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.82))
                    .lineLimit(7)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                actionButton("Deny", systemImage: "xmark", tint: .red) {
                    decide(.denied)
                }
                actionButton("Approve", systemImage: "checkmark", tint: .green) {
                    decide(.approved)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardTint.opacity(abs(dragOffset) > 0 ? 0.10 : 0.055), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardTint.opacity(abs(dragOffset) > 0 ? 0.35 : 0.10), lineWidth: 1)
            }
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset / 48)))
        .gesture(
            DragGesture(minimumDistance: 16)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    if value.translation.width > 90 {
                        decide(.approved)
                    } else if value.translation.width < -90 {
                        decide(.denied)
                    } else {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: dragOffset)
    }

    private func actionButton(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 26)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
        .help(title)
    }

    @ViewBuilder
    private var metadataView: some View {
        if sourceText != nil || proposedText != nil || !contextLines.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let sourceText {
                        Text(sourceText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if let proposedText {
                        Text(proposedText)
                            .lineLimit(1)
                    }
                }
                ForEach(contextLines, id: \.self) { contextLine in
                    Text(contextLine)
                        .lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var sourceText: String? {
        if let automationID = action.automationID, !automationID.isEmpty {
            return "Source: \(sourceName(for: automationID))"
        }
        if let jobID = action.jobID, !jobID.isEmpty {
            return "Job: \(shortIdentifier(jobID))"
        }
        return nil
    }

    private var contextLines: [String] {
        var values: [String] = []
        if let targetPath = action.targetPath, !targetPath.isEmpty {
            values.append("File: \(shortPath(targetPath))")
        }
        if let threadLabel {
            values.append("Thread: \(threadLabel)")
        }
        if let jobID = action.jobID, !jobID.isEmpty, action.automationID != nil {
            values.append("Job: \(shortIdentifier(jobID))")
        }
        return values
    }

    private var proposedText: String? {
        guard let createdAt = action.createdAt else {
            return nil
        }
        return Self.relativeDateFormatter.localizedString(for: createdAt, relativeTo: Date())
    }

    private var threadLabel: String? {
        if let threadTitle, !threadTitle.isEmpty {
            return threadTitle
        }
        guard let threadID = action.threadID, !threadID.isEmpty else {
            return nil
        }
        return shortIdentifier(threadID)
    }

    private func shortIdentifier(_ value: String) -> String {
        guard value.count > 12 else {
            return value
        }
        return String(value.prefix(6)) + "..." + String(value.suffix(4))
    }

    private func sourceName(for automationID: String) -> String {
        switch automationID {
        case "daily-codex-guidance-review":
            return "Codex guidance"
        case "daily-obsidian-backlink-proposals":
            return "Backlinks"
        case "daily-note-to-genuine-ideas":
            return "Genuine Ideas"
        default:
            return automationID
        }
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var cardTint: Color {
        if dragOffset > 0 {
            return .green
        }
        if dragOffset < 0 {
            return .red
        }
        return .primary
    }

    private func decide(_ status: CodexActionStatus) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
            dragOffset = status == .approved ? 420 : -420
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            switch status {
            case .approved:
                approve()
            case .denied:
                deny()
            case .pending, .cancelled, .completed, .failed:
                break
            }
        }
    }

    private func shortPath(_ path: String) -> String {
        let components = path.split(separator: "/").map(String.init)
        guard components.count > 2 else {
            return path
        }
        return components.suffix(2).joined(separator: "/")
    }
}

private struct EmptyLine: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}
