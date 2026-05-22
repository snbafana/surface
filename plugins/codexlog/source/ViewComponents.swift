import Foundation
import SwiftUI

struct StatusPill: View {
    var title: String
    var value: String
    var tint: Color = .secondary
    var isEmphasized = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(isEmphasized ? tint : .primary)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
    }
}

struct SectionHeader: View {
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

struct RunningThreadRow: View {
    let runningThread: CodexRunningThread

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(stateColor)
                .frame(width: 7, height: 7)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(runningThread.thread.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(lastSeenText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(metadata)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }

    private var lastSeenText: String {
        guard let lastSeenAt = runningThread.lastSeenAt else {
            return "active"
        }
        if abs(lastSeenAt.timeIntervalSinceNow) < 2 {
            return "now"
        }
        return Self.relativeDateFormatter.localizedString(for: lastSeenAt, relativeTo: Date())
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var stateColor: Color {
        switch runningThread.state {
        case .running:
            return .green
        case .interrupted:
            return .orange
        case .complete:
            return .secondary
        case .unknown:
            return .accentColor
        }
    }

    private var metadata: String {
        var parts: [String] = []
        if let cwd = runningThread.thread.cwd, !cwd.isEmpty {
            parts.append(shortPath(cwd))
        }
        if let lastEvent = runningThread.lastEvent, !lastEvent.isEmpty {
            parts.append(lastEvent)
        }
        if runningThread.childThreadCount > 0 {
            parts.append("\(runningThread.childThreadCount) child")
        }
        if runningThread.logCount > 0 {
            parts.append("\(runningThread.logCount) events")
        }
        return parts.isEmpty ? runningThread.state.rawValue : parts.joined(separator: " · ")
    }

    private func shortPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let displayPath = path.hasPrefix(home) ? "~" + String(path.dropFirst(home.count)) : path
        let components = displayPath.split(separator: "/").map(String.init)
        guard components.count > 3 else {
            return displayPath
        }
        return components.suffix(3).joined(separator: "/")
    }
}

struct ActionCard: View {
    let action: CodexActionProposal
    let threadTitle: String?
    let queuePosition: String?
    let approve: () -> Void
    let deny: () -> Void
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let sourceText {
                    Text(sourceText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
                }
                Spacer(minLength: 6)
                if let queuePosition {
                    Text(queuePosition)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(action.title)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            metadataView

            if let detail = action.detail {
                Divider().opacity(0.35)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.82))
                    .lineLimit(4)
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
        .background(cardTint.opacity(abs(dragOffset) > 0 ? 0.10 : 0.05), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardTint.opacity(abs(dragOffset) > 0 ? 0.35 : 0.12), lineWidth: 1)
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
                .frame(height: 30)
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
        if proposedText != nil || !contextLines.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                if contextLines.isEmpty {
                    if let proposedText {
                        Text(proposedText)
                            .lineLimit(1)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(contextLines.first ?? "")
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if let proposedText {
                            Text(proposedText)
                                .lineLimit(1)
                        }
                    }
                }
                ForEach(contextLines.dropFirst(), id: \.self) { contextLine in
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

struct EmptyLine: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}
