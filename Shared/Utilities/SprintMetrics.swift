import Foundation

enum PriorityBucket: String, CaseIterable, Identifiable, Codable {
    case highest
    case high
    case medium
    case low
    case lowest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highest: return "Highest"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .lowest: return "Lowest"
        }
    }

    static func bucket(for priorityName: String, priorityId: String?) -> PriorityBucket {
        let normalized = priorityName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalized {
        case "highest", "blocker", "critical":
            return .highest
        case "high", "major":
            return .high
        case "medium", "normal":
            return .medium
        case "low", "minor":
            return .low
        case "lowest", "trivial":
            return .lowest
        default:
            break
        }

        switch priorityId {
        case "1": return .highest
        case "2": return .high
        case "3": return .medium
        case "4": return .low
        case "5": return .lowest
        default: return .medium
        }
    }
}

struct PriorityCount: Identifiable, Equatable {
    let bucket: PriorityBucket
    let count: Int

    var id: String { bucket.id }
}

enum SprintMetrics {
    static func scopedSections(
        _ sections: [SprintSection],
        preferences: AppPreferences,
        pairs: [ProjectBoardPair]
    ) -> [SprintSection] {
        switch preferences.boardScope {
        case .all:
            return sections
        case .selected:
            let pairID = preferences.selectedPairID ?? pairs.first(where: \.isValid)?.id
            guard let pairID,
                  let pair = pairs.first(where: { $0.id == pairID && $0.isValid }) else {
                return sections
            }
            return sections.filter {
                $0.projectKey.caseInsensitiveCompare(pair.projectKey) == .orderedSame
                    && $0.boardId == pair.boardId
            }
        }
    }

    static func filterSections(
        _ sections: [SprintSection],
        statusFilter: StatusFilter,
        searchText: String
    ) -> [SprintSection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return sections.compactMap { section in
            let groups = section.statusGroups.compactMap { group -> StatusGroup? in
                let issues = group.issues.filter { issue in
                    matchesStatus(issue, filter: statusFilter)
                        && matchesSearch(issue, query: query)
                }
                guard !issues.isEmpty else { return nil }
                return StatusGroup(id: group.id, name: group.name, issues: issues)
            }
            guard !groups.isEmpty else { return nil }
            return SprintSection(
                id: section.id,
                sprintId: section.sprintId,
                name: section.name,
                endDate: section.endDate,
                progress: section.progress,
                daysRemaining: section.daysRemaining,
                projectKey: section.projectKey,
                boardId: section.boardId,
                pairId: section.pairId,
                boardURL: section.boardURL,
                sprintURL: section.sprintURL,
                statusGroups: groups
            )
        }
    }

    static func nonDoneIssues(in sections: [SprintSection]) -> [JiraIssueDisplay] {
        sections.flatMap(\.statusGroups).flatMap(\.issues).filter {
            !$0.isDone
        }
    }

    static func nonDoneCount(in sections: [SprintSection]) -> Int {
        nonDoneIssues(in: sections).count
    }

    static func nearestDaysRemaining(in sections: [SprintSection]) -> Int? {
        sections.compactMap(\.daysRemaining).min()
    }

    static func priorityCounts(in sections: [SprintSection]) -> [PriorityCount] {
        let issues = nonDoneIssues(in: sections)
        var tallies: [PriorityBucket: Int] = [:]
        for issue in issues {
            let bucket = PriorityBucket.bucket(for: issue.priorityName, priorityId: issue.priorityId)
            tallies[bucket, default: 0] += 1
        }
        return PriorityBucket.allCases.compactMap { bucket in
            let count = tallies[bucket, default: 0]
            guard count > 0 else { return nil }
            return PriorityCount(bucket: bucket, count: count)
        }
    }

    static func hasHighPriorityOpen(in sections: [SprintSection]) -> Bool {
        nonDoneIssues(in: sections).contains {
            let bucket = PriorityBucket.bucket(for: $0.priorityName, priorityId: $0.priorityId)
            return bucket == .highest || bucket == .high
        }
    }

    static func isUrgent(in sections: [SprintSection]) -> Bool {
        if let days = nearestDaysRemaining(in: sections), days <= 2 {
            return true
        }
        return hasHighPriorityOpen(in: sections)
    }

    static func menuBarTitle(for sections: [SprintSection]) -> String {
        let count = nonDoneCount(in: sections)
        if let days = nearestDaysRemaining(in: sections) {
            let dayLabel = days <= 0 ? "0d" : "\(days)d"
            return "\(dayLabel) · \(count)"
        }
        return "\(count)"
    }

    private static func matchesStatus(_ issue: JiraIssueDisplay, filter: StatusFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .active:
            return !issue.isDone
        case .inProgress:
            return issue.statusCategoryKey == "indeterminate"
                || issue.statusName.lowercased().contains("progress")
        }
    }

    private static func matchesSearch(_ issue: JiraIssueDisplay, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return issue.key.lowercased().contains(query)
            || issue.summary.lowercased().contains(query)
    }
}
