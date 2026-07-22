import CoreGraphics
import Foundation

enum IdleMonitor {
    /// Seconds since last keyboard/mouse/tablet event for this login session.
    static func secondsSinceLastInput() -> TimeInterval {
        // ~0 raw value means "any event type" across HID sources.
        let any: CGEventType = CGEventType(rawValue: ~UInt32(0))!
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: any)
    }

    static func isIdle(thresholdSeconds: TimeInterval) -> Bool {
        secondsSinceLastInput() >= thresholdSeconds
    }
}
