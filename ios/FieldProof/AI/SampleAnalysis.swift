import Foundation

/// Vision results for the bundled sample photos, computed on a Mac by `scripts/embed-samples.swift`.
/// Used only on the iOS Simulator, where Vision's models cannot run (REFERENCE.md §7.1). Real iPhones run Vision live.
enum SampleAnalysis {

    // MARK: - Lookup

    struct Entry {
        let labels: [AnalysisResult.Label]
        let embedding: [Float]
    }

    /// Results for these exact bytes, matched by SHA-256, or nil if the photo is not a bundled sample.
    static func entry(forHash hash: String) -> Entry? { table[hash] }

    // MARK: - Loading

    private static let table: [String: Entry] = {
        guard let url = Bundle.main.url(forResource: "analysis", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["items"] as? [String: [String: Any]] else { return [:] }
        return items.mapValues { item in
            let labels = (item["labels"] as? [[String: Any]] ?? []).compactMap { l -> AnalysisResult.Label? in
                guard let name = l["label"] as? String, let c = l["confidence"] as? Double else { return nil }
                return AnalysisResult.Label(label: name, confidence: c)
            }
            let embedding = (item["embedding"] as? [NSNumber] ?? []).map(\.floatValue)
            return Entry(labels: labels, embedding: embedding)
        }
    }()
}
