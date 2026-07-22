import Foundation

enum TimerPhase: String, Equatable, Sendable {
    case idle
    case working
    case paused
    case breaking
}
