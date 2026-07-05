import AppKit
import Carbon
import Core
import os
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
    private let logger = Logger(subsystem: "com.snbafana.Surface", category: "AppDelegate")
    private var panel: SurfacePanel?
    private var statusIcon: StatusIcon?
    private var toggleShortcut: KeyboardShortcutToken?
    private var lifecycleObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private var recoveryTask: Task<Void, Never>?
    private var shortcutWatchdog: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateDuplicateSurfaceProcesses()
        NSApp.setActivationPolicy(.accessory)

        let panel = SurfacePanel()
        panel.onEscape = { [weak surface] in
            surface?.hide()
        }
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
            surface?.toggle()
        }
        if toggleShortcut == nil {
            logger.error("Option-E shortcut registration failed")
        }

        surface.hide()
        installLifecycleObservers()
        installShortcutWatchdog()
    }

    func applicationWillTerminate(_ notification: Notification) {
        recoveryTask?.cancel()
        shortcutWatchdog?.invalidate()
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
                    self?.scheduleSystemRecovery(reason: name.rawValue)
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
                self?.scheduleSystemRecovery(reason: NSApplication.didChangeScreenParametersNotification.rawValue)
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

    private func terminateDuplicateSurfaceProcesses() {
        let currentProcessID = ProcessInfo.processInfo.processIdentifier
        for application in NSWorkspace.shared.runningApplications {
            guard application.processIdentifier != currentProcessID else {
                continue
            }
            guard isDuplicateSurfaceApplication(application) else {
                continue
            }

            if application.terminate() {
                logger.info("Terminated duplicate Surface process pid=\(application.processIdentifier, privacy: .public) path=\(application.executableURL?.path ?? "unknown", privacy: .public)")
            } else if application.forceTerminate() {
                logger.info("Force terminated duplicate Surface process pid=\(application.processIdentifier, privacy: .public) path=\(application.executableURL?.path ?? "unknown", privacy: .public)")
            } else {
                logger.error("Could not terminate duplicate Surface process pid=\(application.processIdentifier, privacy: .public) path=\(application.executableURL?.path ?? "unknown", privacy: .public)")
            }
        }
    }

    private func isDuplicateSurfaceApplication(_ application: NSRunningApplication) -> Bool {
        if let bundleIdentifier = application.bundleIdentifier,
           ["com.snbafana.Surface", "local.surface.app"].contains(bundleIdentifier) {
            return true
        }
        if application.bundleURL?.lastPathComponent == "Surface.app" {
            return true
        }
        if application.executableURL?.path.contains("/Surface.app/Contents/MacOS/") == true {
            return true
        }
        return application.executableURL?.lastPathComponent == "Surface"
    }

    private func installShortcutWatchdog() {
        let timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recoverKeyboardShortcuts(reason: "shortcut-watchdog")
            }
        }
        timer.tolerance = 30
        shortcutWatchdog = timer
    }

    private func scheduleSystemRecovery(reason: String) {
        recoverSystemIntegration(reason: reason)
        recoveryTask?.cancel()
        recoveryTask = Task { @MainActor [weak self] in
            for delay in [1_000_000_000, 5_000_000_000] as [UInt64] {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else {
                    return
                }
                self?.recoverSystemIntegration(reason: "\(reason)-retry")
            }
        }
    }

    private func recoverSystemIntegration(reason: String) {
        recoverKeyboardShortcuts(reason: reason)
        panel?.prepareForDisplay()
        surface.reapplyVisibility()
    }

    private func recoverKeyboardShortcuts(reason: String) {
        let didRecover = surface.keyboardShortcuts.reconnectRegisteredShortcuts()
        let active = surface.keyboardShortcuts.activeSystemHotKeyCount
        let expected = surface.keyboardShortcuts.registrationCount
        if didRecover {
            logger.info("Shortcut recovery succeeded reason=\(reason, privacy: .public) active=\(active, privacy: .public) expected=\(expected, privacy: .public)")
        } else {
            let failure = surface.keyboardShortcuts.lastFailureDescription ?? "unknown"
            logger.error("Shortcut recovery failed reason=\(reason, privacy: .public) active=\(active, privacy: .public) expected=\(expected, privacy: .public) failure=\(failure, privacy: .public)")
        }
    }
}

MainApp.main()
