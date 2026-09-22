import Foundation

/// What the crew member says the problem is. AI labels are supporting evidence; the person picks the category.
enum ReportCategory: String, CaseIterable, Identifiable, Codable {
    case pothole
    case graffiti
    case tree
    case fixture
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pothole: "Pothole"
        case .graffiti: "Graffiti"
        case .tree: "Downed tree"
        case .fixture: "Broken fixture"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .pothole: "road.lanes"
        case .graffiti: "paintbrush"
        case .tree: "tree"
        case .fixture: "lightbulb"
        case .other: "questionmark.circle"
        }
    }
}
