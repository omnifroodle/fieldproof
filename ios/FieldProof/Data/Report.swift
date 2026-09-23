import CouchbaseLiteSwift
import Foundation

/// One field report. Stored as a JSON document in `evidence.reports`; the full photo lives in `evidence.photos`.
struct Report: Identifiable, Equatable {

    // MARK: - Types

    struct Location: Equatable {
        var lat: Double
        var lon: Double
        var accuracy: Double
        var altitude: Double
        var heading: Double
    }

    // MARK: - Fields

    var id: String
    var district: String
    var status: ReportStatus = .open
    var category: ReportCategory
    var createdAt: Date
    var createdBy: String
    var deviceId: String
    var location: Location
    var aiLabels: [AnalysisResult.Label] = []
    var ocrText = ""
    var notes = ""
    /// One sentence written on the device by Apple's language model; empty when the model cannot run.
    var summary = ""
    var embedding: [Float] = []
    var imageHash: String
    var thumbnail: Data?
    var relatedReportIds: [String] = []
    var attachedTo: String?
    var seed = false
    /// The bundled file a seed report was made from; used to avoid seeding the same sample twice.
    var seedFile: String?

    var photoDocId: String { Report.photoId(for: id) }

    // MARK: - Ids

    static func newId() -> String { "report::\(UUID().uuidString.lowercased())" }
    static func photoId(for reportId: String) -> String { reportId.replacingOccurrences(of: "report::", with: "photo::") }

    // MARK: - Dates

    /// ISO-8601 UTC with no fractional seconds, e.g. 2026-09-22T17:04:11Z.
    static let timestamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Document mapping

    /// Talking point: a report is plain JSON in Couchbase Lite. The same document syncs to Capella unchanged.
    init?(document: Document) {
        guard document.string(forKey: "type") == "report",
              let category = ReportCategory(rawValue: document.string(forKey: "category") ?? ""),
              let loc = document.dictionary(forKey: "location") else { return nil }
        id = document.id
        district = document.string(forKey: "district") ?? ""
        status = ReportStatus(rawValue: document.string(forKey: "status") ?? "") ?? .open
        self.category = category
        createdAt = Report.timestamp.date(from: document.string(forKey: "createdAt") ?? "") ?? .distantPast
        createdBy = document.string(forKey: "createdBy") ?? ""
        deviceId = document.string(forKey: "deviceId") ?? ""
        location = Location(
            lat: loc.double(forKey: "lat"), lon: loc.double(forKey: "lon"), accuracy: loc.double(forKey: "accuracy"),
            altitude: loc.double(forKey: "altitude"), heading: loc.double(forKey: "heading")
        )
        aiLabels = (document.array(forKey: "aiLabels")?.toArray() as? [[String: Any]] ?? []).compactMap {
            guard let label = $0["label"] as? String else { return nil }
            return AnalysisResult.Label(label: label, confidence: ($0["confidence"] as? NSNumber)?.doubleValue ?? 0)
        }
        ocrText = document.string(forKey: "ocrText") ?? ""
        notes = document.string(forKey: "notes") ?? ""
        summary = document.string(forKey: "summary") ?? ""
        embedding = (document.array(forKey: "embedding")?.toArray() as? [NSNumber] ?? []).map(\.floatValue)
        imageHash = document.string(forKey: "imageHash") ?? ""
        thumbnail = document.blob(forKey: "thumbnail")?.content
        relatedReportIds = document.array(forKey: "relatedReportIds")?.toArray() as? [String] ?? []
        attachedTo = document.string(forKey: "attachedTo")
        seed = document.boolean(forKey: "seed")
        seedFile = document.string(forKey: "seedFile")
    }

    init(
        id: String, district: String, status: ReportStatus = .open, category: ReportCategory, createdAt: Date,
        createdBy: String, deviceId: String, location: Location, notes: String, imageHash: String, thumbnail: Data?
    ) {
        self.id = id
        self.district = district
        self.status = status
        self.category = category
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.deviceId = deviceId
        self.location = location
        self.notes = notes
        self.imageHash = imageHash
        self.thumbnail = thumbnail
    }

    /// Writes every field onto a mutable document (new or existing).
    func apply(to doc: MutableDocument) {
        doc.setString("report", forKey: "type")
        doc.setString(id, forKey: "id")
        doc.setString(district, forKey: "district")
        doc.setString(status.rawValue, forKey: "status")
        doc.setString(category.rawValue, forKey: "category")
        doc.setString(Report.timestamp.string(from: createdAt), forKey: "createdAt")
        doc.setString(createdBy, forKey: "createdBy")
        doc.setString(deviceId, forKey: "deviceId")
        doc.setDictionary(MutableDictionaryObject(data: [
            "lat": location.lat, "lon": location.lon, "accuracy": location.accuracy,
            "altitude": location.altitude, "heading": location.heading,
        ]), forKey: "location")
        doc.setArray(MutableArrayObject(data: aiLabels.map { ["label": $0.label, "confidence": $0.confidence] }), forKey: "aiLabels")
        doc.setString(ocrText, forKey: "ocrText")
        doc.setString(notes, forKey: "notes")
        if summary.isEmpty { doc.removeValue(forKey: "summary") } else { doc.setString(summary, forKey: "summary") }
        // No embedding yet means "not analyzed": leave the key out so the vector index skips the document.
        if embedding.isEmpty {
            doc.removeValue(forKey: "embedding")
            doc.removeValue(forKey: "embeddingModel")
        } else {
            doc.setArray(MutableArrayObject(data: embedding.map { $0 as NSNumber }), forKey: "embedding")
            doc.setString(Embedding.model, forKey: "embeddingModel")
        }
        doc.setString(imageHash, forKey: "imageHash")
        doc.setString(photoDocId, forKey: "photoDocId")
        // Talking point: the thumbnail is a blob inside the report, so it syncs with the report, ahead of the full photo.
        doc.setBlob(thumbnail.map { Blob(contentType: "image/jpeg", data: $0) }, forKey: "thumbnail")
        doc.setArray(MutableArrayObject(data: relatedReportIds), forKey: "relatedReportIds")
        if let attachedTo { doc.setString(attachedTo, forKey: "attachedTo") } else { doc.removeValue(forKey: "attachedTo") }
        doc.setBoolean(seed, forKey: "seed")
        if let seedFile { doc.setString(seedFile, forKey: "seedFile") }
    }
}
