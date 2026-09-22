import CouchbaseLiteSwift
import XCTest
@testable import FieldProof

/// A report written to a Couchbase Lite document and read back is unchanged.
final class ReportMappingTests: XCTestCase {

    private func sample() -> Report {
        var report = Report(
            id: "report::test-1", district: "valley", status: .inProgress, category: .graffiti,
            createdAt: Date(timeIntervalSince1970: 1_790_000_000), createdBy: "crew-valley", deviceId: "device-1",
            location: .init(lat: 37.7461, lon: -119.5863, accuracy: 5, altitude: 1210, heading: 184),
            notes: "Tag on the shelter awning.", imageHash: String(repeating: "ab", count: 32), thumbnail: Data([0xFF, 0xD8, 0xFF, 0xD9])
        )
        report.aiLabels = [.init(label: "graffiti", confidence: 0.81), .init(label: "wall", confidence: 0.44)]
        report.ocrText = "NPS-4471"
        report.embedding = [0.25, -0.5, 0.125]
        report.relatedReportIds = ["report::other"]
        report.attachedTo = "report::parent"
        report.seed = true
        return report
    }

    func testRoundTrip() throws {
        let report = sample()
        let doc = MutableDocument(id: report.id)
        report.apply(to: doc)
        let back = try XCTUnwrap(Report(document: doc))
        XCTAssertEqual(back, report)
        XCTAssertEqual(doc.string(forKey: "createdAt"), "2026-09-21T14:13:20Z")
        XCTAssertEqual(doc.string(forKey: "photoDocId"), "photo::test-1")
        XCTAssertEqual(doc.string(forKey: "embeddingModel"), Embedding.model)
    }

    func testNoEmbeddingLeavesTheKeyOut() {
        var report = sample()
        report.embedding = []
        report.attachedTo = nil
        let doc = MutableDocument(id: report.id)
        report.apply(to: doc)
        XCTAssertFalse(doc.contains(key: "embedding"), "the vector index should skip reports that are not analyzed")
        XCTAssertFalse(doc.contains(key: "attachedTo"))
    }

    func testOtherDocumentTypesAreIgnored() {
        let doc = MutableDocument(id: "photo::x")
        doc.setString("photo", forKey: "type")
        XCTAssertNil(Report(document: doc))
    }
}
