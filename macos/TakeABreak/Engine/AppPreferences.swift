import Foundation

struct TodoItem: Identifiable, Equatable, Sendable, Codable, Hashable {
    var id: UUID
    var text: String
    /// When true, shown on the break / lock screen.
    var isEnabled: Bool

    init(id: UUID = UUID(), text: String, isEnabled: Bool = true) {
        self.id = id
        self.text = text
        self.isEnabled = isEnabled
    }
}

/// How hard it is to skip a break.
enum SkipDifficulty: String, Codable, CaseIterable, Identifiable, Sendable {
    case easy
    case normal
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "轻松"
        case .normal: return "标准"
        case .hard: return "严格"
        }
    }

    var subtitle: String {
        switch self {
        case .easy: return "按钮固定，长按即可跳过"
        case .normal: return "缓慢移动，鼠标靠近稍后再躲开"
        case .hard: return "跳动更快，躲开更积极"
        }
    }
}

struct AppPreferences: Equatable, Sendable, Codable {
    var workMinutes: Int
    var breakMinutes: Int
    var customMessage: String
    var allowLongPressSkip: Bool
    /// Absolute path to the folder that holds break wallpapers (random pick each break).
    var wallpaperFolderPath: String?
    /// Optional security-scoped bookmark for the folder (best-effort; path is primary for non-sandbox).
    var wallpaperFolderBookmark: Data?
    /// User-defined reminders shown on the break lock screen when enabled.
    var todos: [TodoItem]
    /// Post a system notification when a break starts.
    var notifyOnBreakStart: Bool
    /// Skip button chase difficulty (only when allowLongPressSkip is true).
    var skipDifficulty: SkipDifficulty

    static let `default` = AppPreferences(
        workMinutes: 25,
        breakMinutes: 5,
        customMessage: "站起来走走，看看远处",
        allowLongPressSkip: true,
        wallpaperFolderPath: nil,
        wallpaperFolderBookmark: nil,
        todos: [],
        notifyOnBreakStart: true,
        skipDifficulty: .normal
    )

    static let workMinutesUIRange = 5...90
    static let breakMinutesRange = 1...30
    static let maxTodos = 20

    mutating func clampForStorage() {
        workMinutes = min(max(workMinutes, Self.workMinutesUIRange.lowerBound), Self.workMinutesUIRange.upperBound)
        breakMinutes = min(max(breakMinutes, Self.breakMinutesRange.lowerBound), Self.breakMinutesRange.upperBound)
        todos = todos
            .map { item in
                var copy = item
                copy.text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return copy
            }
            .filter { !$0.text.isEmpty }
        if todos.count > Self.maxTodos {
            todos = Array(todos.prefix(Self.maxTodos))
        }
    }

    var displayMessage: String {
        let trimmed = customMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "该休息一下了" : trimmed
    }

    var activeTodoTexts: [String] {
        todos
            .filter(\.isEnabled)
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var wallpaperFolderDisplayName: String {
        guard let path = wallpaperFolderPath, !path.isEmpty else {
            return "未选择"
        }
        return (path as NSString).lastPathComponent
    }

    enum CodingKeys: String, CodingKey {
        case workMinutes, breakMinutes, customMessage, allowLongPressSkip
        case wallpaperFolderPath, wallpaperFolderBookmark, todos
        case notifyOnBreakStart, skipDifficulty
    }

    init(
        workMinutes: Int,
        breakMinutes: Int,
        customMessage: String,
        allowLongPressSkip: Bool,
        wallpaperFolderPath: String?,
        wallpaperFolderBookmark: Data?,
        todos: [TodoItem],
        notifyOnBreakStart: Bool,
        skipDifficulty: SkipDifficulty
    ) {
        self.workMinutes = workMinutes
        self.breakMinutes = breakMinutes
        self.customMessage = customMessage
        self.allowLongPressSkip = allowLongPressSkip
        self.wallpaperFolderPath = wallpaperFolderPath
        self.wallpaperFolderBookmark = wallpaperFolderBookmark
        self.todos = todos
        self.notifyOnBreakStart = notifyOnBreakStart
        self.skipDifficulty = skipDifficulty
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        workMinutes = try c.decodeIfPresent(Int.self, forKey: .workMinutes) ?? 25
        breakMinutes = try c.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? 5
        customMessage = try c.decodeIfPresent(String.self, forKey: .customMessage) ?? Self.default.customMessage
        allowLongPressSkip = try c.decodeIfPresent(Bool.self, forKey: .allowLongPressSkip) ?? true
        wallpaperFolderPath = try c.decodeIfPresent(String.self, forKey: .wallpaperFolderPath)
        wallpaperFolderBookmark = try c.decodeIfPresent(Data.self, forKey: .wallpaperFolderBookmark)
        todos = try c.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
        notifyOnBreakStart = try c.decodeIfPresent(Bool.self, forKey: .notifyOnBreakStart) ?? true
        skipDifficulty = try c.decodeIfPresent(SkipDifficulty.self, forKey: .skipDifficulty) ?? .normal
    }
}
