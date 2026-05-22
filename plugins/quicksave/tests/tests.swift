import AppKit
import Carbon
import Core
import Testing
@testable import Quicksave

@Suite("Quicksave plugin")
struct QuicksaveTests {
    @MainActor
    @Test func blockCreatesRuntimeAndView() {
        #expect(Plugin.block.id == "quicksave")

        let shortcuts = RecordingShortcuts()
        let runtime = Plugin.block.makeRuntime(Block.Context(keyboardShortcuts: shortcuts))
        runtime.start()
        _ = runtime.makeView()
        runtime.stop()
    }

    @MainActor
    @Test func runtimeRegistersOnlyOptionC() {
        let shortcuts = RecordingShortcuts()
        let runtime = Plugin.block.makeRuntime(Block.Context(keyboardShortcuts: shortcuts))

        runtime.start()
        runtime.stop()

        #expect(shortcuts.registered == [
            KeyboardShortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(optionKey))
        ])
        #expect(shortcuts.unregistered.count == 1)
    }

    @Test func capturesPlainTextAsFlatTextFile() throws {
        let fixture = try QuicksaveFixture()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.setString("hello quicksave", forType: .string)

        let result = try ClipboardCapture().captureClipboard(to: fixture.inboxURL, pasteboard: pasteboard)
        let savedURL = try #require(result.firstSavedURL)

        #expect(result.savedURLs.count == 1)
        #expect(savedURL.pathExtension == "txt")
        #expect(savedURL.deletingLastPathComponent() == fixture.inboxURL)
        #expect(try String(contentsOf: savedURL, encoding: .utf8) == "hello quicksave")
    }

    @Test func savesNotesAndReturnsOnlyTodaysHistory() throws {
        let fixture = try QuicksaveFixture()
        let captureURL = fixture.inboxURL.appendingPathComponent("capture.txt")
        try "saved".write(to: captureURL, atomically: true, encoding: .utf8)
        let now = Date()

        let noteURL = try ContextNoteWriter().save(note: "today note", for: [captureURL], in: fixture.inboxURL, now: now)
        _ = try ContextNoteWriter().save(
            note: "old note",
            for: [],
            in: fixture.inboxURL,
            now: now.addingTimeInterval(-172_800)
        )

        let notes = try QuicksaveHistory().todayNotes(in: fixture.inboxURL, now: now)

        #expect(noteURL.lastPathComponent == "capture.note.txt")
        #expect(notes.map(\.text) == ["today note"])
        #expect(notes.first?.captureName == "capture")
        #expect(notes.first?.captureURL?.resolvingSymlinksInPath() == captureURL.resolvingSymlinksInPath())
        #expect(notes.first?.captureKind == "text")
    }

    @Test func savesStandaloneNotesToFileHistory() throws {
        let fixture = try QuicksaveFixture()
        let now = Date(timeIntervalSince1970: 1_764_077_400)

        let firstURL = try ContextNoteWriter().save(note: "first note", for: [], in: fixture.inboxURL, now: now)
        let secondURL = try ContextNoteWriter().save(
            note: "second note",
            for: [],
            in: fixture.inboxURL,
            now: now.addingTimeInterval(60)
        )
        let notes = try QuicksaveHistory().todayNotes(in: fixture.inboxURL, now: now)

        #expect(firstURL.lastPathComponent.hasSuffix("-note.txt"))
        #expect(secondURL.lastPathComponent.hasSuffix("-note.txt"))
        #expect(notes.map(\.text) == ["second note", "first note"])
        #expect(notes.allSatisfy { $0.captureName == nil })
    }

    @Test func resolvesImageCaptureForSidecarNote() throws {
        let fixture = try QuicksaveFixture()
        let now = Date()
        let imageURL = fixture.inboxURL.appendingPathComponent("capture.png")
        try Data([0x89, 0x50, 0x4e, 0x47]).write(to: imageURL)

        _ = try ContextNoteWriter().save(note: "image note", for: [imageURL], in: fixture.inboxURL, now: now)
        let notes = try QuicksaveHistory().todayNotes(in: fixture.inboxURL, now: now)

        #expect(notes.map(\.text) == ["image note"])
        #expect(notes.first?.captureName == "capture")
        #expect(notes.first?.captureURL?.resolvingSymlinksInPath() == imageURL.resolvingSymlinksInPath())
        #expect(notes.first?.captureKind == "image")
    }

    @MainActor
    @Test func runtimeConsumesImplicitCaptureContextAfterSavingNote() throws {
        let fixture = try QuicksaveFixture()
        let captureURL = fixture.inboxURL.appendingPathComponent("capture.txt")
        try "saved".write(to: captureURL, atomically: true, encoding: .utf8)

        let runtime = Runtime(
            context: Block.Context(
                storageDirectory: fixture.inboxURL,
                now: fixture.date,
                allowsLiveProcesses: false,
                allowsExternalWrites: false
            )
        )
        runtime.start()
        defer { runtime.stop() }

        runtime.noteText = "first note"
        runtime.saveNote()
        runtime.noteText = "second note"
        runtime.saveNote()

        let notes = try QuicksaveHistory().todayNotes(in: fixture.inboxURL, now: fixture.date)
        let notesByText = Dictionary(uniqueKeysWithValues: notes.map { ($0.text, $0) })

        #expect(notesByText["first note"]?.captureName == "capture")
        #expect(notesByText["second note"]?.captureName == nil)
    }

    @Test func appendsTextCaptureToObsidianDailyNote() throws {
        let fixture = try QuicksaveFixture()
        let captureURL = fixture.inboxURL.appendingPathComponent("capture.txt")
        try "first line\nsecond line".write(to: captureURL, atomically: true, encoding: .utf8)

        let dailyNote = try fixture.obsidian.append(captureURL: captureURL, note: "why this mattered", date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(dailyNote.lastPathComponent == "05-09-2026.md")
        #expect(contents.contains("# 05-09-2026"))
        #expect(contents.contains("> first line\n  > second line"))
        #expect(contents.contains("  - why this mattered"))
    }

    @Test func appendsStandaloneNoteToObsidianDailyNote() throws {
        let fixture = try QuicksaveFixture()

        let dailyNote = try fixture.obsidian.append(note: "standalone block note", date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"

        #expect(contents.contains("- \(formatter.string(from: fixture.date))"))
        #expect(contents.contains("  - standalone block note"))
    }

    @Test func appendsNoteToExistingObsidianCaptureEntry() throws {
        let fixture = try QuicksaveFixture()
        let captureURL = fixture.inboxURL.appendingPathComponent("capture.txt")
        try "saved once".write(to: captureURL, atomically: true, encoding: .utf8)

        _ = try fixture.obsidian.append(captureURL: captureURL, date: fixture.date)
        let dailyNote = try fixture.obsidian.appendNotes(for: [captureURL], note: "capture context", date: fixture.date)
        let contents = try String(contentsOf: dailyNote, encoding: .utf8)

        #expect(contents.contains("> saved once\n  - capture context"))
        #expect(contents.components(separatedBy: "saved once").count == 2)
    }

    @Test func storesObsidianSettings() throws {
        let suiteName = "surface-quicksave-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let root = URL(fileURLWithPath: "/tmp/QuicksaveVault", isDirectory: true)
        let dailyNotes = root.appendingPathComponent("Daily", isDirectory: true)
        let template = root.appendingPathComponent("Templates/Daily Note.md", isDirectory: false)

        QuicksaveSettings.setObsidianVaultURL(root, defaults: defaults)
        QuicksaveSettings.setObsidianDailyNotesURL(dailyNotes, defaults: defaults)
        QuicksaveSettings.setObsidianDailyTemplateURL(template, defaults: defaults)

        #expect(QuicksaveSettings.obsidianVaultURL(defaults: defaults).path == root.path)
        #expect(QuicksaveSettings.obsidianDailyNotesURL(defaults: defaults).path == dailyNotes.path)
        #expect(QuicksaveSettings.obsidianDailyTemplateURL(defaults: defaults).path == template.path)
    }
}

@MainActor
private final class RecordingShortcuts: KeyboardShortcutRegistrar {
    var registered: [KeyboardShortcut] = []
    var unregistered: [KeyboardShortcutToken] = []
    private var nextID: UInt32 = 1

    func registerKeyboardShortcut(
        _ shortcut: KeyboardShortcut,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> KeyboardShortcutToken? {
        registered.append(shortcut)
        defer { nextID += 1 }
        return KeyboardShortcutToken(rawValue: nextID)
    }

    func unregisterKeyboardShortcut(_ token: KeyboardShortcutToken) {
        unregistered.append(token)
    }
}

private struct QuicksaveFixture {
    let rootURL: URL
    let inboxURL: URL
    let dailyNotesURL: URL
    let obsidian: ObsidianDailyNotes
    let date: Date

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("surface-quicksave-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        inboxURL = rootURL.appendingPathComponent("inbox", isDirectory: true)
        dailyNotesURL = rootURL.appendingPathComponent("Zettelkatsen", isDirectory: true)
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 9
        components.hour = 12
        components.minute = 30
        date = try #require(components.date)
        obsidian = ObsidianDailyNotes(
            dailyNotesDirectory: dailyNotesURL,
            vaultDirectory: rootURL,
            resolveDailyNote: ObsidianDailyNotes.fileSystemDailyNoteResolver()
        )
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dailyNotesURL, withIntermediateDirectories: true)
    }
}
