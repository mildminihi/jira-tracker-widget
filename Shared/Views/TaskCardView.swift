import AppKit
import SwiftUI

struct TaskCardView: View {
    let issue: JiraIssueDisplay
    var isCompact = false

    @State private var didCopy = false

    var body: some View {
        HStack(spacing: 4) {
            Link(destination: issue.browseURL) {
                HStack(spacing: isCompact ? 6 : 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(PriorityColors.color(for: issue.priorityName, priorityId: issue.priorityId))
                        .frame(width: 4)

                    VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
                        HStack(spacing: 6) {
                            Text(issue.key)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)

                            if !isCompact {
                                Text(issue.priorityName)
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(issue.summary)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
            }

            Button(action: copyLink) {
                Image(systemName: didCopy ? "checkmark" : "link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(didCopy ? .green : .secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(didCopy ? "Copied" : "Copy link")
        }
        .padding(.vertical, isCompact ? 4 : 6)
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private func copyLink() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(issue.browseURL.absoluteString, forType: .string)
        didCopy = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }
}
