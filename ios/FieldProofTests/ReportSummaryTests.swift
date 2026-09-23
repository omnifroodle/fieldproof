import XCTest
@testable import FieldProof

/// The on-device language model. Skipped where it cannot run (the simulator has no model assets),
/// so this test is the way to check Apple Intelligence on a real device:
/// `xcodebuild test -destination 'platform=iOS,name=<your phone>'`.
final class ReportSummaryTests: XCTestCase {

    func testWritesOneShortSentence() async throws {
        if let reason = ReportSummary.unavailableReason { throw XCTSkip(reason) }

        let summary = await ReportSummary.write(
            category: .tree,
            labels: [AnalysisResult.Label(label: "tree", confidence: 0.6)],
            ocrText: "ROAD\nCLOSED",
            notes: "Barriers across the bridge approach, tree across the far lane."
        )

        let line = try XCTUnwrap(summary, "the model was available but wrote nothing")
        XCTAssertFalse(line.isEmpty)
        XCTAssertLessThanOrEqual(line.split(separator: " ").count, 20, "asked for one short sentence: \(line)")
        XCTAssertFalse(line.contains("\n"), "one line only: \(line)")
    }
}
