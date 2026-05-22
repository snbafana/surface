import AppKit
import Carbon
import Core
import SwiftUI

@MainActor
final class Runtime: ObservableObject, BlockRuntime {
    @Published var noteText = ""
    @Published private(set) var notes: [QuicksaveNote] = []
    @Published private(set) var status = "Ready"
    @Published private(set) var lastSavedAt: Date?

    private let context: Block.Context
    private let capture = ClipboardCapture()
    private let noteWriter = ContextNoteWriter()
    private let history = QuicksaveHistory()
    private var isRunning = false
    private var captureShortcutToken: KeyboardShortcutToken?
    private var lastCaptureURLs: [URL] = []
    private var consumedCaptureURLs = Set<URL>()

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
            consumedCaptureURLs.subtract(result.savedURLs.map(canonicalCaptureURL))
            let captureStatus = statusText(for: result)
            if shouldAppendToObsidian {
                do {
                    try appendCapturesToObsidian(result.savedURLs)
                    status = "\(captureStatus) + Obsidian"
                } catch {
                    status = "\(captureStatus); Obsidian error"
                }
            } else {
                status = captureStatus
            }
            reloadNotes()
        } catch {
            status = error.localizedDescription
        }
    }

    func saveNote() {
        let targets = latestCaptureTargets()
        do {
            let now = context.now ?? Date()
            _ = try noteWriter.save(note: noteText, for: targets, in: inboxURL, now: now)
            var obsidianError = false
            if shouldAppendToObsidian {
                do {
                    try appendNoteToObsidian(noteText, targets: targets, now: now)
                } catch {
                    obsidianError = true
                }
            }
            noteText = ""
            lastSavedAt = now
            let savedStatus = targets.isEmpty ? "Saved note" : "Saved note with capture"
            if obsidianError {
                status = "\(savedStatus); Obsidian error"
            } else if shouldAppendToObsidian {
                status = "\(savedStatus) + Obsidian"
            } else {
                status = savedStatus
            }
            markCaptureTargetsConsumed(targets)
            reloadNotes()
        } catch {
            status = error.localizedDescription
        }
    }

    func clearDraft() {
        noteText = ""
        status = "Draft cleared"
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
            return lastCaptureURLs.filter { !consumedCaptureURLs.contains(canonicalCaptureURL($0)) }
        }
        guard let latest = latestCaptureURL() else {
            return []
        }
        guard !consumedCaptureURLs.contains(canonicalCaptureURL(latest)) else {
            return []
        }
        return [latest]
    }

    private func markCaptureTargetsConsumed(_ targets: [URL]) {
        guard !targets.isEmpty else {
            return
        }
        consumedCaptureURLs.formUnion(targets.map(canonicalCaptureURL))
        lastCaptureURLs.removeAll()
    }

    private func canonicalCaptureURL(_ url: URL) -> URL {
        url.standardizedFileURL
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

    private var shouldAppendToObsidian: Bool {
        context.allowsExternalWrites
    }

    private func appendCapturesToObsidian(_ captureURLs: [URL]) throws {
        guard !captureURLs.isEmpty else {
            throw ObsidianAppendError.noCapture
        }

        let writer = obsidianDailyNotes()
        let now = context.now ?? Date()
        for captureURL in captureURLs {
            let note = try ContextNoteWriter.noteText(for: captureURL)
            _ = try writer.append(captureURL: captureURL, note: note, date: now)
        }
    }

    private func appendNoteToObsidian(_ note: String, targets: [URL], now: Date) throws {
        let writer = obsidianDailyNotes()
        if targets.isEmpty {
            _ = try writer.append(note: note, date: now)
        } else {
            _ = try writer.appendNotes(for: targets, note: note, date: now)
            lastCaptureURLs = targets
        }
    }

    private func obsidianDailyNotes() -> ObsidianDailyNotes {
        ObsidianDailyNotes(
            dailyNotesDirectory: QuicksaveSettings.obsidianDailyNotesURL(),
            vaultDirectory: QuicksaveSettings.obsidianVaultURL(),
            resolveDailyNote: ObsidianDailyNotes.obsidianTemplateDailyNoteResolver(
                vaultURL: QuicksaveSettings.obsidianVaultURL(),
                templateURL: QuicksaveSettings.obsidianDailyTemplateURL()
            )
        )
    }

    private func statusText(for result: CaptureResult) -> String {
        if result.savedURLs.count == 1, let savedURL = result.firstSavedURL {
            return "Saved \(savedURL.pathExtension.uppercased())"
        }
        return "Saved \(result.savedURLs.count) items"
    }

    var noteCountText: String {
        "\(notes.count) \(notes.count == 1 ? "note" : "notes") today"
    }

    var latestNoteText: String {
        guard let latest = notes.first else {
            return "No notes today"
        }
        let now = context.now ?? Date()
        if abs(latest.modifiedAt.timeIntervalSince(now)) < 60 {
            return "Last note just now"
        }
        return "Last note \(Self.relativeFormatter.localizedString(for: latest.modifiedAt, relativeTo: now))"
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
