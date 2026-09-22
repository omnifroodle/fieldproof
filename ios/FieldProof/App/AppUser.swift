import Foundation

/// The three App Services users. The phone picks one in Settings; there is no login screen (docs/DEFECTS.md D2).
enum AppUser: String, CaseIterable, Identifiable {
    case crewValley = "crew-valley"
    case crewTuolumne = "crew-tuolumne"
    case supervisor

    var id: String { rawValue }

    /// District a new report is filed under. The supervisor files in the Valley district.
    var district: String {
        switch self {
        case .crewValley, .supervisor: "valley"
        case .crewTuolumne: "tuolumne"
        }
    }

    var label: String {
        switch self {
        case .crewValley: "Crew · Valley district"
        case .crewTuolumne: "Crew · Tuolumne district"
        case .supervisor: "Supervisor · all districts"
        }
    }

    var headerLine: String {
        switch self {
        case .crewValley: "VALLEY DISTRICT · FIELD REPORTS"
        case .crewTuolumne: "TUOLUMNE DISTRICT · FIELD REPORTS"
        case .supervisor: "ALL DISTRICTS · FIELD REPORTS"
        }
    }
}
