import Foundation

enum JiraAPIError: LocalizedError {
    case invalidDomain
    case unauthorized
    case boardNotFound
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidDomain:
            return "Invalid Jira domain"
        case .unauthorized:
            return "Unauthorized"
        case .boardNotFound:
            return "Board not found"
        case .invalidResponse:
            return "Invalid response from Jira"
        case let .httpError(code, message):
            return "HTTP \(code): \(message)"
        }
    }
}

struct JiraAPIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let formatters = [
                ISO8601DateFormatter.jiraWithFractionalSeconds,
                ISO8601DateFormatter.jiraWithoutFractionalSeconds
            ]

            for formatter in formatters {
                if let date = formatter.date(from: value) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(value)"
            )
        }
        self.decoder = decoder
    }

    func testConnection(config: SprintConfig) async -> (authOK: Bool, results: [ConnectionTestResult]) {
        guard config.isConfigured else {
            return (false, [])
        }

        do {
            _ = try await validateAuth(config: config)
        } catch {
            return (false, config.validPairs.map {
                ConnectionTestResult(
                    id: $0.id,
                    projectKey: $0.projectKey,
                    boardId: $0.boardId,
                    success: false,
                    message: "Authentication failed"
                )
            })
        }

        var results: [ConnectionTestResult] = []
        for pair in config.validPairs {
            do {
                let sprints = try await fetchOpenSprints(config: config, boardId: pair.boardId)
                var totalTasks = 0
                var sprintsWithTasks = 0

                for sprint in sprints {
                    let issues = try await fetchSprintIssues(
                        config: config,
                        sprintId: sprint.id,
                        projectKey: pair.projectKey
                    )
                    totalTasks += issues.count
                    if !issues.isEmpty {
                        sprintsWithTasks += 1
                    }
                }

                let sprintNames = sprints.map(\.name).joined(separator: ", ")
                let sprintText = sprintNames.isEmpty
                    ? "no open sprints on board"
                    : "open sprints: \(sprintNames)"

                let taskText = totalTasks == 0
                    ? "no tasks assigned to you"
                    : "\(totalTasks) tasks across \(sprintsWithTasks) sprint(s)"

                results.append(
                    ConnectionTestResult(
                        id: pair.id,
                        projectKey: pair.projectKey,
                        boardId: pair.boardId,
                        success: true,
                        message: "Board \(pair.boardId) OK — \(taskText), \(sprintText)"
                    )
                )
            } catch JiraAPIError.boardNotFound {
                results.append(
                    ConnectionTestResult(
                        id: pair.id,
                        projectKey: pair.projectKey,
                        boardId: pair.boardId,
                        success: false,
                        message: "Board ID \(pair.boardId) not found"
                    )
                )
            } catch {
                results.append(
                    ConnectionTestResult(
                        id: pair.id,
                        projectKey: pair.projectKey,
                        boardId: pair.boardId,
                        success: false,
                        message: error.localizedDescription
                    )
                )
            }
        }

        return (true, results)
    }

    func fetchSprintData(config: SprintConfig) async -> SprintLoadResult {
        guard config.isConfigured else {
            return .failure(.notConfigured)
        }

        do {
            _ = try await validateAuth(config: config)
        } catch JiraAPIError.unauthorized {
            return .failure(.authFailed)
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }

        var sprintMap: [Int: JiraSprint] = [:]
        var issuesBySprint: [Int: [JiraIssue]] = [:]
        var sprintPair: [Int: ProjectBoardPair] = [:]
        var foundOpenSprint = false

        for pair in config.validPairs {
            let openSprints: [JiraSprint]
            do {
                openSprints = try await fetchOpenSprints(config: config, boardId: pair.boardId)
            } catch JiraAPIError.boardNotFound {
                return .failure(.boardNotFound(projectKey: pair.projectKey, boardId: pair.boardId))
            } catch {
                return .failure(.networkError(error.localizedDescription))
            }

            if !openSprints.isEmpty {
                foundOpenSprint = true
            }

            for sprint in openSprints {
                sprintMap[sprint.id] = sprint
                sprintPair[sprint.id] = pair

                let issues: [JiraIssue]
                do {
                    issues = try await fetchSprintIssues(
                        config: config,
                        sprintId: sprint.id,
                        projectKey: pair.projectKey
                    )
                } catch {
                    return .failure(.networkError(error.localizedDescription))
                }

                if !issues.isEmpty {
                    issuesBySprint[sprint.id] = issues
                }
            }
        }

        if issuesBySprint.isEmpty {
            return .failure(foundOpenSprint ? .noTasksAssigned : .noSprints)
        }

        let sections = buildSections(
            sprintMap: sprintMap,
            issuesBySprint: issuesBySprint,
            sprintPair: sprintPair,
            jiraDomain: config.normalizedDomain
        )

        if sections.isEmpty {
            return .failure(.noTasksAssigned)
        }

        return .success(sections: sections, jiraDomain: config.normalizedDomain)
    }

    private func validateAuth(config: SprintConfig) async throws -> JiraMyselfResponse {
        let url = try makeURL(config: config, path: "/rest/api/3/myself")
        return try await request(url: url, config: config)
    }

    private func fetchOpenSprints(config: SprintConfig, boardId: Int) async throws -> [JiraSprint] {
        let path = "/rest/agile/1.0/board/\(boardId)/sprint?state=active,future"
        let url = try makeURL(config: config, path: path)
        let response: SprintListResponse = try await request(url: url, config: config)
        return response.values.filter(\.isOpen)
    }

    private func fetchSprintIssues(
        config: SprintConfig,
        sprintId: Int,
        projectKey: String
    ) async throws -> [JiraIssue] {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(
                name: "jql",
                value: "project = \"\(projectKey)\" AND assignee = currentUser() ORDER BY status ASC, priority DESC"
            ),
            URLQueryItem(name: "fields", value: "summary,status,priority"),
            URLQueryItem(name: "maxResults", value: "100")
        ]

        guard let query = components.percentEncodedQuery else {
            throw JiraAPIError.invalidResponse
        }

        let path = "/rest/agile/1.0/sprint/\(sprintId)/issue?\(query)"
        let url = try makeURL(config: config, path: path)
        let response: AgileIssueSearchResponse = try await request(url: url, config: config)
        return response.issues.map { mapIssue($0, sprintId: sprintId) }
    }

    private func mapIssue(_ issue: SearchIssue, sprintId: Int) -> JiraIssue {
        JiraIssue(
            key: issue.key,
            summary: issue.fields.summary,
            statusName: issue.fields.status.name,
            statusCategoryKey: issue.fields.status.statusCategory.key,
            priorityName: issue.fields.priority?.name ?? "None",
            priorityId: issue.fields.priority?.id,
            sprintIds: [sprintId]
        )
    }

    private func buildSections(
        sprintMap: [Int: JiraSprint],
        issuesBySprint: [Int: [JiraIssue]],
        sprintPair: [Int: ProjectBoardPair],
        jiraDomain: String
    ) -> [SprintSection] {
        let sortedSprintIDs = issuesBySprint.keys.sorted { lhs, rhs in
            let lhsDate = sprintMap[lhs]?.endDate ?? .distantFuture
            let rhsDate = sprintMap[rhs]?.endDate ?? .distantFuture
            return lhsDate < rhsDate
        }

        return sortedSprintIDs.compactMap { sprintID in
            guard let sprint = sprintMap[sprintID],
                  let issues = issuesBySprint[sprintID],
                  let pair = sprintPair[sprintID],
                  !issues.isEmpty else {
                return nil
            }

            let doneCount = issues.filter { $0.statusCategoryKey == "done" }.count
            let progress = Double(doneCount) / Double(issues.count)
            let daysRemaining = sprint.endDate.map(daysRemainingUntil)
            let projectKey = pair.projectKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let encodedProject = projectKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectKey
            guard let boardURL = URL(string: "\(jiraDomain)/jira/software/c/projects/\(encodedProject)/boards/\(pair.boardId)"),
                  var sprintComponents = URLComponents(url: boardURL, resolvingAgainstBaseURL: false) else {
                return nil
            }
            sprintComponents.queryItems = [URLQueryItem(name: "sprint", value: String(sprint.id))]
            guard let sprintURL = sprintComponents.url else { return nil }

            let grouped = Dictionary(grouping: issues, by: \.statusName)
            let sortedStatusNames = grouped.keys.sorted()

            let statusGroups: [StatusGroup] = sortedStatusNames.compactMap { statusName in
                guard let statusIssues = grouped[statusName] else { return nil }

                let displays = statusIssues.compactMap { issue -> JiraIssueDisplay? in
                    let encodedKey = issue.key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? issue.key
                    guard let browseURL = URL(string: "\(jiraDomain)/browse/\(encodedKey)") else {
                        return nil
                    }
                    return JiraIssueDisplay(
                        id: issue.key,
                        key: issue.key,
                        summary: issue.summary,
                        statusName: issue.statusName,
                        statusCategoryKey: issue.statusCategoryKey,
                        priorityName: issue.priorityName,
                        priorityId: issue.priorityId,
                        browseURL: browseURL
                    )
                }

                return StatusGroup(
                    id: statusName,
                    name: statusName.uppercased(),
                    issues: displays
                )
            }

            return SprintSection(
                id: "\(pair.id.uuidString)-\(sprint.id)",
                sprintId: sprint.id,
                name: sprint.name,
                endDate: sprint.endDate,
                progress: progress,
                daysRemaining: daysRemaining,
                projectKey: projectKey,
                boardId: pair.boardId,
                pairId: pair.id,
                boardURL: boardURL,
                sprintURL: sprintURL,
                statusGroups: statusGroups
            )
        }
    }

    private func daysRemainingUntil(_ endDate: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: endDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    private func makeURL(config: SprintConfig, path: String) throws -> URL {
        let domain = config.normalizedDomain
        guard let url = URL(string: domain + path) else {
            throw JiraAPIError.invalidDomain
        }
        return url
    }

    private func request<T: Decodable>(
        url: URL,
        config: SprintConfig,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(makeAuthHeader(config: config), forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JiraAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw JiraAPIError.invalidResponse
            }
        case 401, 403:
            throw JiraAPIError.unauthorized
        case 404:
            throw JiraAPIError.boardNotFound
        default:
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw JiraAPIError.httpError(httpResponse.statusCode, body)
        }
    }

    private func makeAuthHeader(config: SprintConfig) -> String {
        let credential = "\(config.email):\(config.apiToken)"
        let encoded = Data(credential.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }
}

private extension ISO8601DateFormatter {
    static let jiraWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let jiraWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
