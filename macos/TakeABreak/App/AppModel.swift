import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: TimerState
    @Published private(set) var todayStats: DailyStats
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
    private var freezeReasons: Set<String> = []
    /// True when pause was caused by idle detection (auto-resume on activity).
    private var pausedByIdle = false
    private let overlay = BreakOverlayController()

    init(engine: TimerEngine? = nil) {
        let prefs = PreferencesStore.load()
        let eng = engine ?? TimerEngine(preferences: prefs)
        eng.setPreferences(prefs)
        self.engine = eng
        self.preferences = prefs
        self.state = eng.getState()
        self.todayStats = DailyStatsStore.loadToday()
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
        pausedByIdle = false
        engine.start()
        publish()
    }

    func pause() {
        pausedByIdle = false
        engine.pause()
        publish()
    }

    func resume() {
        pausedByIdle = false
        engine.resume()
        publish()
    }

    func stop() {
        pausedByIdle = false
        engine.stop()
        overlay.hide()
        publish()
    }

    func skipBreak() {
        let wasBreaking = state.phase == .breaking
        engine.skipBreak()
        overlay.hide()
        if wasBreaking {
            if preferences.soundEnabled {
                BreakSounds.playBreakEnd()
            }
            todayStats = DailyStatsStore.update { $0.skipCount += 1 }
        }
        pausedByIdle = false
        publish()
    }

    func openPreferences() {
        PreferencesOpener.open()
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

    // MARK: - Tick

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
        todayStats = DailyStatsStore.loadToday()

        // Screen lock / sleep: do not advance the clock.
        guard freezeReasons.isEmpty else { return }

        handleIdleDetection()

        let previous = state.phase
        let remBefore = state.remainingMs
        engine.tick()
        let next = engine.getState()

        // Accumulate focus time for work segments that ticked.
        if previous == .working, freezeReasons.isEmpty {
            if next.phase == .working {
                let spent = max(0, remBefore - next.remainingMs)
                if spent > 0 {
                    todayStats = DailyStatsStore.update { $0.focusMilliseconds += spent }
                }
            } else if next.phase == .breaking {
                // Remaining work time was consumed.
                if remBefore > 0 {
                    todayStats = DailyStatsStore.update {
                        $0.focusMilliseconds += remBefore
                        $0.completedRounds += 1
                    }
                }
            }
        }

        publish()

        if previous != .breaking && next.phase == .breaking {
            enterBreakUI()
        } else if previous == .breaking && next.phase != .breaking {
            // Natural end → idle. Skip goes to working and is handled in skipBreak().
            leaveBreakUI(playEndSound: true)
            maybeLockScreenAfterBreakEndedIdle()
        } else if next.phase == .breaking {
            overlay.update(
                message: displayMessage,
                remainingMs: next.remainingMs,
                progress: next.progress
            )
        }
    }

    /// Security: if break ended by itself and nobody has been at the Mac, lock the session.
    private func maybeLockScreenAfterBreakEndedIdle() {
        guard preferences.lockScreenWhenBreakEndsIdle else { return }
        let threshold = TimeInterval(preferences.lockScreenIdleSeconds)
        let idleSeconds = IdleMonitor.secondsSinceLastInput()
        guard idleSeconds >= threshold else { return }

        // Defer slightly so break-end sound / UI teardown can finish first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            ScreenLock.lockNow()
        }
    }

    private func handleIdleDetection() {
        guard preferences.idleDetectionEnabled else {
            // If user turns idle detection off while idle-paused, leave them paused.
            return
        }
        let threshold = TimeInterval(preferences.idleThresholdMinutes * 60)
        let idle = IdleMonitor.isIdle(thresholdSeconds: threshold)
        let phase = engine.getState().phase

        if idle {
            switch preferences.idleAction {
            case .pause:
                if phase == .working {
                    engine.pause()
                    pausedByIdle = true
                    publish()
                }
            case .reset:
                if phase == .working || phase == .paused {
                    engine.stop()
                    pausedByIdle = false
                    publish()
                }
            }
        } else if pausedByIdle, phase == .paused {
            engine.resume()
            pausedByIdle = false
            publish()
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
        if preferences.soundEnabled {
            BreakSounds.playBreakStart()
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

    private func leaveBreakUI(playEndSound: Bool) {
        overlay.hide()
        if playEndSound, preferences.soundEnabled {
            BreakSounds.playBreakEnd()
        }
    }

    private func publish() {
        state = engine.getState()
    }

    // MARK: - System freeze

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
