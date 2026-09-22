import Foundation

/// What the on-device Vision pass learned about one photo.
struct AnalysisResult {

    // MARK: - Types

    struct Label: Equatable {
        let label: String
        let confidence: Double
    }

    // MARK: - Fields

    let labels: [Label]
    let ocrText: String
    /// 768 floats, or empty if no embedding could be made (then the duplicate check is skipped).
    let embedding: [Float]
    /// True on the simulator: labels and embedding came from the Mac precompute, not a live model run.
    let precomputed: Bool
}
