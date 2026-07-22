import AppKit
import Foundation

enum ScreenLock {
    /// Lock the Mac login session (same idea as Control–Command–Q).
    static func lockNow() {
        if lockViaPrivateLoginFramework() {
            return
        }
        lockViaSystemEvents()
    }

    /// Preferred: private but widely used `SACLockScreenImmediate`.
    private static func lockViaPrivateLoginFramework() -> Bool {
        let path = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        guard let handle = dlopen(path, RTLD_LAZY) else { return false }
        defer { dlclose(handle) }
        guard let sym = dlsym(handle, "SACLockScreenImmediate") else { return false }
        typealias LockFn = @convention(c) () -> Void
        let lock = unsafeBitCast(sym, to: LockFn.self)
        lock()
        return true
    }

    /// Fallback: simulate ⌃⌘Q (may require Accessibility permission for System Events).
    private static func lockViaSystemEvents() {
        let script = """
        tell application "System Events"
            keystroke "q" using {control down, command down}
        end tell
        """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            // Last resort: put display to sleep (not a full session lock).
            let sleepTask = Process()
            sleepTask.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            sleepTask.arguments = ["displaysleepnow"]
            try? sleepTask.run()
        }
    }
}
