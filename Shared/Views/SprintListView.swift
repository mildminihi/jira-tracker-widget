import SwiftUI

struct SprintListView: View {
    let result: WidgetLoadResult

    var body: some View {
        Group {
            switch result {
            case let .success(sections, _):
                ScrollView {
                    sprintContent(sections: sections)
                }
            case let .failure(error):
                errorView(error: error)
            }
        }
    }

    @ViewBuilder
    private func sprintContent(sections: [SprintSection]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(sections) { section in
                SprintSectionView(section: section)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private func errorView(error: WidgetError) -> some View {
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
