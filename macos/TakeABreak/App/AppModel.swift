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
            if preferences.notifyOnBreakStart {
                BreakNotifier.requestPermissionIfNeeded()
            }
        }
    }

    private let engine: TimerEngine
    private var tickTimer: Timer?
    private var sleepObservers: [NSObjectProtocol] = []
    private var lockObservers: [NSObjectProtocol] = []
    /// Reasons the clock is frozen (e.g. `sleep`, `lock`). Empty = running.
    private var freezeReasons: Set<String> = []
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
        observeScreenLock()
        if prefs.notifyOnBreakStart {
            BreakNotifier.requestPermissionIfNeeded()
        }
        overlay.onSkip = { [weak self] in
            self?.skipBreak()
        }
        overlay.onRequestStop = { [weak self] in
            self?.stop()
        }
    }

    // MARK: - Menu bar

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
        if #available(macOS 14.0, *) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func quit() {
        engine.stop()
        overlay.hide()
        publish()
        NSApp.terminate(nil)
    }

    // MARK: - Wallpaper folder

    @discardableResult
    func setWallpaperFolder(from url: URL) -> String? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return "请选择一个文件夹"
        }

        let count = WallpaperStore.listImages(in: url).count
        guard count > 0 else {
            return "该文件夹中没有图片（支持 jpg / png / heic 等）"
        }

        var next = preferences
        next.wallpaperFolderPath = url.path
        next.wallpaperFolderBookmark = WallpaperStore.makeBookmark(for: url)
        preferences = next
        return nil
    }

    func clearWallpaperFolder() {
        var next = preferences
        next.wallpaperFolderPath = nil
        next.wallpaperFolderBookmark = nil
        preferences = next
    }

    var wallpaperFolderImageCount: Int {
        WallpaperStore.imageCount(
            path: preferences.wallpaperFolderPath,
            bookmark: preferences.wallpaperFolderBookmark
        )
    }

    func randomBreakWallpaper() -> NSImage? {
        WallpaperStore.randomImage(
            path: preferences.wallpaperFolderPath,
            bookmark: preferences.wallpaperFolderBookmark
        )
    }

    // MARK: - Todos

    func addTodo(text: String = "") {
        var next = preferences
        guard next.todos.count < AppPreferences.maxTodos else { return }
        next.todos.append(TodoItem(text: text.isEmpty ? "新待办" : text, isEnabled: true))
        preferences = next
    }

    func updateTodo(id: UUID, text: String? = nil, isEnabled: Bool? = nil) {
        var next = preferences
        guard let index = next.todos.firstIndex(where: { $0.id == id }) else { return }
        if let text {
            next.todos[index].text = text
        }
        if let isEnabled {
            next.todos[index].isEnabled = isEnabled
        }
        preferences = next
    }

    func removeTodo(id: UUID) {
        var next = preferences
        next.todos.removeAll { $0.id == id }
        preferences = next
    }

    func moveTodos(from source: IndexSet, to destination: Int) {
        var next = preferences
        next.todos.move(fromOffsets: source, toOffset: destination)
        preferences = next
    }

    // MARK: - Tick & system freeze

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
        // Screen lock / sleep: do not advance the clock.
        guard freezeReasons.isEmpty else { return }

        let previous = state.phase
        engine.tick()
        publish()
        let next = state.phase
        if previous != .breaking && next == .breaking {
            enterBreakUI()
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

    private func enterBreakUI() {
        let todos = preferences.activeTodoTexts
        if preferences.notifyOnBreakStart {
            BreakNotifier.notifyBreakStarted(
                message: displayMessage,
                todoCount: todos.count
            )
        }
        overlay.show(
            message: displayMessage,
            quote: QuoteLibrary.random(),
            todos: todos,
            remainingMs: state.remainingMs,
            progress: state.progress,
            allowSkip: preferences.allowLongPressSkip,
            skipDifficulty: preferences.skipDifficulty,
            wallpaperImage: randomBreakWallpaper()
        )
    }

    private func publish() {
        state = engine.getState()
    }

    private func freezeTimer(reason: String) {
        let wasEmpty = freezeReasons.isEmpty
        freezeReasons.insert(reason)
        if wasEmpty {
            engine.noteSleep()
        }
    }

    private func unfreezeTimer(reason: String) {
        freezeReasons.remove(reason)
        if freezeReasons.isEmpty {
            engine.noteWake()
        }
    }

    private func observeSleep() {
        let nc = NSWorkspace.shared.notificationCenter
        let willSleep = nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.freezeTimer(reason: "sleep")
            }
        }
        let didWake = nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.unfreezeTimer(reason: "sleep")
            }
        }
        sleepObservers = [willSleep, didWake]
    }

    /// Pause countdown while the macOS login/lock screen is active.
    private func observeScreenLock() {
        let dnc = DistributedNotificationCenter.default()
        let locked = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.freezeTimer(reason: "lock")
            }
        }
        let unlocked = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.unfreezeTimer(reason: "lock")
            }
        }
        lockObservers = [locked, unlocked]
    }
}
