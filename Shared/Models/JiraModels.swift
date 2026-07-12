import Foundation

struct WidgetConfig: Codable, Equatable {
    var jiraDomain: String
    var email: String
    var apiToken: String
    var pairs: [ProjectBoardPair]

    static let empty = WidgetConfig(
        jiraDomain: "",
        email: "",
        apiToken: "",
        pairs: [ProjectBoardPair()]
    )

    var isConfigured: Bool {
        !jiraDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !validPairs.isEmpty
    }

    var validPairs: [ProjectBoardPair] {
        pairs.filter { $0.isValid }
    }

    var normalizedDomain: String {
        var domain = jiraDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        while domain.hasSuffix("/") {
            domain.removeLast()
        }
        return domain
    }
}

struct ProjectBoardPair: Codable, Equatable, Identifiable {
    var id: UUID
    var projectKey: String
    var boardId: Int

    init(id: UUID = UUID(), projectKey: String = "", boardId: Int = 0) {
        self.id = id
        self.projectKey = projectKey
        self.boardId = boardId
    }

    var isValid: Bool {
        !projectKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && boardId > 0
    }
}

enum WidgetError: Equatable {
    case notConfigured
    case authFailed
    case boardNotFound(projectKey: String, boardId: Int)
    case noSprints
    case noTasksAssigned
    case networkError(String)

    var message: String {
        switch self {
        case .notConfigured:
            return "Open Jira Sprint Tracker to configure"
        case .authFailed:
            return "Authentication failed — check email and API token"
        case let .boardNotFound(projectKey, boardId):
            return "Board ID \(boardId) invalid for project \(projectKey)"
        case .noSprints:
            return "No open sprints on the configured board"
        case .noTasksAssigned:
            return "No tasks assigned to you in open sprints"
        case let .networkError(message):
            return "Unable to reach Jira: \(message)"
        }
    }
}

struct JiraSprint: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let state: String
    let endDate: Date?

    var isOpen: Bool {
        state.lowercased() != "closed"
    }
}

struct JiraIssue: Equatable {
    let key: String
    let summary: String
    let statusName: String
    let statusCategoryKey: String
    let priorityName: String
    let priorityId: String?
    let sprintIds: [Int]
}

struct ConnectionTestResult: Identifiable, Equatable, Codable {
    let id: UUID
    let projectKey: String
    let boardId: Int
    let success: Bool
    let message: String
}

struct JiraIssueDisplay: Identifiable, Equatable, Codable {
    let id: String
    let key: String
    let summary: String
    let statusName: String
    let statusCategoryKey: String
    let priorityName: String
    let priorityId: String?
    let browseURL: URL

    var isDone: Bool {
        statusCategoryKey == "done"
    }
}

struct StatusGroup: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let issues: [JiraIssueDisplay]
}

struct SprintSection: Identifiable, Equatable, Codable {
    let id: String
    let sprintId: Int
    let name: String
    let endDate: Date?
    let progress: Double
    let daysRemaining: Int?
    let projectKey: String
    let boardId: Int
    let pairId: UUID
    let boardURL: URL
    let sprintURL: URL
    let statusGroups: [StatusGroup]
}

enum WidgetLoadResult: Equatable {
    case success(sections: [SprintSection], jiraDomain: String)
    case failure(WidgetError)
}

struct SprintListResponse: Decodable {
    let values: [JiraSprint]
}

struct SearchJQLResponse: Decodable {
    let issues: [SearchIssue]
    let isLast: Bool?
    let nextPageToken: String?
}

struct AgileIssueSearchResponse: Decodable {
    let issues: [SearchIssue]
}

struct SearchJQLRequest: Encodable {
    let jql: String
    let maxResults: Int
    let fields: [String]
    let nextPageToken: String?

    init(jql: String, maxResults: Int, fields: [String], nextPageToken: String? = nil) {
        self.jql = jql
        self.maxResults = maxResults
        self.fields = fields
        self.nextPageToken = nextPageToken
    }
}

struct SearchIssue: Decodable {
    let key: String
    let fields: SearchIssueFields
}

struct SearchIssueFields: Decodable {
    let summary: String
    let status: JiraStatus
    let priority: JiraPriority?
    let sprint: SprintFieldValue?
}

struct JiraStatus: Decodable {
    let name: String
    let statusCategory: JiraStatusCategory
}

struct JiraStatusCategory: Decodable {
    let key: String
}

struct JiraPriority: Decodable {
    let name: String
    let id: String?
}

enum SprintFieldValue: Decodable {
    case single(JiraSprintField)
    case multiple([JiraSprintField])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([JiraSprintField].self) {
            self = .multiple(array)
            return
        }
        let single = try container.decode(JiraSprintField.self)
        self = .single(single)
    }

    var sprintFields: [JiraSprintField] {
        switch self {
        case let .single(field):
            return [field]
        case let .multiple(fields):
            return fields
        }
    }
}

struct JiraSprintField: Decodable {
    let id: Int
    let name: String?
    let state: String?
    let endDate: Date?
}

struct JiraMyselfResponse: Decodable {
    let displayName: String
}
