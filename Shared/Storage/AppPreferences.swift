import Foundation

enum BoardScope: String, Codable, CaseIterable, Identifiable {
    case selected
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selected: return "This board"
        case .all: return "All"
        }
    }
}

enum StatusFilter: String, Codable, CaseIterable, Identifiable {
    case all
    case active
    case inProgress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .inProgress: return "In Progress"
        }
    }
}

struct AppPreferences: Codable, Equatable {
    var boardScope: BoardScope
    var selectedPairID: UUID?
    var statusFilter: StatusFilter
    var isCompact: Bool

    static let `default` = AppPreferences(
        boardScope: .selected,
        selectedPairID: nil,
        statusFilter: .active,
        isCompact: false
    )
}

struct RefreshHealthSnapshot: Codable, Equatable {
    var lastUpdated: Date?
    var success: Bool
    var message: String

    static let empty = RefreshHealthSnapshot(lastUpdated: nil, success: true, message: "Not refreshed yet")
}

enum AppPreferencesStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupID)
    }

    static func load() -> AppPreferences {
        guard let defaults,
              let data = defaults.data(forKey: AppConstants.preferencesKey),
              let prefs = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            return .default
        }
        return prefs
    }

    static func save(_ preferences: AppPreferences) {
        guard let defaults,
              let data = try? JSONEncoder().encode(preferences) else {
            return
        }
        defaults.set(data, forKey: AppConstants.preferencesKey)
    }

    static func loadRefreshHealth() -> RefreshHealthSnapshot {
        guard let defaults,
              let data = defaults.data(forKey: AppConstants.refreshHealthKey),
              let snapshot = try? JSONDecoder().decode(RefreshHealthSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func saveRefreshHealth(_ snapshot: RefreshHealthSnapshot) {
        guard let defaults,
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: AppConstants.refreshHealthKey)
    }

    static func loadTestResults() -> [ConnectionTestResult] {
        guard let defaults,
              let data = defaults.data(forKey: AppConstants.testResultsKey),
              let results = try? JSONDecoder().decode([ConnectionTestResult].self, from: data) else {
            return []
        }
        return results
    }

    static func saveTestResults(_ results: [ConnectionTestResult]) {
        guard let defaults,
              let data = try? JSONEncoder().encode(results) else {
            return
        }
        defaults.set(data, forKey: AppConstants.testResultsKey)
    }
}
