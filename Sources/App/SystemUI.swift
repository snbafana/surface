import AppKit
import Carbon
import Core
import os

final class SurfacePanel: NSPanel {
    var onEscape: (() -> Void)?
    private let logger = Logger(subsystem: "com.snbafana.Surface", category: "SurfacePanel")

    init() {
        let frame = Self.targetFrameForDisplay()
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        worksWhenModal = true
        prepareForDisplay()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }

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
        collectionBehavior = [
            .canJoinAllApplications,
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .transient
        ]
        setFrame(targetFrame, display: true)
    }

    func showForDisplay() {
        prepareForDisplay()
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        makeKey()
        logState("Panel shown")
    }

    func reassertVisibleAfterActivation() {
        DispatchQueue.main.async { [weak self] in
            self?.reassertVisible(reason: "next-turn")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            self?.reassertVisible(reason: "delayed")
        }
    }

    func hideFromDisplay() {
        orderOut(nil)
        logger.info("Panel hidden visible=\(self.isVisible, privacy: .public)")
    }

    private static func targetFrameForDisplay() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
    }

    private func reassertVisible(reason: String) {
        guard isVisible else {
            return
        }
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        makeKey()
        logState("Panel reasserted \(reason)")
    }

    private func logState(_ message: String) {
        logger.info(
            "\(message, privacy: .public) visible=\(self.isVisible, privacy: .public) key=\(self.isKeyWindow, privacy: .public) screen=\(self.screen?.localizedName ?? "none", privacy: .public) frame=\(NSStringFromRect(self.frame), privacy: .public) behavior=\(self.collectionBehavior.rawValue, privacy: .public)"
        )
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
        let shortcutTitle = surface.keyboardShortcuts.lastFailureDescription.map {
            "Shortcut issue: \($0)"
        } ?? "Shortcut: Option-E"
        let shortcutItem = NSMenuItem(title: shortcutTitle, action: nil, keyEquivalent: "")
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)

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

    private let logger = Logger(subsystem: "com.snbafana.Surface", category: "KeyboardShortcuts")
    private var handlerRef: EventHandlerRef?
    private var nextID: UInt32 = 1
    private var hotKeyRefs: [KeyboardShortcutToken: EventHotKeyRef] = [:]
    private var registrations: [KeyboardShortcutToken: Registration] = [:]
    private var lastFireTimes: [KeyboardShortcutToken: TimeInterval] = [:]
    private(set) var lastFailureDescription: String?
    private let minimumShortcutInterval: TimeInterval = 0.25

    var activeSystemHotKeyCount: Int {
        hotKeyRefs.count
    }

    var registrationCount: Int {
        registrations.count
    }

    @MainActor
    @discardableResult
    func registerKeyboardShortcut(
        _ shortcut: KeyboardShortcut,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> KeyboardShortcutToken? {
        let token = KeyboardShortcutToken(rawValue: nextID)
        nextID += 1

        guard installHandlerIfNeeded() else {
            recordFailure("could not install shortcut handler", shortcut: shortcut, status: nil)
            return nil
        }

        guard let hotKeyRef = registerSystemHotKey(shortcut, token: token) else {
            return nil
        }

        hotKeyRefs[token] = hotKeyRef
        registrations[token] = Registration(shortcut: shortcut, action: action)
        lastFailureDescription = nil
        return token
    }

    @MainActor
    func unregisterKeyboardShortcut(_ token: KeyboardShortcutToken) {
        if let hotKeyRef = hotKeyRefs.removeValue(forKey: token) {
            UnregisterEventHotKey(hotKeyRef)
        }
        registrations[token] = nil
        lastFireTimes[token] = nil
    }

    @MainActor
    func unregisterAll() {
        unregisterSystemHotKeys()
        registrations.removeAll()
        lastFireTimes.removeAll()
    }

    @MainActor
    @discardableResult
    func reconnectRegisteredShortcuts() -> Bool {
        let registrations = registrations
        unregisterSystemHotKeys()

        guard !registrations.isEmpty else {
            lastFailureDescription = nil
            return true
        }

        guard installHandlerIfNeeded() else {
            if let registration = registrations.values.first {
                recordFailure("could not install shortcut handler during reconnect", shortcut: registration.shortcut, status: nil)
            }
            return false
        }

        var didFail = false
        for (token, registration) in registrations {
            if let hotKeyRef = registerSystemHotKey(registration.shortcut, token: token) {
                hotKeyRefs[token] = hotKeyRef
            } else {
                didFail = true
            }
        }
        if !didFail {
            lastFailureDescription = nil
        }
        return !didFail
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
            recordFailure("registration failed", shortcut: shortcut, status: status)
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
        guard let registration = registrations[token] else {
            logger.error("Shortcut fired with no registration token=\(token.rawValue, privacy: .public)")
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        if let lastFireTime = lastFireTimes[token], now - lastFireTime < minimumShortcutInterval {
            logger.info("Shortcut repeat ignored token=\(token.rawValue, privacy: .public) shortcut=\(registration.shortcut.displayName, privacy: .public)")
            return
        }
        lastFireTimes[token] = now
        logger.info("Shortcut fired token=\(token.rawValue, privacy: .public) shortcut=\(registration.shortcut.displayName, privacy: .public)")
        registration.action()
    }

    @MainActor
    private func recordFailure(_ message: String, shortcut: KeyboardShortcut, status: OSStatus?) {
        let statusText = status.map { " OSStatus \($0)" } ?? ""
        lastFailureDescription = "\(shortcut.displayName) \(message)\(statusText)"
        if let status {
            logger.error(
                "\(message, privacy: .public): keyCode=\(shortcut.keyCode, privacy: .public) modifiers=\(shortcut.modifiers, privacy: .public) status=\(status, privacy: .public)"
            )
        } else {
            logger.error(
                "\(message, privacy: .public): keyCode=\(shortcut.keyCode, privacy: .public) modifiers=\(shortcut.modifiers, privacy: .public)"
            )
        }
    }
}

private extension KeyboardShortcut {
    var displayName: String {
        switch (keyCode, modifiers) {
        case (UInt32(kVK_ANSI_E), UInt32(optionKey)):
            return "Option-E"
        case (UInt32(kVK_ANSI_C), UInt32(optionKey)):
            return "Option-C"
        default:
            return "keyCode \(keyCode) modifiers \(modifiers)"
        }
    }
}

private extension String {
    var fourCharCode: FourCharCode {
        utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }
}
