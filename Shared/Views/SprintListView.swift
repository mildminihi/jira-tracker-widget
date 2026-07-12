import SwiftUI

struct SprintListView: View {
    let sections: [SprintSection]
    var showsOpenBoard = false
    var isCompact = false
    var emptyMessage: String?

    var body: some View {
        if sections.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(emptyMessage ?? "No tasks match the current filters.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
                    ForEach(sections) { section in
                        SprintSectionView(
                            section: section,
                            showsOpenBoard: showsOpenBoard,
                            isCompact: isCompact
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
        }
    }
}

struct SprintErrorView: View {
    let error: SprintError

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(error.message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
