import Foundation

/// Snapshot of the pomodoro engine.
struct TimerState: Equatable, Sendable {
    var phase: TimerPhase
    var roundIndex: Int
    var remainingMs: Int
    var lockedWorkMinutes: Int
    var lockedBreakMinutes: Int
    var workMinutes: Int
    var breakMinutes: Int
    var customMessage: String
    var allowLongPressSkip: Bool
    /// 0...1 elapsed ratio for the current working/breaking segment.
    var progress: Double
}

/// Pure pomodoro state machine.
/// After a break ends naturally, returns to Idle and waits for `start()` (does not auto-continue).
final class TimerEngine: @unchecked Sendable {
    private let now: () -> Int
    private let minuteMs: Int

    private var prefs: AppPreferences
    private var phase: TimerPhase = .idle
    private var roundIndex: Int = 0
    private var lockedWorkMinutes: Int = AppPreferences.default.workMinutes
    private var lockedBreakMinutes: Int = AppPreferences.default.breakMinutes
    private var remainingMs: Int = 0
    private var lastTickAt: Int?

    init(
        now: @escaping () -> Int = { Int(Date().timeIntervalSince1970 * 1000) },
        minuteMs: Int = 60_000,
        preferences: AppPreferences = .default
    ) {
        self.now = now
        self.minuteMs = minuteMs
        self.prefs = preferences
        self.lockedWorkMinutes = preferences.workMinutes
        self.lockedBreakMinutes = preferences.breakMinutes
    }

    func getState() -> TimerState {
        TimerState(
            phase: phase,
            roundIndex: roundIndex,
            remainingMs: remainingMs,
            lockedWorkMinutes: lockedWorkMinutes,
            lockedBreakMinutes: lockedBreakMinutes,
            workMinutes: prefs.workMinutes,
            breakMinutes: prefs.breakMinutes,
            customMessage: prefs.customMessage,
            allowLongPressSkip: prefs.allowLongPressSkip,
            progress: progressRatio()
        )
    }

    var displayMessage: String { prefs.displayMessage }

    var preferences: AppPreferences { prefs }

    func setPreferences(_ partial: AppPreferences) {
        var next = partial
        next.workMinutes = min(max(next.workMinutes, 1), 90)
        next.breakMinutes = min(max(next.breakMinutes, 1), 30)
        prefs = next
    }

    func updatePreferences(_ mutate: (inout AppPreferences) -> Void) {
        var copy = prefs
        mutate(&copy)
        setPreferences(copy)
    }

    /// Start or continue: next round index is `roundIndex + 1` (first start → 1).
    func start() {
        guard phase == .idle else { return }
        enterWorking(nextRound: roundIndex + 1)
    }

    func pause() {
        guard phase == .working else { return }
        tick()
        if phase == .working {
            phase = .paused
        }
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .working
        lastTickAt = now()
    }

    func stop() {
        phase = .idle
        remainingMs = 0
        roundIndex = 0
        lastTickAt = nil
    }

    /// Skip break and immediately start the next work round.
    func skipBreak() {
        guard phase == .breaking else { return }
        guard prefs.allowLongPressSkip else { return }
        enterWorking(nextRound: roundIndex + 1)
    }

    func tick() {
        guard phase == .working || phase == .breaking else { return }
        let t = now()
        if lastTickAt == nil {
            lastTickAt = t
            return
        }
        let delta = max(0, t - lastTickAt!)
        lastTickAt = t
        remainingMs = max(0, remainingMs - delta)
        guard remainingMs == 0 else { return }
        if phase == .working {
            enterBreaking()
        } else if phase == .breaking {
            // Wait for user to start the next focus session.
            finishBreakAwaitingStart()
        }
    }

    func noteSleep() {
        lastTickAt = nil
    }

    func noteWake() {
        lastTickAt = now()
    }

    // MARK: - Private

    private func enterWorking(nextRound: Int) {
        phase = .working
        roundIndex = nextRound
        lockedWorkMinutes = prefs.workMinutes
        lockedBreakMinutes = prefs.breakMinutes
        remainingMs = lockedWorkMinutes * minuteMs
        lastTickAt = now()
    }

    private func enterBreaking() {
        phase = .breaking
        remainingMs = lockedBreakMinutes * minuteMs
        lastTickAt = now()
    }

    /// Natural break end → Idle, keep roundIndex so UI can say "completed N rounds".
    private func finishBreakAwaitingStart() {
        phase = .idle
        remainingMs = 0
        lastTickAt = nil
    }

    private func progressRatio() -> Double {
        switch phase {
        case .working, .paused:
            let total = Double(lockedWorkMinutes * minuteMs)
            guard total > 0 else { return 0 }
            return 1 - Double(remainingMs) / total
        case .breaking:
            let total = Double(lockedBreakMinutes * minuteMs)
            guard total > 0 else { return 0 }
            return 1 - Double(remainingMs) / total
        case .idle:
            return 0
        }
    }
}

enum TimeFormatting {
    static func mmss(fromMilliseconds ms: Int) -> String {
        let totalSec = max(0, Int(ceil(Double(ms) / 1000.0)))
        let m = totalSec / 60
        let s = totalSec % 60
        return String(format: "%02d:%02d", m, s)
    }
}
