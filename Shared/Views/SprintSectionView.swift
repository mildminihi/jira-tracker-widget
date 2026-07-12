import SwiftUI

struct SprintSectionView: View {
    let section: SprintSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(section.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                countdownPill
            }

            ProgressView(value: section.progress)
                .tint(
                    LinearGradient(
                        colors: [.blue, .purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            ForEach(section.statusGroups) { group in
                Text(group.name)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                ForEach(group.issues) { issue in
                    TaskCardView(issue: issue)
                }
            }
        }
    }

    @ViewBuilder
    private var countdownPill: some View {
        if let days = section.daysRemaining {
            let label = days == 0 ? "Ends today" : days == 1 ? "1d left" : "\(days)d left"
            let isUrgent = days <= 2

            Text("⏳ \(label)")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isUrgent ? Color.red.opacity(0.15) : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(isUrgent ? .red : .secondary)
        }
    }
}
