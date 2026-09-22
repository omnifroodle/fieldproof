import Foundation

/// Builds the sample reports from the bundled photos and `manifest.json`, through the same save path as a capture.
enum SeedData {

    // MARK: - Manifest

    struct Entry: Decodable {
        let file: String
        let category: ReportCategory
        let district: String
        let status: ReportStatus
        let lat: Double
        let lon: Double
        let heading: Double
        let notes: String
        let createdDaysAgo: Int
        let createdBy: String
    }

    static func entries() throws -> [Entry] {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json") else { return [] }
        return try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
    }

    // MARK: - Load

    /// Creates each seed report unless it already exists with an embedding. Returns how many were written.
    /// Each photo goes through the same on-device analysis as a capture (precomputed on the simulator).
    /// Ids are deterministic (`report::seed-pothole-01`), so running it twice does not duplicate anything.
    static func load(into repository: ReportRepository, deviceId: String, progress: @escaping @MainActor (Int, Int) -> Void) async throws -> Int {
        let list = try entries()
        var written = 0
        for (index, entry) in list.enumerated() {
            await progress(index, list.count)
            let base = (entry.file as NSString).deletingPathExtension
            let id = "report::seed-\(base)"
            if try repository.hasAnalyzedReport(id: id) { continue }
            guard let url = Bundle.main.url(forResource: base, withExtension: "jpg"),
                  let photo = PreparedPhoto.from(sampleJPEG: try Data(contentsOf: url)) else { continue }

            // Spread creation times through the day so the list does not look machine-made.
            let hours = Double(base.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 9 + 7)
            let createdAt = Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(-entry.createdDaysAgo) * 86_400 + hours * 3_600)
            var report = Report(
                id: id, district: entry.district, status: entry.status, category: entry.category,
                createdAt: min(createdAt, Date()), createdBy: entry.createdBy, deviceId: deviceId,
                location: Report.Location(lat: entry.lat, lon: entry.lon, accuracy: 5,
                                          altitude: entry.district == "tuolumne" ? 2620 : 1210, heading: entry.heading),
                notes: entry.notes, imageHash: photo.hash, thumbnail: photo.thumbnail
            )
            let analysis = try await ImageAnalyzer.analyze(jpeg: photo.jpeg, hash: photo.hash)
            report.aiLabels = analysis.labels
            report.ocrText = analysis.ocrText
            report.embedding = analysis.embedding
            report.seed = true
            try repository.save(report, photo: photo)
            written += 1
        }
        await progress(list.count, list.count)
        return written
    }
}
