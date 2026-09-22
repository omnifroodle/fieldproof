import CouchbaseLiteSwift
import Foundation

/// The duplicate check: "does this photo look like an open report near here?"
/// One SQL++ query on the phone combines vector search, a geo box, and status. No network involved.
enum DuplicateCheckQuery {

    // MARK: - Result

    struct Candidate {
        let id: String
        let category: String
        let status: String
        let createdAt: String
        let notes: String
        let lat: Double
        let lon: Double
        let vectorDistance: Double   // 1 - cosine similarity (0 = identical)
        let meters: Double           // exact distance from the capture point
    }

    // MARK: - Tuning

    /// Cosine distance below which two photos count as "the same problem". Tuned in Phase 2 on the sample set:
    /// near-duplicates score 0.01–0.10, different subjects 0.12 and up (docs/REFERENCE.md §7.2).
    static let defaultMaxDistance = 0.15

    // MARK: - SQL++

    private static let sql = """
        SELECT META().id AS id,
               category, status, createdAt, notes,
               location.lat AS lat, location.lon AS lon,
               APPROX_VECTOR_DISTANCE(embedding, $queryVector, 'COSINE') AS distance
        FROM evidence.reports
        WHERE type = 'report'
          AND (status != 'resolved' OR $includeResolved)
          AND attachedTo IS MISSING
          AND location.lat BETWEEN $minLat AND $maxLat
          AND location.lon BETWEEN $minLon AND $maxLon
          AND META().id != $excludeId
          AND APPROX_VECTOR_DISTANCE(embedding, $queryVector, 'COSINE') < $maxDistance
        ORDER BY APPROX_VECTOR_DISTANCE(embedding, $queryVector, 'COSINE')
        LIMIT $maxResults
        """
    // SELECT:  what the review sheet shows, plus the vector distance for each candidate.
    // FROM:    the reports collection in the evidence scope, the same keyspace as in Capella.
    // type:    only report documents.
    // status:  resolved work is not a duplicate candidate ("Find similar" sets $includeResolved).
    // attachedTo IS MISSING: captures already attached to a report are not parents themselves.
    // BETWEEN: a cheap geo box (~200 m) using the value index, applied alongside the vector search.
    // META().id != $excludeId: "Find similar" leaves out the report you are looking at.
    // APPROX_VECTOR_DISTANCE < $maxDistance: the vector index finds photos that look alike.
    //          'COSINE' must match the index metric (4.1.2 does not infer it).
    // ORDER BY: most similar first. LIMIT: a short list a person can review.

    // MARK: - Run

    static func run(
        in db: Database,
        embedding: [Float],
        lat: Double,
        lon: Double,
        radiusMeters: Double = 200,
        maxDistance: Double = defaultMaxDistance,
        excludeId: String? = nil,
        includeResolved: Bool = false,
        limit: Int = 5
    ) throws -> [Candidate] {
        let box = GeoBox(lat: lat, lon: lon, radiusMeters: radiusMeters)

        // Talking point: the query is compiled once by Couchbase Lite and run against the local database.
        let query = try db.createQuery(sql)

        // Talking point: named parameters keep the SQL++ readable; the photo's embedding is bound as an array.
        let params = Parameters()
        params.setArray(MutableArrayObject(data: embedding.map { $0 as NSNumber }), forName: "queryVector")
        params.setBoolean(includeResolved, forName: "includeResolved")
        params.setDouble(box.minLat, forName: "minLat")
        params.setDouble(box.maxLat, forName: "maxLat")
        params.setDouble(box.minLon, forName: "minLon")
        params.setDouble(box.maxLon, forName: "maxLon")
        params.setString(excludeId ?? "", forName: "excludeId")
        params.setDouble(maxDistance, forName: "maxDistance")
        params.setInt(limit, forName: "maxResults")
        query.parameters = params

        // The box is a square around a circle; keep only candidates inside the true radius.
        return try query.execute().compactMap { row -> Candidate? in
            let rowLat = row.double(forKey: "lat"), rowLon = row.double(forKey: "lon")
            let meters = GeoBox.meters(lat1: lat, lon1: lon, lat2: rowLat, lon2: rowLon)
            guard meters <= radiusMeters, let id = row.string(forKey: "id") else { return nil }
            return Candidate(
                id: id,
                category: row.string(forKey: "category") ?? "",
                status: row.string(forKey: "status") ?? "",
                createdAt: row.string(forKey: "createdAt") ?? "",
                notes: row.string(forKey: "notes") ?? "",
                lat: rowLat,
                lon: rowLon,
                vectorDistance: row.double(forKey: "distance"),
                meters: meters
            )
        }
    }
}
