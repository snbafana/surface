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

        let noteURL = try ContextNoteWriter().save(note: "today note", for: [captureURL], in: fixture.inboxURL)
        let oldNoteURL = try ContextNoteWriter().save(note: "old note", for: [], in: fixture.inboxURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-172_800)],
            ofItemAtPath: oldNoteURL.path
        )

        let notes = try QuicksaveHistory().todayNotes(in: fixture.inboxURL)

        #expect(noteURL.lastPathComponent == "capture.note.txt")
        #expect(notes.map(\.text) == ["today note"])
        #expect(notes.first?.captureName == "capture")
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
