import Foundation

enum AppConstants {
    static let appGroupID = "group.supanat.wanroj.jira-tracker-widget"
    static let configKey = "widgetConfig" // legacy key name; keep for existing installs
    static let preferencesKey = "appPreferences"
    static let refreshHealthKey = "refreshHealth"
    static let testResultsKey = "testResults"
    static let refreshIntervalMinutes = 30
    static let maxProjectPairs = 3
    static let widgetKind = "JiraSprintPriorityWidget"
}
