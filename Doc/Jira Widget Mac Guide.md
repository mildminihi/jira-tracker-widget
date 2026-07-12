# Role
You are an expert macOS and iOS developer specializing in Swift, SwiftUI, and WidgetKit.

# Objective
Create a native macOS app with a Widget Extension (systemLarge size only) that tracks the user's active Jira sprint tasks. 

# Architecture & Project Setup
1.  **Main macOS App:** A minimal configuration screen.
    *   UI to input: Jira Domain (e.g., https://your-domain.atlassian.net), Email, Atlassian API Token, and Project Key.
    *   Save these credentials securely using `AppGroups` (e.g., `group.com.yourname.jirawidget`) so the Widget Extension can read them.
2.  **Widget Extension:** A macOS Widget showing the sprint progress and user's tasks.
    *   Accesses credentials from `AppGroups`.
    *   Uses `TimelineProvider` to refresh data every 30 minutes.

# Data Layer (Jira REST API)
*   **Authentication:** Basic Auth using the saved Email and API Token.
*   **Endpoint:** `/rest/api/3/search`
*   **JQL:** `project = "{ProjectKey}" AND sprint in openSprints() AND assignee = currentUser() ORDER BY status ASC, priority DESC`
*   **Data parsing needed:**
    *   Sprint Name and Sprint End Date (to calculate days remaining).
    *   Total tasks vs. "Done" tasks (to calculate progress percentage).
    *   Tasks grouped by Status (e.g., "To Do", "In Progress", "Done").
    *   Task details: Issue Key, Summary, Status, Priority Name, Priority Color.

# UI/UX Specifications (WidgetKit)
Lock the widget size to `.supportedFamilies([.systemLarge])`.

**1. Header Section:**
*   HStack containing Sprint Name (headline).
*   A visually appealing horizontal Progress Bar (gradient color) showing Sprint completion percentage.
*   A Sprint Countdown pill (e.g., "⏳ 3d left"). Turn text red if <= 2 days.

**2. Content Section (Scrollable if needed, or clamped):**
*   Group tasks by Status. Show a small header for each Status (e.g., "IN PROGRESS").
*   For each task, create a `TaskCardView`.
*   `TaskCardView` components:
    *   Vertical color bar indicating Priority on the left edge.
    *   Issue Key (e.g., IOS-123) and Priority badge.
    *   Issue Summary (line limit 1).
*   Wrap each `TaskCardView` in a `Link` component so clicking it opens the default browser directly to the ticket URL (`{JiraDomain}/browse/{IssueKey}`).

# Output Instructions
1. Provide the code for the Main App configuration view (SwiftUI) and UserDefaults/AppGroup manager.
2. Provide the Network API manager for fetching and decoding Jira JSON.
3. Provide the complete WidgetKit implementation (TimelineProvider, SimpleEntry, and Widget View).
4. Outline step-by-step instructions on what I need to manually configure in Xcode (e.g., Enabling App Groups, adding Widget Target).