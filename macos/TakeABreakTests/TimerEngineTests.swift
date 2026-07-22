import XCTest
@testable import TakeABreak

final class TimerEngineTests: XCTestCase {
    func testFormatMmSs() {
        XCTAssertEqual(TimeFormatting.mmss(fromMilliseconds: 0), "00:00")
        XCTAssertEqual(TimeFormatting.mmss(fromMilliseconds: 65_000), "01:05")
        XCTAssertEqual(TimeFormatting.mmss(fromMilliseconds: 25 * 60 * 1000), "25:00")
    }

    func testStartsIdleWithDefaults() {
        let e = TimerEngine(now: { 0 })
        let s = e.getState()
        XCTAssertEqual(s.phase, .idle)
        XCTAssertEqual(s.workMinutes, 25)
        XCTAssertEqual(s.breakMinutes, 5)
        XCTAssertEqual(s.roundIndex, 0)
    }

    func testStartLocksDurations() {
        var t = 1_000
        let e = TimerEngine(now: { t })
        e.setPreferences(makePrefs(work: 25, break: 5))
        e.start()
        let s = e.getState()
        XCTAssertEqual(s.phase, .working)
        XCTAssertEqual(s.roundIndex, 1)
        XCTAssertEqual(s.lockedWorkMinutes, 25)
        XCTAssertEqual(s.remainingMs, 25 * 60 * 1000)
    }

    func testPauseFreezesRemaining() {
        var t = 0
        let e = TimerEngine(now: { t }, minuteMs: 1000)
        e.setPreferences(makePrefs(work: 1, break: 1))
        e.start()
        t = 10
        e.tick()
        e.pause()
        XCTAssertEqual(e.getState().phase, .paused)
        let rem = e.getState().remainingMs
        t = 999_999
        e.tick()
        XCTAssertEqual(e.getState().remainingMs, rem)
        e.resume()
        XCTAssertEqual(e.getState().phase, .working)
    }

    func testWorkToBreakThenIdleAwaitingStart() {
        var t = 0
        let e = TimerEngine(now: { t }, minuteMs: 1000)
        e.setPreferences(makePrefs(work: 1, break: 1))
        e.start()
        t = 1000
        e.tick()
        XCTAssertEqual(e.getState().phase, .breaking)
        XCTAssertEqual(e.getState().remainingMs, 1000)
        t = 2000
        e.tick()
        // Natural break end waits for user — does not auto-start next work.
        XCTAssertEqual(e.getState().phase, .idle)
        XCTAssertEqual(e.getState().roundIndex, 1)
        e.start()
        XCTAssertEqual(e.getState().phase, .working)
        XCTAssertEqual(e.getState().roundIndex, 2)
    }

    func testSkipBreakWhenAllowed() {
        var t = 0
        let e = TimerEngine(now: { t }, minuteMs: 1000)
        e.setPreferences(makePrefs(work: 1, break: 5, skip: true))
        e.start()
        t = 1000
        e.tick()
        e.skipBreak()
        XCTAssertEqual(e.getState().phase, .working)
        XCTAssertEqual(e.getState().roundIndex, 2)
    }

    func testSkipBreakNoOpWhenDisallowed() {
        var t = 0
        let e = TimerEngine(now: { t }, minuteMs: 1000)
        e.setPreferences(makePrefs(work: 1, break: 5, skip: false))
        e.start()
        t = 1000
        e.tick()
        e.skipBreak()
        XCTAssertEqual(e.getState().phase, .breaking)
    }

    func testStopToIdle() {
        var t = 0
        let e = TimerEngine(now: { t }, minuteMs: 1000)
        e.setPreferences(makePrefs(work: 1, break: 1))
        e.start()
        e.stop()
        XCTAssertEqual(e.getState().phase, .idle)
    }

    func testPrefsAffectNextRoundOnly() {
        var t = 0
        let e = TimerEngine(now: { t }, minuteMs: 1000)
        e.setPreferences(makePrefs(work: 1, break: 1))
        e.start()
        e.setPreferences(makePrefs(work: 10, break: 3))
        XCTAssertEqual(e.getState().lockedWorkMinutes, 1)
        XCTAssertEqual(e.getState().workMinutes, 10)
        t = 1000
        e.tick()
        XCTAssertEqual(e.getState().lockedBreakMinutes, 1)
        t = 2000
        e.tick()
        XCTAssertEqual(e.getState().phase, .idle)
        e.start()
        XCTAssertEqual(e.getState().lockedWorkMinutes, 10)
        XCTAssertEqual(e.getState().remainingMs, 10_000)
    }

    func testPauseDoesNotOverrideBreakTransition() {
        var t = 0
        let e = TimerEngine(now: { t }, minuteMs: 1000)
        e.setPreferences(makePrefs(work: 1, break: 1))
        e.start()
        t = 1000
        e.pause()
        XCTAssertEqual(e.getState().phase, .breaking)
    }

    func testEmptyMessageFallback() {
        let e = TimerEngine()
        e.setPreferences(makePrefs(work: 25, break: 5, message: "   "))
        XCTAssertEqual(e.displayMessage, "该休息一下了")
    }

    private func makePrefs(work: Int, break br: Int, skip: Bool = true, message: String = "站起来走走，看看远处") -> AppPreferences {
        AppPreferences(
            workMinutes: work,
            breakMinutes: br,
            customMessage: message,
            allowLongPressSkip: skip,
            wallpaperFolderPath: nil,
            wallpaperFolderBookmark: nil,
            todos: [],
            notifyOnBreakStart: true,
            skipDifficulty: .normal,
            soundEnabled: true,
            idleDetectionEnabled: true,
            idleThresholdMinutes: 3,
            idleAction: .pause,
            lockScreenWhenBreakEndsIdle: true
        )
    }
}
