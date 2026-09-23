import FoundationModels
import Foundation
import OSLog

/// A one-line title for a report, written on the phone by Apple's small language model (iOS 26+).
/// Talking point: a third on-device model. The report's own facts go in, one sentence comes out,
/// and nothing about the photograph leaves the device.
enum ReportSummary {

    // MARK: - Availability

    /// Nil when the model can run; otherwise the reason, in words the demo can put on screen.
    static var unavailableReason: String? {
        #if targetEnvironment(simulator)
        // Measured 2026-09-22: the simulator reports the model as available and then fails to generate,
        // because its safety assets are not installed (SensitiveContentAnalysisML 15 / ModelManager 1001).
        return "Not on the simulator; runs on an Apple Intelligence device"
        #else
        guard #available(iOS 26, *) else { return "Needs iOS 26 or newer" }
        switch SystemLanguageModel.default.availability {
        case .available: return nil
        case .unavailable(let reason): return words(for: reason)
        }
        #endif
    }

    static var isAvailable: Bool { unavailableReason == nil }

    @available(iOS 26, *)
    private static func words(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible: return "This device has no Apple Intelligence"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence is switched off"
        case .modelNotReady: return "The model is still downloading"
        @unknown default: return "The model is unavailable"
        }
    }

    // MARK: - Write

    private static let log = Logger(subsystem: "com.couchbase.demo.fieldproof", category: "ReportSummary")

    private static let instructions = """
        You write the one-line title of a field maintenance report for a work crew.
        One sentence, at most 14 words, plain and factual. Name the problem and where it is.
        No opening phrase, no adjectives, no invented detail: use only the facts given.
        """

    /// Returns nil if the model cannot run or refuses; the report is filed either way.
    static func write(category: ReportCategory, labels: [AnalysisResult.Label], ocrText: String, notes: String) async -> String? {
        guard #available(iOS 26, *), isAvailable else { return nil }
        let facts = [
            "Category: \(category.label)",
            labels.isEmpty ? nil : "Image labels: \(labels.map(\.label).joined(separator: ", "))",
            ocrText.isEmpty ? nil : "Text in the photo: \(ocrText)",
            notes.isEmpty ? nil : "Crew note: \(notes)",
        ].compactMap { $0 }.joined(separator: "\n")

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: facts,
                options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 40)
            )
            let line = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return line.isEmpty ? nil : line
        } catch {
            log.error("summary failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
