import AppKit
import Carbon
import Core
import ServiceManagement
import SwiftUI

struct MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let surface = Surface()
    private var panel: SurfacePanel?
    private var statusIcon: StatusIcon?
    private var toggleShortcut: KeyboardShortcutToken?
    private var localKeyMonitor: Any?
    private var lifecycleObservers: [(NotificationCenter, NSObjectProtocol)] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerLaunchAtLoginIfNeeded()

        let panel = SurfacePanel()
        panel.contentView = NSHostingView(
            rootView: SurfaceView()
                .environmentObject(surface)
                .background(.clear)
        )
        self.panel = panel
        surface.attach(panel: panel)

        let statusIcon = StatusIcon(surface: surface)
        statusIcon.install()
        self.statusIcon = statusIcon

        toggleShortcut = surface.keyboardShortcuts.registerKeyboardShortcut(
            KeyboardShortcut(keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(optionKey))
        ) { [weak surface] in
            surface?.toggleFromShortcut()
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak surface] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let characters = event.charactersIgnoringModifiers?.lowercased()
            if flags.contains(.option), characters == "e" {
                MainActor.assumeIsolated {
                    surface?.toggleFromShortcut()
                }
                return nil
            }

            guard event.keyCode == UInt16(kVK_Escape) else {
                return event
            }
            MainActor.assumeIsolated {
                surface?.hide()
            }
            return nil
        }

        surface.hide()
        installLifecycleObservers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        if let toggleShortcut {
            surface.keyboardShortcuts.unregisterKeyboardShortcut(toggleShortcut)
        }
        surface.keyboardShortcuts.invalidate()
        removeLifecycleObservers()
        statusIcon?.uninstall()
    }

    private func installLifecycleObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification
        ] {
            let observer = workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.recoverSystemIntegration()
                }
            }
            lifecycleObservers.append((workspaceCenter, observer))
        }

        let screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recoverSystemIntegration()
            }
        }
        lifecycleObservers.append((NotificationCenter.default, screenObserver))
    }

    private func removeLifecycleObservers() {
        for (center, observer) in lifecycleObservers {
            center.removeObserver(observer)
        }
        lifecycleObservers.removeAll()
    }

    private func recoverSystemIntegration() {
        surface.keyboardShortcuts.reconnectRegisteredShortcuts()
        panel?.prepareForDisplay()
        if surface.isVisible {
            surface.show()
        } else {
            surface.hide()
        }
    }

    private func registerLaunchAtLoginIfNeeded() {
        guard #available(macOS 13.0, *) else {
            return
        }

        let service = SMAppService.mainApp
        guard service.status != .enabled, service.status != .requiresApproval else {
            return
        }

        try? service.register()
    }
}

MainApp.main()
