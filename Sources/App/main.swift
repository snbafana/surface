import AppKit
import Carbon
import Core
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

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
            KeyboardShortcut(keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(cmdKey))
        ) { [weak surface] in
            surface?.toggle()
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak surface] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let characters = event.charactersIgnoringModifiers?.lowercased()
            if flags.contains(.command), characters == "e" {
                MainActor.assumeIsolated {
                    surface?.toggle()
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        if let toggleShortcut {
            surface.keyboardShortcuts.unregisterKeyboardShortcut(toggleShortcut)
        }
        surface.keyboardShortcuts.invalidate()
        statusIcon?.uninstall()
    }
}

MainApp.main()
