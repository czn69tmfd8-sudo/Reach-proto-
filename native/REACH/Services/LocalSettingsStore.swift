import Foundation

struct ReachLocalSettings: Codable, Equatable {
    var preferredDisplayName: String = ""
    var hasCompletedWelcome: Bool = false
    var keepScreenAwakeDuringOpenHand: Bool = true
    var showSelfView: Bool = true
}

actor LocalSettingsStore {
    private let defaults: UserDefaults
    private let key = "reach.native.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ReachLocalSettings {
        guard
            let data = defaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(ReachLocalSettings.self, from: data)
        else { return ReachLocalSettings() }
        return settings
    }

    func save(_ settings: ReachLocalSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
