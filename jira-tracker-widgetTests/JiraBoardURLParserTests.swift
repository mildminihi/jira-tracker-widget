import XCTest
@testable import Jira_Sprint_Tracker

final class JiraBoardURLParserTests: XCTestCase {

    func testParseStandardBoardURL() {
        let parsed = JiraBoardURLParser.parse(
            "https://linemanwongnai.atlassian.net/jira/software/c/projects/LM/boards/99"
        )

        XCTAssertEqual(
            parsed,
            JiraBoardURLParser.ParsedBoard(
                jiraDomain: "https://linemanwongnai.atlassian.net",
                projectKey: "LM",
                boardId: 99
            )
        )
    }

    func testParseBoardURLWithoutCSegment() {
        let parsed = JiraBoardURLParser.parse(
            "https://example.atlassian.net/jira/software/projects/ABC/boards/12"
        )

        XCTAssertEqual(parsed?.projectKey, "ABC")
        XCTAssertEqual(parsed?.boardId, 12)
        XCTAssertEqual(parsed?.jiraDomain, "https://example.atlassian.net")
    }

    func testParseTrimsWhitespace() {
        let parsed = JiraBoardURLParser.parse(
            "  https://example.atlassian.net/jira/software/c/projects/XYZ/boards/7  "
        )

        XCTAssertEqual(parsed?.projectKey, "XYZ")
        XCTAssertEqual(parsed?.boardId, 7)
    }

    func testParseRejectsInvalidInput() {
        XCTAssertNil(JiraBoardURLParser.parse(""))
        XCTAssertNil(JiraBoardURLParser.parse("not-a-url"))
        XCTAssertNil(JiraBoardURLParser.parse("https://example.atlassian.net/browse/ABC-1"))
        XCTAssertNil(JiraBoardURLParser.parse("https://example.atlassian.net/jira/software/c/projects/LM"))
    }
}
