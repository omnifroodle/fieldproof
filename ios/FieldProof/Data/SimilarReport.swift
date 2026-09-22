import Foundation

/// A duplicate-check or "Find similar" hit: the report, how alike the photos are, and how far away it is.
struct SimilarReport: Identifiable {

    // MARK: - Fields

    let report: Report
    /// Exact cosine distance between the two embeddings (0 = identical).
    let distance: Double
    let meters: Double

    var id: String { report.id }

    /// Shown as a big number: 1 − distance, as a whole percent.
    var similarityPercent: Int { Int((max(0, 1 - distance) * 100).rounded()) }
}
