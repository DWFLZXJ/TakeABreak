import Foundation

enum PreferencesStore {
    private static let key = "takeabreak.prefs.v1"

    static func load() -> AppPreferences {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return .default
        }
        do {
            var prefs = try JSONDecoder().decode(AppPreferences.self, from: data)
            prefs.clampForStorage()
            return prefs
        } catch {
            return .default
        }
    }

    static func save(_ prefs: AppPreferences) {
        var copy = prefs
        copy.clampForStorage()
        if let data = try? JSONEncoder().encode(copy) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
