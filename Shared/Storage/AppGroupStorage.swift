import Foundation

enum AppGroupStorage {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupID)
    }

    static func loadConfig() -> WidgetConfig? {
        guard let defaults,
              let data = defaults.data(forKey: AppConstants.configKey) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetConfig.self, from: data)
    }

    static func saveConfig(_ config: WidgetConfig) {
        guard let defaults,
              let data = try? JSONEncoder().encode(config) else {
            return
        }
        defaults.set(data, forKey: AppConstants.configKey)
    }
}
