import WidgetKit
import SwiftUI

struct PrioritySummaryEntry: TimelineEntry {
    let date: Date
    let title: String
    let isUrgent: Bool
    let counts: [PriorityCount]
    let errorMessage: String?
}

struct PrioritySummaryProvider: TimelineProvider {
    private let apiClient = JiraAPIClient()

    func placeholder(in context: Context) -> PrioritySummaryEntry {
        PrioritySummaryEntry(
            date: .now,
            title: "3d · 5",
            isUrgent: false,
            counts: [
                PriorityCount(bucket: .high, count: 2),
                PriorityCount(bucket: .medium, count: 3)
            ],
            errorMessage: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PrioritySummaryEntry) -> Void) {
        Task {
            completion(await loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrioritySummaryEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let next = Date().addingTimeInterval(TimeInterval(AppConstants.refreshIntervalMinutes * 60))
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func loadEntry() async -> PrioritySummaryEntry {
        let preferences = AppPreferencesStore.load()
        guard let config = AppGroupStorage.loadConfig(), config.isConfigured else {
            return PrioritySummaryEntry(
                date: .now,
                title: "",
                isUrgent: false,
                counts: [],
                errorMessage: SprintError.notConfigured.message
            )
        }

        let result = await apiClient.fetchSprintData(config: config)
        switch result {
        case let .success(sections, _):
            let scoped = SprintMetrics.scopedSections(sections, preferences: preferences, pairs: config.pairs)
            return PrioritySummaryEntry(
                date: .now,
                title: SprintMetrics.menuBarTitle(for: scoped),
                isUrgent: SprintMetrics.isUrgent(in: scoped),
                counts: SprintMetrics.priorityCounts(in: scoped),
                errorMessage: nil
            )
        case let .failure(error):
            return PrioritySummaryEntry(
                date: .now,
                title: "",
                isUrgent: false,
                counts: [],
                errorMessage: error.message
            )
        }
    }
}

struct PrioritySummaryWidget: Widget {
    let kind = AppConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrioritySummaryProvider()) { entry in
            PrioritySummaryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Jira Priority Summary")
        .description("Non-done task counts by priority for the selected board scope.")
        .supportedFamilies([.systemSmall])
    }
}

struct PrioritySummaryWidgetView: View {
    let entry: PrioritySummaryEntry

    var body: some View {
        if let errorMessage = entry.errorMessage {
            VStack(alignment: .leading, spacing: 6) {
                Text("Jira")
                    .font(.caption.weight(.semibold))
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title.isEmpty ? "0" : entry.title)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(entry.isUrgent ? .red : .primary)

                if entry.counts.isEmpty {
                    Text("No open tasks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.counts) { row in
                        HStack {
                            Circle()
                                .fill(PriorityColors.color(for: row.bucket.title, priorityId: nil))
                                .frame(width: 8, height: 8)
                            Text(row.bucket.title)
                                .font(.caption2)
                            Spacer()
                            Text("\(row.count)")
                                .font(.caption.weight(.semibold).monospacedDigit())
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

#Preview(as: .systemSmall) {
    PrioritySummaryWidget()
} timeline: {
    PrioritySummaryEntry(
        date: .now,
        title: "2d · 4",
        isUrgent: true,
        counts: [
            PriorityCount(bucket: .highest, count: 1),
            PriorityCount(bucket: .medium, count: 3)
        ],
        errorMessage: nil
    )
}
