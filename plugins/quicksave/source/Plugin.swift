import AppKit
import Carbon
import Core
import SwiftUI

public enum Plugin {
    public static let block = Block(
        id: "quicksave",
        title: "Quicksave",
        defaultSize: GridSize(width: 8, height: 8)
    ) { context in
        Runtime(context: context)
    }
}

@MainActor
final class Runtime: ObservableObject, BlockRuntime {
    @Published var noteText = ""
    @Published private(set) var notes: [QuicksaveNote] = []
    @Published private(set) var status = "Ready"

    private let context: Block.Context
    private let capture = ClipboardCapture()
    private let noteWriter = ContextNoteWriter()
    private let history = QuicksaveHistory()
    private var isRunning = false
    private var captureShortcutToken: KeyboardShortcutToken?
    private var lastCaptureURLs: [URL] = []

    init(context: Block.Context) {
        self.context = context
    }

    func start() {
        guard !isRunning else {
            return
        }

        isRunning = true
        captureShortcutToken = context.keyboardShortcuts?.registerKeyboardShortcut(
            KeyboardShortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(optionKey))
        ) { [weak self] in
            self?.captureClipboard()
        }
        reloadNotes()
    }

    func stop() {
        if let captureShortcutToken {
            context.keyboardShortcuts?.unregisterKeyboardShortcut(captureShortcutToken)
            self.captureShortcutToken = nil
        }
        isRunning = false
    }

    func refresh() async {
        reloadNotes()
    }

    func makeView() -> AnyView {
        AnyView(ContentView(runtime: self))
    }

    func captureClipboard() {
        do {
            let result = try capture.captureClipboard(to: inboxURL)
            lastCaptureURLs = result.savedURLs
            status = statusText(for: result)
            reloadNotes()
        } catch {
            status = error.localizedDescription
        }
    }

    func saveNote() {
        let targets = latestCaptureTargets()
        do {
            _ = try noteWriter.save(note: noteText, for: targets, in: inboxURL)
            noteText = ""
            status = targets.isEmpty ? "Saved note" : "Saved note for \(targets[0].lastPathComponent)"
            reloadNotes()
        } catch {
            status = error.localizedDescription
        }
    }

    func openInbox() {
        let inbox = inboxURL
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        NSWorkspace.shared.open(inbox)
    }

    private func reloadNotes() {
        do {
            notes = try history.todayNotes(in: inboxURL, now: context.now ?? Date())
        } catch {
            status = error.localizedDescription
        }
    }

    private func latestCaptureTargets() -> [URL] {
        if !lastCaptureURLs.isEmpty {
            return lastCaptureURLs
        }
        guard let latest = latestCaptureURL() else {
            return []
        }
        return [latest]
    }

    private func latestCaptureURL() -> URL? {
        let inbox = inboxURL
        guard FileManager.default.fileExists(atPath: inbox.path) else {
            return nil
        }

        return try? FileManager.default.contentsOfDirectory(
            at: inbox,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { !ContextNoteWriter.isNoteFile($0) }
        .sorted { modificationDate($0) > modificationDate($1) }
        .first
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private var inboxURL: URL {
        context.storageDirectory ?? QuicksaveSettings.inboxURL()
    }

    private func statusText(for result: CaptureResult) -> String {
        if result.savedURLs.count == 1, let savedURL = result.firstSavedURL {
            return "Saved \(savedURL.pathExtension.uppercased())"
        }
        return "Saved \(result.savedURLs.count) items"
    }
}

private struct ContentView: View {
    @ObservedObject var runtime: Runtime
    private var canSave: Bool { !runtime.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $runtime.noteText)
                    .font(QuickCaptureStyle.bodyFont)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)

                if runtime.noteText.isEmpty {
                    Text("Write a note for the latest capture")
                        .font(QuickCaptureStyle.bodyFont)
                        .foregroundStyle(QuickCaptureStyle.subtleText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 15)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 92)
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

                Spacer()

                Text("\(runtime.notes.count) today")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(QuickCaptureStyle.mutedText)
            }
        }
    }

    private var recentNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QuickCaptureStyle.secondaryText)
                Spacer()
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
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
                if let captureName = note.captureName {
                    Text(displayName(for: captureName))
                        .font(.caption2)
                        .foregroundStyle(QuickCaptureStyle.mutedText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Text(note.text)
                .font(QuickCaptureStyle.noteFont)
                .foregroundStyle(QuickCaptureStyle.primaryText)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .quickCaptureCard(fill: QuickCaptureStyle.rowFill, stroke: QuickCaptureStyle.rowStroke)
    }

    private var timeString: String {
        Self.timeFormatter.string(from: note.modifiedAt)
    }

    private func displayName(for captureName: String) -> String {
        var name = captureName
        if let range = name.range(of: #"^\d{4}-\d{2}-\d{2}T"#, options: .regularExpression) {
            name.removeSubrange(range)
        }
        name = name.replacingOccurrences(of: "-00.000Z", with: "")
        name = name.replacingOccurrences(of: "-", with: ":")
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

    static let primaryText = Color.white.opacity(0.90)
    static let secondaryText = Color.white.opacity(0.66)
    static let mutedText = Color.white.opacity(0.46)
    static let subtleText = Color.white.opacity(0.38)
    static let disabledText = Color.white.opacity(0.35)
    static let primaryIcon = Color.white.opacity(0.82)

    static let softFill = Color.white.opacity(0.055)
    static let inputFill = Color.white.opacity(0.075)
    static let buttonFill = Color.white.opacity(0.08)
    static let rowFill = Color.white.opacity(0.065)
    static let emptyFill = Color.white.opacity(0.045)
    static let activeFill = Color.white.opacity(0.18)
    static let disabledFill = Color.white.opacity(0.07)
    static let inputStroke = Color.white.opacity(0.10)
    static let rowStroke = Color.white.opacity(0.07)
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
