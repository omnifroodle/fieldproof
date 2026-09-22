import CouchbaseLiteSwift
import Foundation

/// Save, read, and watch reports in the on-device database.
final class ReportRepository {

    // MARK: - Errors

    enum RepositoryError: Error {
        case missingCollection
    }

    // MARK: - State

    let database: Database
    private let reports: Collection
    private let photos: Collection
    private var tokens: [ListenerToken] = []

    // MARK: - Init

    init(database: Database) throws {
        self.database = database
        guard let reports = try database.collection(name: DatabaseManager.reportsName, scope: DatabaseManager.scopeName),
              let photos = try database.collection(name: DatabaseManager.photosName, scope: DatabaseManager.scopeName) else {
            throw RepositoryError.missingCollection
        }
        self.reports = reports
        self.photos = photos
    }

    // MARK: - Write

    /// Saves the report and its full-resolution photo as two documents in one batch.
    func save(_ report: Report, photo: PreparedPhoto) throws {
        // Talking point: Couchbase Lite stores the full report locally, so this save succeeds with no network.
        try database.inBatch {
            let reportDoc = try reports.document(id: report.id)?.toMutable() ?? MutableDocument(id: report.id)
            report.apply(to: reportDoc)
            try reports.save(document: reportDoc)

            // Talking point: the full photo is a separate document, so small reports and thumbnails sync first.
            let photoDoc = try photos.document(id: report.photoDocId)?.toMutable() ?? MutableDocument(id: report.photoDocId)
            photoDoc.setString("photo", forKey: "type")
            photoDoc.setString(report.photoDocId, forKey: "id")
            photoDoc.setString(report.id, forKey: "reportId")
            photoDoc.setString(report.district, forKey: "district")
            photoDoc.setString(Report.timestamp.string(from: report.createdAt), forKey: "createdAt")
            photoDoc.setString(photo.hash, forKey: "imageHash")
            photoDoc.setInt(photo.jpeg.count, forKey: "byteLength")
            photoDoc.setBlob(Blob(contentType: "image/jpeg", data: photo.jpeg), forKey: "photo")
            try photos.save(document: photoDoc)
        }
    }

    // MARK: - Read

    func report(id: String) throws -> Report? {
        try reports.document(id: id).flatMap(Report.init(document:))
    }

    /// The stored photo bytes (the blob in the photo document), or nil if it has not arrived yet.
    func photoData(for report: Report) throws -> Data? {
        try photos.document(id: report.photoDocId)?.blob(forKey: "photo")?.content
    }

    /// True when the report exists and already has an embedding (used by the seeder).
    func hasAnalyzedReport(id: String) throws -> Bool {
        guard let doc = try reports.document(id: id) else { return false }
        return doc.array(forKey: "embedding") != nil
    }

    // MARK: - Live list

    /// Calls `onChange` with every report, newest first, now and whenever the collection changes.
    func observeReports(_ onChange: @escaping ([Report]) -> Void) throws {
        // Talking point: a live query. When a save or a sync changes the results, Couchbase Lite re-runs it and calls us.
        let query = try database.createQuery(
            "SELECT META().id AS id FROM evidence.reports WHERE type = 'report' ORDER BY createdAt DESC"
        )
        let token = query.addChangeListener { [weak self] change in
            guard let self, let results = change.results else { return }
            let list = results.compactMap { row in
                row.string(forKey: "id").flatMap { try? self.report(id: $0) }
            }
            DispatchQueue.main.async { onChange(list) }
        }
        tokens.append(token)
    }

    // MARK: - Close

    /// Stops live queries and closes the database (before a reset deletes it).
    func close() throws {
        tokens.forEach { $0.remove() }
        tokens.removeAll()
        try database.close()
    }
}
