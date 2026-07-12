import SwiftUI

@main
struct jira_tracker_widgetApp: App {
    @StateObject private var store = SprintDataStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(store: store)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                if !store.menuBarTitle.isEmpty {
                    Text(store.menuBarTitle)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(store.isUrgent ? .red : .primary)
        }
        .menuBarExtraStyle(.window)

        Settings {
            ConfigView(store: store)
        }
    }
}
