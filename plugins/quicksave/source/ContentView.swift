import SwiftUI

struct ContentView: View {
    @ObservedObject var runtime: Runtime
    private var canSave: Bool { !runtime.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            composer
            recentNotes
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(runtime.status)
                .font(.caption.weight(.medium))
                .foregroundStyle(QuickCaptureStyle.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(QuickCaptureStyle.softFill, in: Capsule())

            Text(runtime.noteCountText)
                .font(.caption.weight(.medium))
                .foregroundStyle(QuickCaptureStyle.mutedText)

            Spacer(minLength: 10)

            iconButton("Capture clipboard", systemName: "doc.on.clipboard") {
                runtime.captureClipboard()
            }
            iconButton("Open inbox", systemName: "folder") {
                runtime.openInbox()
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $runtime.noteText)
                    .font(QuickCaptureStyle.bodyFont)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)

                if runtime.noteText.isEmpty {
                    Text("Add a note...")
                        .font(QuickCaptureStyle.bodyFont)
                        .foregroundStyle(QuickCaptureStyle.subtleText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 15)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 70)
            .quickCaptureCard(fill: QuickCaptureStyle.inputFill, stroke: QuickCaptureStyle.inputStroke)

            HStack(spacing: 10) {
                Button {
                    runtime.saveNote()
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(canSave ? QuickCaptureStyle.activeFill : QuickCaptureStyle.disabledFill, in: Capsule())
                .foregroundStyle(canSave ? .white : QuickCaptureStyle.disabledText)
                .disabled(!canSave)

                if canSave {
                    Button {
                        runtime.clearDraft()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(QuickCaptureStyle.mutedText)
                    .help("Clear draft")
                }

                Text(runtime.latestNoteText)
                    .font(.caption)
                    .foregroundStyle(QuickCaptureStyle.mutedText)
                    .lineLimit(1)

                Spacer()
            }
        }
    }

    private var recentNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QuickCaptureStyle.secondaryText)
                Spacer()
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if runtime.notes.isEmpty {
                        EmptyState()
                    } else {
                        ForEach(runtime.notes) { note in
                            NoteRow(note: note)
                        }
                    }
                }
                .padding(.bottom, 2)
            }
        }
    }

    private func iconButton(_ help: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 28, height: 28)
                .quickCaptureCard(radius: 7, fill: QuickCaptureStyle.buttonFill, stroke: QuickCaptureStyle.inputStroke)
        }
        .buttonStyle(.plain)
        .foregroundStyle(QuickCaptureStyle.primaryIcon)
        .help(help)
    }
}

private struct NoteRow: View {
    let note: QuicksaveNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(timeString)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(QuickCaptureStyle.secondaryText)
                if let contextLabel {
                    Text(contextLabel)
                        .font(.caption2)
                        .foregroundStyle(QuickCaptureStyle.mutedText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Text(note.text)
                .font(QuickCaptureStyle.noteFont)
                .foregroundStyle(QuickCaptureStyle.primaryText)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(QuickCaptureStyle.rowStroke)
                .frame(height: 1)
        }
    }

    private var timeString: String {
        Self.timeFormatter.string(from: note.modifiedAt)
    }

    private var contextLabel: String? {
        if let kind = note.captureKind {
            return kind
        }
        guard let captureName = note.captureName else {
            return nil
        }
        return displayName(for: captureName)
    }

    private func displayName(for captureName: String) -> String {
        var name = captureName
        if let range = name.range(of: #"^\d{4}-\d{2}-\d{2}T"#, options: .regularExpression) {
            name.removeSubrange(range)
        }
        name = name.replacingOccurrences(of: "-00.000Z", with: "")
        name = name.replacingOccurrences(of: "-", with: ":")
        if name.range(of: #"^\d{2}:\d{2}(:\d{2})?(\.\d+Z)?$"#, options: .regularExpression) != nil {
            return "capture"
        }
        return name.isEmpty ? "Capture" : name
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct EmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("No notes yet")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(QuickCaptureStyle.secondaryText)
            Text("Capture something or save a note to start today.")
                .font(.caption)
                .foregroundStyle(QuickCaptureStyle.mutedText)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .quickCaptureCard(fill: QuickCaptureStyle.emptyFill, stroke: .clear)
    }
}

private enum QuickCaptureStyle {
    static let bodyFont = Font.system(size: 13)
    static let noteFont = Font.system(size: 12)

    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let mutedText = Color.secondary.opacity(0.75)
    static let subtleText = Color.secondary.opacity(0.55)
    static let disabledText = Color.secondary.opacity(0.45)
    static let primaryIcon = Color.primary

    static let softFill = Color.primary.opacity(0.06)
    static let inputFill = Color.primary.opacity(0.055)
    static let buttonFill = Color.primary.opacity(0.08)
    static let rowFill = Color.primary.opacity(0.06)
    static let emptyFill = Color.primary.opacity(0.045)
    static let activeFill = Color.accentColor.opacity(0.22)
    static let disabledFill = Color.primary.opacity(0.055)
    static let inputStroke = Color.primary.opacity(0.14)
    static let rowStroke = Color.primary.opacity(0.08)
}

private extension View {
    func quickCaptureCard(radius: CGFloat = 8, fill: Color, stroke: Color) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(stroke, lineWidth: 1)
            }
    }
}
