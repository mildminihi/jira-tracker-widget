import SwiftUI

@main
struct jira_tracker_widgetApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
        } label: {
            Image(systemName: "checklist")
        }
        .menuBarExtraStyle(.window)

        Settings {
            ConfigView()
        }
    }
}
