import AppKit
import SwiftUI

struct MenuBarPopoverView: View {
    @ObservedObject var store: SprintDataStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
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
                    .foregroundStyle(store.isUrgent ? .red : .primary)
                if let lastUpdated = store.lastUpdated {
                    Text("Updated \(lastUpdated, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle(isOn: compactBinding) {
                Text("Compact")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .help("Denser task cards")

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

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Scope", selection: scopeBinding) {
                ForEach(BoardScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if store.preferences.boardScope == .selected {
                Picker("Board", selection: selectedPairBinding) {
                    ForEach(store.config.validPairs) { pair in
                        Text("\(pair.projectKey) · \(pair.boardId)").tag(Optional(pair.id))
                    }
                }
                .labelsHidden()
            }

            HStack(spacing: 6) {
                ForEach(StatusFilter.allCases) { filter in
                    filterChip(filter)
                }
            }

            TextField("Search key or summary", text: $store.searchText)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
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
            switch store.result {
            case .success:
                SprintListView(
                    sections: store.displaySections,
                    showsOpenBoard: store.preferences.boardScope == .selected,
                    isCompact: store.preferences.isCompact,
                    emptyMessage: store.scopedSections.isEmpty
                        ? "No tasks for this board scope."
                        : "No tasks match the current filters."
                )
            case let .failure(error):
                SprintErrorView(error: error)
            }
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

    private func filterChip(_ filter: StatusFilter) -> some View {
        let selected = store.preferences.statusFilter == filter
        return Button {
            store.updatePreferences { $0.statusFilter = filter }
        } label: {
            Text(filter.title)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(selected ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var scopeBinding: Binding<BoardScope> {
        Binding(
            get: { store.preferences.boardScope },
            set: { newValue in
                store.updatePreferences { $0.boardScope = newValue }
            }
        )
    }

    private var selectedPairBinding: Binding<UUID?> {
        Binding(
            get: { store.preferences.selectedPairID },
            set: { newValue in
                store.updatePreferences { $0.selectedPairID = newValue }
            }
        )
    }

    private var compactBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.isCompact },
            set: { newValue in
                store.updatePreferences { $0.isCompact = newValue }
            }
        )
    }
}

#Preview {
    MenuBarPopoverView(store: SprintDataStore())
}
