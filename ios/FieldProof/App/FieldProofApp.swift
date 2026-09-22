import CouchbaseLiteSwift
import SwiftUI

@main
struct FieldProofApp: App {

    // MARK: - State

    private let database: Database

    // MARK: - Init

    init() {
        // Talking point: the vector search extension is loaded once, before the database opens.
        try! Extension.enableVectorSearch()
        database = try! DatabaseManager.open()
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            SpikeView(database: database)
                .preferredColorScheme(.light)
        }
    }
}
