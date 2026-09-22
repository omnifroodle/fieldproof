import Foundation

/// Helpers for the 768-float image embeddings produced by Vision feature prints.
enum Embedding {

    // MARK: - Model

    /// Stored on each report so a future model change can coexist with old vectors.
    static let model = "vision-featureprint-r2"
    static let dimensions = 768

    // MARK: - Math

    static func normalized(_ v: [Float]) -> [Float] {
        let norm = sqrt(v.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return v }
        return v.map { $0 / norm }
    }

    /// Exact cosine distance (0 = identical). The vector index does the approximate search; this is for display.
    static func cosineDistance(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 1 }
        let na = normalized(a), nb = normalized(b)
        var dot: Float = 0
        for i in 0..<na.count { dot += na[i] * nb[i] }
        return Double(1 - dot)
    }
}
