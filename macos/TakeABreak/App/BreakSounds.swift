import AppKit
import Foundation

enum BreakSounds {
    /// Entering a break.
    static func playBreakStart() {
        playSystem("Glass")
    }

    /// Break finished (natural end) or skipped back to work / idle.
    static func playBreakEnd() {
        playSystem("Purr")
    }

    private static func playSystem(_ name: String) {
        // Built-in macOS alert sounds under /System/Library/Sounds
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.play()
            return
        }
        // Fallback path if named lookup fails
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
        NSSound(contentsOf: url, byReference: true)?.play()
    }
}
