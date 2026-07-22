import Foundation

struct AppPreferences: Equatable, Sendable, Codable {
    var workMinutes: Int
    var breakMinutes: Int
    var customMessage: String
    var allowLongPressSkip: Bool
    /// Absolute path to the folder that holds break wallpapers (random pick each break).
    var wallpaperFolderPath: String?
    /// Optional security-scoped bookmark for the folder (best-effort; path is primary for non-sandbox).
    var wallpaperFolderBookmark: Data?

    static let `default` = AppPreferences(
        workMinutes: 25,
        breakMinutes: 5,
        customMessage: "站起来走走，看看远处",
        allowLongPressSkip: true,
        wallpaperFolderPath: nil,
        wallpaperFolderBookmark: nil
    )

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

    var wallpaperFolderDisplayName: String {
        guard let path = wallpaperFolderPath, !path.isEmpty else {
            return "未选择"
        }
        return (path as NSString).lastPathComponent
    }
}
