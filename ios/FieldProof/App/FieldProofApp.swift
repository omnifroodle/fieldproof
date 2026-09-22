import CouchbaseLiteSwift
import SwiftUI

@main
struct FieldProofApp: App {

    // MARK: - State

    @StateObject private var state: AppState

    // MARK: - Init

    init() {
        // Talking point: the vector search extension is loaded once, before the database opens.
        try! Extension.enableVectorSearch()
        let database = try! DatabaseManager.open()
        _state = StateObject(wrappedValue: try! AppState(database: database))
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ReportListView()
                .environmentObject(state)
                .environmentObject(state.sync)
                .preferredColorScheme(.light)
                .tint(Theme.Palette.sienna)
        }
    }
}
