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
    let embedding: [Float]
}
