import Combine
import Foundation
import WidgetKit

@MainActor
final class SprintDataStore: ObservableObject {
    @Published private(set) var result: SprintLoadResult = .failure(.notConfigured)
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published var preferences: AppPreferences
    @Published private(set) var refreshHealth: RefreshHealthSnapshot
    @Published var searchText = ""

    private let apiClient = JiraAPIClient()

    init() {
        preferences = AppPreferencesStore.load()
        refreshHealth = AppPreferencesStore.loadRefreshHealth()
        lastUpdated = refreshHealth.lastUpdated
        ensureSelectedPair()
        Task { await runBackgroundRefreshLoop() }
    }

    private func runBackgroundRefreshLoop() async {
        await refreshIfNeeded(force: true)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            await refreshIfNeeded()
        }
    }

    var config: SprintConfig {
        AppGroupStorage.loadConfig() ?? .empty
    }

    var scopedSections: [SprintSection] {
        guard case let .success(sections, _) = result else { return [] }
        return SprintMetrics.scopedSections(sections, preferences: preferences, pairs: config.pairs)
    }

    var displaySections: [SprintSection] {
        SprintMetrics.filterSections(
            scopedSections,
            statusFilter: preferences.statusFilter,
            searchText: searchText
        )
    }

    var menuBarTitle: String {
        guard case .success = result else { return "" }
        return SprintMetrics.menuBarTitle(for: scopedSections)
    }

    var isUrgent: Bool {
        guard case .success = result else { return false }
        return SprintMetrics.isUrgent(in: scopedSections)
    }

    var priorityCounts: [PriorityCount] {
        SprintMetrics.priorityCounts(in: scopedSections)
    }

    func updatePreferences(_ update: (inout AppPreferences) -> Void) {
        update(&preferences)
        ensureSelectedPair()
        AppPreferencesStore.save(preferences)
        WidgetCenter.shared.reloadAllTimelines()
        objectWillChange.send()
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard force || shouldRefresh else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        guard let config = AppGroupStorage.loadConfig() else {
            result = .failure(.notConfigured)
            persistHealth(success: false, message: SprintError.notConfigured.message)
            return
        }

        ensureSelectedPair(using: config)
        let loadResult = await apiClient.fetchSprintData(config: config)
        result = loadResult
        lastUpdated = Date()

        switch loadResult {
        case .success:
            persistHealth(success: true, message: "Last refresh succeeded")
        case let .failure(error):
            persistHealth(success: false, message: error.message)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func ensureSelectedPair(using config: SprintConfig? = nil) {
        let currentConfig = config ?? self.config
        let valid = currentConfig.validPairs
        guard !valid.isEmpty else {
            preferences.selectedPairID = nil
            return
        }
        if let selected = preferences.selectedPairID,
           valid.contains(where: { $0.id == selected }) {
            return
        }
        preferences.selectedPairID = valid[0].id
        AppPreferencesStore.save(preferences)
    }

    private func persistHealth(success: Bool, message: String) {
        let snapshot = RefreshHealthSnapshot(
            lastUpdated: Date(),
            success: success,
            message: message
        )
        refreshHealth = snapshot
        AppPreferencesStore.saveRefreshHealth(snapshot)
    }

    private var shouldRefresh: Bool {
        guard let lastUpdated else { return true }
        let interval = TimeInterval(AppConstants.refreshIntervalMinutes * 60)
        return Date().timeIntervalSince(lastUpdated) >= interval
    }
}
