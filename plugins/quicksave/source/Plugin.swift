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
            let result = try capture.captureClipboard(to: QuicksaveSettings.inboxURL())
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
            _ = try noteWriter.save(note: noteText, for: targets, in: QuicksaveSettings.inboxURL())
            noteText = ""
            status = targets.isEmpty ? "Saved note" : "Saved note for \(targets[0].lastPathComponent)"
            reloadNotes()
        } catch {
            status = error.localizedDescription
        }
    }

    func openInbox() {
        let inbox = QuicksaveSettings.inboxURL()
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        NSWorkspace.shared.open(inbox)
    }

    private func reloadNotes() {
        do {
            notes = try history.todayNotes(in: QuicksaveSettings.inboxURL())
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
        let inbox = QuicksaveSettings.inboxURL()
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

    private func statusText(for result: CaptureResult) -> String {
        if result.savedURLs.count == 1, let savedURL = result.firstSavedURL {
            return "Saved \(savedURL.pathExtension.uppercased())"
        }
        return "Saved \(result.savedURLs.count) items"
    }
}

private struct ContentView: View {
    @ObservedObject var runtime: Runtime

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(runtime.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button {
                    runtime.captureClipboard()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(.borderless)
                .help("Capture clipboard")
                Button {
                    runtime.openInbox()
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Open inbox")
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $runtime.noteText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                if runtime.noteText.isEmpty {
                    Text("New note")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 72)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

            HStack {
                Button("Save Note") {
                    runtime.saveNote()
                }
                .disabled(runtime.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                Text("\(runtime.notes.count) today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Previous Notes")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    if runtime.notes.isEmpty {
                        Text("No notes today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(runtime.notes) { note in
                            NoteRow(note: note)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct NoteRow: View {
    let note: QuicksaveNote

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(timeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let captureName = note.captureName {
                    Text(captureName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Text(note.text)
                .font(.caption)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: note.modifiedAt)
    }
}
