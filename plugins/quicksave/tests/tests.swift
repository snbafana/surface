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

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("surface-quicksave-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        inboxURL = rootURL.appendingPathComponent("inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
    }
}
