import Foundation

enum PreferencesStore {
    /// Current prefs key. Also tries previous keys for migration.
    private static let key = "takeabreak.prefs.v3"
    private static let legacyKeys = ["takeabreak.prefs.v2", "takeabreak.prefs.v1"]

    static func load() -> AppPreferences {
        let defaults = UserDefaults.standard
        for candidate in [key] + legacyKeys {
            guard let data = defaults.data(forKey: candidate) else { continue }
            if var prefs = try? JSONDecoder().decode(AppPreferences.self, from: data) {
                prefs.clampForStorage()
                // Migrate forward
                if candidate != key {
                    save(prefs)
                    defaults.removeObject(forKey: candidate)
                }
                return prefs
            }
        }
        return .default
    }

    static func save(_ prefs: AppPreferences) {
        var copy = prefs
        copy.clampForStorage()
        if let data = try? JSONEncoder().encode(copy) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
