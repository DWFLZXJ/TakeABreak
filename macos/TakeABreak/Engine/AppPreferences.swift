import Foundation

struct TodoItem: Identifiable, Equatable, Sendable, Codable, Hashable {
    var id: UUID
    var text: String
    var isEnabled: Bool

    init(id: UUID = UUID(), text: String, isEnabled: Bool = true) {
        self.id = id
        self.text = text
        self.isEnabled = isEnabled
    }
}

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

/// What to do when the user is idle during a work session.
enum IdleAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case pause
    case reset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pause: return "暂停"
        case .reset: return "重置"
        }
    }

    var subtitle: String {
        switch self {
        case .pause: return "空闲时暂停，回来后自动继续"
        case .reset: return "空闲过久回到待命，需手动再开始"
        }
    }
}

struct AppPreferences: Equatable, Sendable, Codable {
    var workMinutes: Int
    var breakMinutes: Int
    var customMessage: String
    var allowLongPressSkip: Bool
    var wallpaperFolderPath: String?
    var wallpaperFolderBookmark: Data?
    var todos: [TodoItem]
    var notifyOnBreakStart: Bool
    var skipDifficulty: SkipDifficulty
    /// Play short sounds when a break starts / ends.
    var soundEnabled: Bool
    /// Detect keyboard/mouse idle during work.
    var idleDetectionEnabled: Bool
    /// Idle threshold in minutes (1–30).
    var idleThresholdMinutes: Int
    var idleAction: IdleAction
    /// When a break ends naturally and the user has been idle, lock the Mac.
    var lockScreenWhenBreakEndsIdle: Bool
    /// Seconds without keyboard/mouse before auto-lock after break ends (1–120).
    var lockScreenIdleSeconds: Int

    static let `default` = AppPreferences(
        workMinutes: 25,
        breakMinutes: 5,
        customMessage: "站起来走走，看看远处",
        allowLongPressSkip: true,
        wallpaperFolderPath: nil,
        wallpaperFolderBookmark: nil,
        todos: [],
        notifyOnBreakStart: true,
        skipDifficulty: .normal,
        soundEnabled: true,
        idleDetectionEnabled: true,
        idleThresholdMinutes: 3,
        idleAction: .pause,
        lockScreenWhenBreakEndsIdle: true,
        lockScreenIdleSeconds: 2
    )

    static let workMinutesUIRange = 5...90
    static let breakMinutesRange = 1...30
    static let idleMinutesRange = 1...30
    /// Idle seconds before locking after a natural break end.
    static let lockScreenIdleSecondsRange = 1...120
    static let maxTodos = 20

    mutating func clampForStorage() {
        workMinutes = min(max(workMinutes, Self.workMinutesUIRange.lowerBound), Self.workMinutesUIRange.upperBound)
        breakMinutes = min(max(breakMinutes, Self.breakMinutesRange.lowerBound), Self.breakMinutesRange.upperBound)
        idleThresholdMinutes = min(max(idleThresholdMinutes, Self.idleMinutesRange.lowerBound), Self.idleMinutesRange.upperBound)
        lockScreenIdleSeconds = min(
            max(lockScreenIdleSeconds, Self.lockScreenIdleSecondsRange.lowerBound),
            Self.lockScreenIdleSecondsRange.upperBound
        )
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
        case soundEnabled, idleDetectionEnabled, idleThresholdMinutes, idleAction
        case lockScreenWhenBreakEndsIdle, lockScreenIdleSeconds
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
        skipDifficulty: SkipDifficulty,
        soundEnabled: Bool,
        idleDetectionEnabled: Bool,
        idleThresholdMinutes: Int,
        idleAction: IdleAction,
        lockScreenWhenBreakEndsIdle: Bool,
        lockScreenIdleSeconds: Int
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
        self.soundEnabled = soundEnabled
        self.idleDetectionEnabled = idleDetectionEnabled
        self.idleThresholdMinutes = idleThresholdMinutes
        self.idleAction = idleAction
        self.lockScreenWhenBreakEndsIdle = lockScreenWhenBreakEndsIdle
        self.lockScreenIdleSeconds = lockScreenIdleSeconds
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
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        idleDetectionEnabled = try c.decodeIfPresent(Bool.self, forKey: .idleDetectionEnabled) ?? true
        idleThresholdMinutes = try c.decodeIfPresent(Int.self, forKey: .idleThresholdMinutes) ?? 3
        idleAction = try c.decodeIfPresent(IdleAction.self, forKey: .idleAction) ?? .pause
        lockScreenWhenBreakEndsIdle = try c.decodeIfPresent(Bool.self, forKey: .lockScreenWhenBreakEndsIdle) ?? true
        lockScreenIdleSeconds = try c.decodeIfPresent(Int.self, forKey: .lockScreenIdleSeconds) ?? 2
    }
}
