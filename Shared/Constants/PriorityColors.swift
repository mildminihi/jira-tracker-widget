import SwiftUI

enum PriorityColors {
    static func color(for priorityName: String, priorityId: String?) -> Color {
        let normalized = priorityName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalized {
        case "highest", "blocker", "critical":
            return .red
        case "high", "major":
            return .orange
        case "medium", "normal":
            return .yellow
        case "low", "minor":
            return .blue
        case "lowest", "trivial":
            return .gray
        default:
            break
        }

        if let priorityId {
            switch priorityId {
            case "1":
                return .red
            case "2":
                return .orange
            case "3":
                return .yellow
            case "4":
                return .blue
            case "5":
                return .gray
            default:
                break
            }
        }

        return .gray
    }
}
