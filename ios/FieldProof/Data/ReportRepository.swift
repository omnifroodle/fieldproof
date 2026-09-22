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
    let reports: Collection
    let photos: Collection
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

            // Attached capture: the parent report lists it, so the dashboard can show "+1 attached capture".
            if let parentId = report.attachedTo, let parent = try reports.document(id: parentId)?.toMutable() {
                let related = parent.array(forKey: "relatedReportIds") ?? MutableArrayObject()
                if !(related.toArray() as? [String] ?? []).contains(report.id) { related.addString(report.id) }
                parent.setArray(related, forKey: "relatedReportIds")
                try reports.save(document: parent)
            }
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

    /// True when a report made from this bundled sample file is already on the phone (used by the seeder).
    func hasSeed(file: String) throws -> Bool {
        let query = try database.createQuery("SELECT META().id FROM evidence.reports WHERE seedFile = $file LIMIT 1")
        let params = Parameters()
        params.setString(file, forName: "file")
        query.parameters = params
        return try query.execute().next() != nil
    }

    // MARK: - Similar reports

    /// Runs the duplicate check query, then loads each hit for its thumbnail and the exact distance to show.
    func similar(
        to embedding: [Float], lat: Double, lon: Double, radiusMeters: Double = 200,
        maxDistance: Double = DuplicateCheckQuery.defaultMaxDistance, excludeId: String? = nil, includeResolved: Bool = false
    ) throws -> [SimilarReport] {
        guard !embedding.isEmpty else { return [] }
        let hits = try DuplicateCheckQuery.run(
            in: database, embedding: embedding, lat: lat, lon: lon, radiusMeters: radiusMeters,
            maxDistance: maxDistance, excludeId: excludeId, includeResolved: includeResolved
        )
        return try hits.compactMap { hit in
            guard let report = try report(id: hit.id) else { return nil }
            return SimilarReport(report: report, distance: Embedding.cosineDistance(embedding, report.embedding), meters: hit.meters)
        }
    }

    /// Every analyzed report with its exact distance to `embedding` (Developer screen, for tuning the threshold).
    func allDistances(to embedding: [Float], lat: Double, lon: Double) throws -> [SimilarReport] {
        let query = try database.createQuery("SELECT META().id AS id FROM evidence.reports WHERE type = 'report' AND embedding IS VALUED")
        return try query.execute().compactMap { row in
            guard let id = row.string(forKey: "id"), let report = try report(id: id) else { return nil }
            let meters = GeoBox.meters(lat1: lat, lon1: lon, lat2: report.location.lat, lon2: report.location.lon)
            return SimilarReport(report: report, distance: Embedding.cosineDistance(embedding, report.embedding), meters: meters)
        }
        .sorted { $0.distance < $1.distance }
    }

    // MARK: - Live list

    /// Calls `onChange` with every report, newest first, now and whenever the collection changes.
    func observeReports(_ onChange: @escaping ([Report]) -> Void) throws {
        let query = try database.createQuery(
            "SELECT META().id AS id FROM evidence.reports WHERE type = 'report' ORDER BY createdAt DESC"
        )
        let reload = { [weak self] in
            guard let self, let rows = try? query.execute() else { return }
            let list = rows.compactMap { row in row.string(forKey: "id").flatMap { try? self.report(id: $0) } }
            onChange(list)
        }
        // Talking point: Couchbase Lite tells the app whenever the collection changes, from a local save or from
        // a sync, so the list updates by itself when the supervisor changes a status on the dashboard.
        tokens.append(reports.addChangeListener(queue: .main) { _ in reload() })
        reload()
    }

    // MARK: - Close

    /// Stops live queries and closes the database (before a reset deletes it).
    func close() throws {
        tokens.forEach { $0.remove() }
        tokens.removeAll()
        try database.close()
    }
}
