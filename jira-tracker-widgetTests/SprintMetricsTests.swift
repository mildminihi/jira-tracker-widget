import XCTest
@testable import Jira_Sprint_Tracker

final class SprintMetricsTests: XCTestCase {

    private let pairA = ProjectBoardPair(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, projectKey: "LM", boardId: 1)
    private let pairB = ProjectBoardPair(id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!, projectKey: "ABC", boardId: 2)

    func testScopedSectionsSelectedBoard() {
        let sections = [
            makeSection(id: "a", projectKey: "LM", boardId: 1, pairId: pairA.id, daysRemaining: 3, issues: [makeIssue(key: "LM-1")]),
            makeSection(id: "b", projectKey: "ABC", boardId: 2, pairId: pairB.id, daysRemaining: 5, issues: [makeIssue(key: "ABC-1")])
        ]
        var preferences = AppPreferences.default
        preferences.boardScope = .selected
        preferences.selectedPairID = pairA.id

        let scoped = SprintMetrics.scopedSections(sections, preferences: preferences, pairs: [pairA, pairB])

        XCTAssertEqual(scoped.map(\.id), ["a"])
    }

    func testFilterActiveExcludesDone() {
        let sections = [
            makeSection(
                id: "a",
                projectKey: "LM",
                boardId: 1,
                pairId: pairA.id,
                daysRemaining: 2,
                issues: [
                    makeIssue(key: "LM-1", statusCategoryKey: "new"),
                    makeIssue(key: "LM-2", statusCategoryKey: "done")
                ]
            )
        ]

        let filtered = SprintMetrics.filterSections(sections, statusFilter: .active, searchText: "")

        XCTAssertEqual(filtered.first?.statusGroups.first?.issues.map(\.key), ["LM-1"])
    }

    func testSearchMatchesKeyAndSummary() {
        let sections = [
            makeSection(
                id: "a",
                projectKey: "LM",
                boardId: 1,
                pairId: pairA.id,
                daysRemaining: 2,
                issues: [
                    makeIssue(key: "LM-10", summary: "Fix login"),
                    makeIssue(key: "LM-20", summary: "Ship widget")
                ]
            )
        ]

        let byKey = SprintMetrics.filterSections(sections, statusFilter: .all, searchText: "lm-20")
        let bySummary = SprintMetrics.filterSections(sections, statusFilter: .all, searchText: "login")

        XCTAssertEqual(byKey.first?.statusGroups.first?.issues.map(\.key), ["LM-20"])
        XCTAssertEqual(bySummary.first?.statusGroups.first?.issues.map(\.key), ["LM-10"])
    }

    func testMenuBarTitleAndUrgency() {
        let sections = [
            makeSection(
                id: "a",
                projectKey: "LM",
                boardId: 1,
                pairId: pairA.id,
                daysRemaining: 2,
                issues: [
                    makeIssue(key: "LM-1", statusCategoryKey: "new", priorityName: "High"),
                    makeIssue(key: "LM-2", statusCategoryKey: "done", priorityName: "Low")
                ]
            )
        ]

        XCTAssertEqual(SprintMetrics.menuBarTitle(for: sections), "2d · 1")
        XCTAssertTrue(SprintMetrics.isUrgent(in: sections))
        XCTAssertEqual(SprintMetrics.priorityCounts(in: sections).map(\.bucket), [.high])
        XCTAssertEqual(SprintMetrics.priorityCounts(in: sections).map(\.count), [1])
    }

    func testPriorityBucketFallbacks() {
        XCTAssertEqual(PriorityBucket.bucket(for: "Critical", priorityId: nil), .highest)
        XCTAssertEqual(PriorityBucket.bucket(for: "Unknown", priorityId: "4"), .low)
        XCTAssertEqual(PriorityBucket.bucket(for: "Weird", priorityId: nil), .medium)
    }

    // MARK: - Fixtures

    private func makeIssue(
        key: String,
        summary: String = "Summary",
        statusName: String = "To Do",
        statusCategoryKey: String = "new",
        priorityName: String = "Medium",
        priorityId: String? = "3"
    ) -> JiraIssueDisplay {
        JiraIssueDisplay(
            id: key,
            key: key,
            summary: summary,
            statusName: statusName,
            statusCategoryKey: statusCategoryKey,
            priorityName: priorityName,
            priorityId: priorityId,
            browseURL: URL(string: "https://example.atlassian.net/browse/\(key)")!
        )
    }

    private func makeSection(
        id: String,
        projectKey: String,
        boardId: Int,
        pairId: UUID,
        daysRemaining: Int?,
        issues: [JiraIssueDisplay]
    ) -> SprintSection {
        SprintSection(
            id: id,
            sprintId: 1,
            name: "Sprint",
            endDate: nil,
            progress: 0,
            daysRemaining: daysRemaining,
            projectKey: projectKey,
            boardId: boardId,
            pairId: pairId,
            boardURL: URL(string: "https://example.atlassian.net/board")!,
            sprintURL: URL(string: "https://example.atlassian.net/sprint")!,
            statusGroups: [
                StatusGroup(id: "todo", name: "TO DO", issues: issues)
            ]
        )
    }
}
