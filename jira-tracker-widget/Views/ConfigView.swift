import SwiftUI

struct ConfigView: View {
    @State private var config = AppGroupStorage.loadConfig() ?? .empty
    @State private var boardLinkInput = ""
    @State private var linkParseMessage: String?
    @State private var linkParseIsError = false
    @State private var testResults: [ConnectionTestResult] = []
    @State private var authFailed = false
    @State private var isTesting = false
    @State private var isSaving = false
    @State private var saveMessage: String?

    private let apiClient = JiraAPIClient()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    GroupBox("Jira Account") {
                        VStack(alignment: .leading, spacing: 12) {
                            labeledField("Jira Domain", text: $config.jiraDomain, prompt: "https://your-domain.atlassian.net")
                            labeledField("Email", text: $config.email, prompt: "you@company.com")
                            secureField("API Token", text: $config.apiToken, prompt: "Atlassian API token")
                        }
                        .padding(.vertical, 4)
                    }

                    GroupBox("Projects") {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Quick add from board link")
                                    .font(.subheadline.weight(.semibold))
                                Text("Copy your Jira board URL from the browser and paste it here.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                TextField(
                                    "https://your-domain.atlassian.net/jira/software/c/projects/LM/boards/99",
                                    text: $boardLinkInput
                                )
                                .textFieldStyle(.roundedBorder)

                                HStack(spacing: 12) {
                                    Button("Parse Link") {
                                        parseBoardLink()
                                    }
                                    .disabled(boardLinkInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                    if !boardLinkInput.isEmpty {
                                        Button("Clear") {
                                            boardLinkInput = ""
                                            linkParseMessage = nil
                                        }
                                    }
                                }

                                if let linkParseMessage {
                                    Text(linkParseMessage)
                                        .font(.caption)
                                        .foregroundStyle(linkParseIsError ? .red : .green)
                                }
                            }

                            Divider()

                            Text("Add up to \(AppConstants.maxProjectPairs) project and board pairs.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(Array(config.pairs.enumerated()), id: \.element.id) { index, _ in
                                ProjectBoardPairRow(
                                    pair: $config.pairs[index],
                                    index: index,
                                    onRemove: { removePair(at: index) }
                                )
                            }

                            if config.pairs.count < AppConstants.maxProjectPairs {
                                Button {
                                    addPair()
                                } label: {
                                    Label("Add Project", systemImage: "plus.circle")
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if authFailed {
                        Text("Authentication failed — check email and API token.")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }

                    if !testResults.isEmpty {
                        GroupBox("Test Results") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(testResults) { result in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(result.success ? .green : .red)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(result.projectKey) · Board \(result.boardId)")
                                                .font(.subheadline.weight(.semibold))
                                            Text(result.message)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    Task { await testConnection() }
                } label: {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Test Connection")
                    }
                }
                .disabled(isTesting)

                Button {
                    saveConfig()
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)

                if let saveMessage {
                    Text(saveMessage)
                        .foregroundStyle(.green)
                        .font(.callout)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 520, minHeight: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Jira Sprint Tracker")
                .font(.largeTitle.bold())
            Text("Configure your Jira credentials and project boards for the menu bar app.")
                .foregroundStyle(.secondary)
        }
    }

    private func labeledField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func secureField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            SecureField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func parseBoardLink() {
        linkParseMessage = nil
        linkParseIsError = false

        guard let parsed = JiraBoardURLParser.parse(boardLinkInput) else {
            linkParseMessage = "Could not parse link. Use a Jira board URL containing /projects/KEY/boards/ID"
            linkParseIsError = true
            return
        }

        config.jiraDomain = parsed.jiraDomain

        if let index = config.pairs.firstIndex(where: { !$0.isValid }) {
            config.pairs[index] = ProjectBoardPair(
                id: config.pairs[index].id,
                projectKey: parsed.projectKey,
                boardId: parsed.boardId
            )
        } else if config.pairs.count < AppConstants.maxProjectPairs {
            config.pairs.append(
                ProjectBoardPair(projectKey: parsed.projectKey, boardId: parsed.boardId)
            )
        } else {
            config.pairs[config.pairs.count - 1] = ProjectBoardPair(
                id: config.pairs[config.pairs.count - 1].id,
                projectKey: parsed.projectKey,
                boardId: parsed.boardId
            )
        }

        linkParseMessage = "Added \(parsed.projectKey) · Board \(parsed.boardId)"
        boardLinkInput = ""
    }

    private func addPair() {
        guard config.pairs.count < AppConstants.maxProjectPairs else { return }
        config.pairs.append(ProjectBoardPair())
    }

    private func removePair(at index: Int) {
        guard config.pairs.count > 1 else {
            config.pairs[0] = ProjectBoardPair()
            return
        }
        config.pairs.remove(at: index)
    }

    private func saveConfig() {
        isSaving = true
        defer { isSaving = false }

        config.pairs = Array(config.pairs.prefix(AppConstants.maxProjectPairs))
        if config.pairs.isEmpty {
            config.pairs = [ProjectBoardPair()]
        }

        AppGroupStorage.saveConfig(config)
        saveMessage = "Saved."
    }

    private func testConnection() async {
        isTesting = true
        authFailed = false
        testResults = []
        defer { isTesting = false }

        let result = await apiClient.testConnection(config: config)
        authFailed = !result.authOK
        testResults = result.results
    }
}

#Preview {
    ConfigView()
}
