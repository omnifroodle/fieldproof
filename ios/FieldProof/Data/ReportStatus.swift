import SwiftUI

/// Work status. Only the supervisor dashboard changes it; the phone shows it.
enum ReportStatus: String, CaseIterable, Identifiable, Codable {
    case open
    case inProgress = "in_progress"
    case resolved

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open: "Open"
        case .inProgress: "In progress"
        case .resolved: "Resolved"
        }
    }

    var color: Color {
        switch self {
        case .open: Theme.Palette.sienna
        case .inProgress: Theme.Palette.mustard
        case .resolved: Theme.Palette.pine
        }
    }
}
