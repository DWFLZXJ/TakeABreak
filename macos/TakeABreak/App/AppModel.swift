import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: TimerState
    @Published var preferences: AppPreferences {
        didSet {
            engine.setPreferences(preferences)
            PreferencesStore.save(preferences)
        }
    }

    private let engine: TimerEngine
    private var tickTimer: Timer?
    private var sleepObservers: [NSObjectProtocol] = []
    private let overlay = BreakOverlayController()

    init(engine: TimerEngine? = nil) {
        let prefs = PreferencesStore.load()
        let eng = engine ?? TimerEngine(preferences: prefs)
        eng.setPreferences(prefs)
        self.engine = eng
        self.preferences = prefs
        self.state = eng.getState()
        startTicking()
        observeSleep()
        overlay.onSkip = { [weak self] in
            self?.skipBreak()
        }
        overlay.onRequestStop = { [weak self] in
            self?.stop()
        }
    }

    // MARK: - Menu bar

    /// Text shown next to the menu bar symbol (empty when idle — icon alone is enough).
    var menuBarTitle: String {
        switch state.phase {
        case .idle:
            return ""
        case .working, .breaking:
            return TimeFormatting.mmss(fromMilliseconds: state.remainingMs)
        case .paused:
            return "‖ " + TimeFormatting.mmss(fromMilliseconds: state.remainingMs)
        }
    }

    var displayMessage: String { engine.displayMessage }

    // MARK: - Actions

    func start() {
        engine.start()
        publish()
    }

    func pause() {
        engine.pause()
        publish()
    }

    func resume() {
        engine.resume()
        publish()
    }

    func stop() {
        engine.stop()
        overlay.hide()
        publish()
    }

    func skipBreak() {
        engine.skipBreak()
        overlay.hide()
        publish()
    }

    func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        // Fallback for older selector naming
        if #available(macOS 14.0, *) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Stop timer, dismiss overlay, then terminate (menu bar apps have no Dock quit by default).
    func quit() {
        engine.stop()
        overlay.hide()
        publish()
        NSApp.terminate(nil)
    }

    // MARK: - Wallpaper prefs

    func selectBuiltinWallpaper(id: String) {
        WallpaperStore.clearCustomFiles()
        var next = preferences
        next.wallpaperId = id
        next.wallpaperBookmark = nil
        preferences = next
    }

    /// Copy the picked image into Application Support and mark wallpaper as custom.
    /// Returns an error message on failure (nil on success).
    @discardableResult
    func applyCustomWallpaper(from url: URL) -> String? {
        do {
            _ = try WallpaperStore.saveCustom(from: url)
            var next = preferences
            next.wallpaperId = "custom"
            // Bookmarks are unreliable without App Sandbox; file copy is the source of truth.
            next.wallpaperBookmark = nil
            preferences = next
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Image used for break overlay / prefs thumbnail when `wallpaperId == custom`.
    func customWallpaperImage() -> NSImage? {
        guard preferences.wallpaperId == "custom" else { return nil }
        return WallpaperStore.loadCustomImage()
    }

    // MARK: - Tick & sleep

    private func startTicking() {
        tickTimer?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.onTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func onTick() {
        let previous = state.phase
        engine.tick()
        publish()
        let next = state.phase
        if previous != .breaking && next == .breaking {
            overlay.show(
                message: displayMessage,
                remainingMs: state.remainingMs,
                progress: state.progress,
                allowSkip: preferences.allowLongPressSkip,
                wallpaperId: preferences.wallpaperId,
                wallpaperImage: customWallpaperImage()
            )
        } else if previous == .breaking && next != .breaking {
            overlay.hide()
        } else if next == .breaking {
            overlay.update(
                message: displayMessage,
                remainingMs: state.remainingMs,
                progress: state.progress
            )
        }
    }

    private func publish() {
        state = engine.getState()
    }

    private func observeSleep() {
        let nc = NSWorkspace.shared.notificationCenter
        let willSleep = nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.engine.noteSleep()
            }
        }
        let didWake = nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.engine.noteWake()
            }
        }
        sleepObservers = [willSleep, didWake]
    }
}
