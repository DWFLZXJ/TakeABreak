import AppKit
import Foundation

/// Opens the SwiftUI `Settings` scene from a menu-bar (LSUIElement / accessory) app.
///
/// Clicking a button alone often fails because:
/// 1) the app is not active, and/or
/// 2) accessory policy hides settings windows behind other apps.
enum PreferencesOpener {
    private static var closeObserver: NSObjectProtocol?
    private static var didForceRegular = false

    @MainActor
    static func open() {
        // Temporarily become a regular app so the settings window can key/order front.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
            didForceRegular = true
        }

        NSApp.activate(ignoringOtherApps: true)

        // Selectors used across macOS versions for Settings / Preferences.
        _ = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)

        // Bring any settings-like window forward after SwiftUI creates it.
        DispatchQueue.main.async {
            orderSettingsWindowsFront()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            orderSettingsWindowsFront()
        }

        installCloseObserverIfNeeded()
    }

    @MainActor
    private static func orderSettingsWindowsFront() {
        for window in NSApp.windows {
            guard isLikelySettingsWindow(window) else { continue }
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.level = .floating
            window.makeKeyAndOrderFront(nil)
            // Drop back to normal after becoming key so it behaves like a normal prefs window.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if window.isVisible {
                    window.level = .normal
                }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func isLikelySettingsWindow(_ window: NSWindow) -> Bool {
        if window.styleMask.contains(.titled) == false { return false }
        // Exclude the menu-bar panel host if any
        let className = String(describing: type(of: window))
        if className.contains("StatusBar") || className.contains("MenuBarExtra") {
            return false
        }
        let title = window.title
        if title.localizedCaseInsensitiveContains("settings")
            || title.localizedCaseInsensitiveContains("preferences")
            || title.localizedCaseInsensitiveContains("偏好")
            || title.localizedCaseInsensitiveContains("设置")
            || title.contains("Take a Break") {
            return true
        }
        let autosave = window.frameAutosaveName
        if autosave.localizedCaseInsensitiveContains("settings")
            || autosave.localizedCaseInsensitiveContains("preferences") {
            return true
        }
        // SwiftUI Settings often uses a standard window with content size ~ preferences panel
        // Heuristic: titled window that is not the main/fullscreen break overlay
        if window.level == .screenSaver { return false }
        // Accept any remaining titled, resizable small utility window after showSettings
        return window.isVisible && window.canBecomeKey && window.frame.width >= 300 && window.frame.width <= 900
    }

    private static func installCloseObserverIfNeeded() {
        guard closeObserver == nil else { return }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { note in
            Task { @MainActor in
                guard didForceRegular else { return }
                // If no titled settings-like windows remain, go back to accessory (menu bar only).
                let stillOpen = NSApp.windows.contains { window in
                    window.isVisible && isLikelySettingsWindow(window) && (note.object as? NSWindow) !== window
                }
                if !stillOpen {
                    // Small delay so the close finishes.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        let anyPrefs = NSApp.windows.contains {
                            $0.isVisible && isLikelySettingsWindow($0)
                        }
                        if !anyPrefs {
                            NSApp.setActivationPolicy(.accessory)
                            didForceRegular = false
                        }
                    }
                }
            }
        }
    }
}
