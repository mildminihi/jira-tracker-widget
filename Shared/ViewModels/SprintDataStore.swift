import Combine
import Foundation

@MainActor
final class SprintDataStore: ObservableObject {
    @Published private(set) var result: WidgetLoadResult = .failure(.notConfigured)
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?

    private let apiClient = JiraAPIClient()

    func refreshIfNeeded(force: Bool = false) async {
        guard force || shouldRefresh else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        guard let config = AppGroupStorage.loadConfig() else {
            result = .failure(.notConfigured)
            return
        }

        result = await apiClient.fetchWidgetData(config: config)
        lastUpdated = Date()
    }

    private var shouldRefresh: Bool {
        guard let lastUpdated else { return true }
        let interval = TimeInterval(AppConstants.refreshIntervalMinutes * 60)
        return Date().timeIntervalSince(lastUpdated) >= interval
    }
}
