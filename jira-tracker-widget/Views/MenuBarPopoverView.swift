import AppKit
import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = SprintDataStore()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 420, height: 520)
        .task {
            await store.refreshIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await store.refreshIfNeeded()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Jira Sprint Tracker")
                    .font(.headline)
                if let lastUpdated = store.lastUpdated {
                    Text("Updated \(lastUpdated, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .disabled(store.isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.lastUpdated == nil {
            VStack {
                Spacer()
                ProgressView("Loading sprint tasks...")
                Spacer()
            }
        } else {
            SprintListView(result: store.result)
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            SettingsLink {
                Text("Settings")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

#Preview {
    MenuBarPopoverView()
}
