import Foundation

enum JiraBoardURLParser {
    struct ParsedBoard: Equatable {
        let jiraDomain: String
        let projectKey: String
        let boardId: Int
    }

    /// Parses Jira board URLs such as:
    /// `https://linemanwongnai.atlassian.net/jira/software/c/projects/LM/boards/99`
    static func parse(_ input: String) -> ParsedBoard? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let host = url.host,
              !host.isEmpty else {
            return nil
        }

        let scheme = url.scheme ?? "https"
        let domain = "\(scheme)://\(host)"
        let path = url.path

        guard let projectKey = firstMatch(pattern: #"/(?:c/)?projects/([^/]+)(?:/|$)"#, in: path),
              let boardIdString = firstMatch(pattern: #"/boards/(\d+)(?:/|$)"#, in: path),
              let boardId = Int(boardIdString) else {
            return nil
        }

        return ParsedBoard(
            jiraDomain: domain,
            projectKey: projectKey,
            boardId: boardId
        )
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}
