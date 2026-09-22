import CouchbaseLiteSwift
import Foundation

/// Opens the on-device database and makes sure collections and indexes exist.
enum DatabaseManager {

    // MARK: - Names

    static let databaseName = "fieldproof"
    static let scopeName = "evidence"
    static let reportsName = "reports"
    static let photosName = "photos"
    static let vectorIndexName = "idx_reports_embedding"
    static let geoIndexName = "idx_reports_geo"

    // MARK: - Open

    static func open() throws -> Database {
        #if DEBUG
        // Talking point: Couchbase Lite logs what it is doing, so we can show the console live if asked.
        LogSinks.console = ConsoleLogSink(level: .info, domains: .all)
        #endif

        // Talking point: the database is a local file on the phone. No network is needed to open or write it.
        let db = try Database(name: databaseName)

        // Talking point: scopes and collections on the device mirror the ones in Capella: evidence.reports, evidence.photos.
        let reports = try db.createCollection(name: reportsName, scope: scopeName)
        _ = try db.createCollection(name: photosName, scope: scopeName)

        try createIndexes(on: reports)
        return db
    }

    // MARK: - Indexes

    private static func createIndexes(on reports: Collection) throws {
        // Talking point: a vector index on the phone. 768 dimensions from Apple's Vision feature print,
        // cosine distance, 8 centroids (about the square root of the report count), no compression.
        var vector = VectorIndexConfiguration(expression: "embedding", dimensions: 768, centroids: 8)
        vector.metric = .cosine
        vector.encoding = .none
        try reports.createIndex(withName: vectorIndexName, config: vector)

        // Talking point: an ordinary value index serves the status and bounding-box filters in the same query.
        let geo = ValueIndexConfiguration(["type", "status", "location.lat", "location.lon"])
        try reports.createIndex(withName: geoIndexName, config: geo)
    }
}
