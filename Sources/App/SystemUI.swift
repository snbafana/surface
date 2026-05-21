import AppKit
import Carbon
import Core

final class SurfacePanel: NSPanel {
    init() {
        let frame = Self.targetFrameForDisplay()
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        prepareForDisplay()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func prepareForDisplay() {
        let targetFrame = Self.targetFrameForDisplay()
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        setFrame(targetFrame, display: true)
    }

    private static func targetFrameForDisplay() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
    }
}

@MainActor
final class StatusIcon: NSObject, NSMenuDelegate {
    private let surface: Surface
    private var item: NSStatusItem?
    private let menu = NSMenu()

    init(surface: Surface) {
        self.surface = surface
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Surface")
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "Surface"
        menu.delegate = self
        item.menu = menu
        self.item = item
        rebuildMenu()
    }

    func uninstall() {
        if let item {
            NSStatusBar.system.removeStatusItem(item)
        }
        self.item = nil
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let title = NSMenuItem(title: "Surface", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        for item in [
            actionItem(title: "Show", action: #selector(showSurface)),
            actionItem(title: "Edit Blocks", action: #selector(editSurface)),
            actionItem(title: "Hide", action: #selector(hideSurface))
        ] {
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let blocksTitle = NSMenuItem(title: "Active Blocks", action: nil, keyEquivalent: "")
        blocksTitle.isEnabled = false
        menu.addItem(blocksTitle)

        for block in surface.workspace.enabledBlocks {
            let item = NSMenuItem(title: blockTitle(for: block.id), action: #selector(showSurface), keyEquivalent: "")
            item.target = self
            item.state = .on
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Quit", action: #selector(quit)))
    }

    private func actionItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func blockTitle(for id: BlockID) -> String {
        surface.blocks.block(for: id)?.title ?? id.rawValue
    }

    @objc private func showSurface() {
        surface.show()
    }

    @objc private func editSurface() {
        surface.edit()
    }

    @objc private func hideSurface() {
        surface.hide()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

final class KeyboardShortcuts: KeyboardShortcutRegistrar {
    private struct Registration {
        var shortcut: KeyboardShortcut
        var action: @MainActor @Sendable () -> Void
    }

    private var handlerRef: EventHandlerRef?
    private var nextID: UInt32 = 1
    private var hotKeyRefs: [KeyboardShortcutToken: EventHotKeyRef] = [:]
    private var registrations: [KeyboardShortcutToken: Registration] = [:]

    @MainActor
    @discardableResult
    func registerKeyboardShortcut(
        _ shortcut: KeyboardShortcut,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> KeyboardShortcutToken? {
        guard installHandlerIfNeeded() else {
            return nil
        }

        let token = KeyboardShortcutToken(rawValue: nextID)
        nextID += 1
        guard let hotKeyRef = registerSystemHotKey(shortcut, token: token) else {
            return nil
        }

        hotKeyRefs[token] = hotKeyRef
        registrations[token] = Registration(shortcut: shortcut, action: action)
        return token
    }

    @MainActor
    func unregisterKeyboardShortcut(_ token: KeyboardShortcutToken) {
        if let hotKeyRef = hotKeyRefs.removeValue(forKey: token) {
            UnregisterEventHotKey(hotKeyRef)
        }
        registrations[token] = nil
    }

    @MainActor
    func unregisterAll() {
        unregisterSystemHotKeys()
        registrations.removeAll()
    }

    @MainActor
    func reconnectRegisteredShortcuts() {
        unregisterSystemHotKeys()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }

        guard installHandlerIfNeeded() else {
            return
        }

        for (token, registration) in registrations {
            if let hotKeyRef = registerSystemHotKey(registration.shortcut, token: token) {
                hotKeyRefs[token] = hotKeyRef
            }
        }
    }

    @MainActor
    func invalidate() {
        unregisterAll()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    @MainActor
    private func unregisterSystemHotKeys() {
        for hotKeyRef in hotKeyRefs.values {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
    }

    @MainActor
    private func registerSystemHotKey(
        _ shortcut: KeyboardShortcut,
        token: KeyboardShortcutToken
    ) -> EventHotKeyRef? {
        let hotKeyID = EventHotKeyID(signature: OSType("SURF".fourCharCode), id: token.rawValue)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            return nil
        }
        return hotKeyRef
    }

    @MainActor
    private func installHandlerIfNeeded() -> Bool {
        guard handlerRef == nil else {
            return true
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard hotKeyID.signature == OSType("SURF".fourCharCode) else {
                    return noErr
                }

                let pointerAddress = UInt(bitPattern: userData)
                Task { @MainActor in
                    guard let pointer = UnsafeRawPointer(bitPattern: pointerAddress) else {
                        return
                    }
                    let shortcuts = Unmanaged<KeyboardShortcuts>.fromOpaque(pointer).takeUnretainedValue()
                    shortcuts.performShortcut(KeyboardShortcutToken(rawValue: hotKeyID.id))
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &handlerRef
        )
        return status == noErr
    }

    @MainActor
    private func performShortcut(_ token: KeyboardShortcutToken) {
        registrations[token]?.action()
    }
}

private extension String {
    var fourCharCode: FourCharCode {
        utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }
}
