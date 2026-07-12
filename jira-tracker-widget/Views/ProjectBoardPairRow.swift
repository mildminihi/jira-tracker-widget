import SwiftUI

struct ProjectBoardPairRow: View {
    @Binding var pair: ProjectBoardPair
    let index: Int
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Project \(index + 1)")
                    .font(.headline)
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Project Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. IOS", text: $pair.projectKey)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Board ID")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. 42", value: $pair.boardId, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ProjectBoardPairRow(
        pair: .constant(ProjectBoardPair(projectKey: "IOS", boardId: 42)),
        index: 0,
        onRemove: {}
    )
    .padding()
}
