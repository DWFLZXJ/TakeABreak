import Foundation

struct AppPreferences: Equatable, Sendable, Codable {
    var workMinutes: Int
    var breakMinutes: Int
    /// Built-in id (e.g. `default-1`) or `custom` when using a user-selected image bookmark.
    var wallpaperId: String
    var customMessage: String
    var allowLongPressSkip: Bool
    /// Security-scoped bookmark data for a custom wallpaper file.
    var wallpaperBookmark: Data?

    static let `default` = AppPreferences(
        workMinutes: 25,
        breakMinutes: 5,
        wallpaperId: "default-1",
        customMessage: "站起来走走，看看远处",
        allowLongPressSkip: true,
        wallpaperBookmark: nil
    )

    /// UI range for work minutes (engine allows 1–90 for tests).
    static let workMinutesUIRange = 5...90
    static let breakMinutesRange = 1...30

    mutating func clampForStorage() {
        workMinutes = min(max(workMinutes, Self.workMinutesUIRange.lowerBound), Self.workMinutesUIRange.upperBound)
        breakMinutes = min(max(breakMinutes, Self.breakMinutesRange.lowerBound), Self.breakMinutesRange.upperBound)
    }

    var displayMessage: String {
        let trimmed = customMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "该休息一下了" : trimmed
    }
}
