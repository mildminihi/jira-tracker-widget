import Foundation

enum AppGroupStorage {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupID)
    }

    static func loadConfig() -> SprintConfig? {
        guard let defaults,
              let data = defaults.data(forKey: AppConstants.configKey) else {
            return nil
        }
        return try? JSONDecoder().decode(SprintConfig.self, from: data)
    }

    static func saveConfig(_ config: SprintConfig) {
        guard let defaults,
              let data = try? JSONEncoder().encode(config) else {
            return
        }
        defaults.set(data, forKey: AppConstants.configKey)
    }
}
