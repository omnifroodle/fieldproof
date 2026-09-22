import XCTest
@testable import FieldProof

/// The bounding box used as the duplicate check's geo prefilter, and the exact distance used for display.
final class GeoBoxTests: XCTestCase {

    private let lat = 37.7460, lon = -119.5860

    func testBoxHalfWidthsMatchTheFormula() {
        let box = GeoBox(lat: lat, lon: lon, radiusMeters: 200)
        XCTAssertEqual(box.maxLat - lat, 200 / 111_320, accuracy: 1e-12)
        XCTAssertEqual(lat - box.minLat, 200 / 111_320, accuracy: 1e-12)
        XCTAssertEqual(box.maxLon - lon, 200 / (111_320 * cos(lat * .pi / 180)), accuracy: 1e-12)
    }

    func testBoxEdgesAreAboutTheRadiusAway() {
        let box = GeoBox(lat: lat, lon: lon, radiusMeters: 200)
        XCTAssertEqual(GeoBox.meters(lat1: lat, lon1: lon, lat2: box.maxLat, lon2: lon), 200, accuracy: 1.5)
        XCTAssertEqual(GeoBox.meters(lat1: lat, lon1: lon, lat2: lat, lon2: box.maxLon), 200, accuracy: 1.5)
    }

    func testCornerIsOutsideTheCircle() {
        // The box is a square around the circle, which is why the query results are filtered by exact distance.
        let box = GeoBox(lat: lat, lon: lon, radiusMeters: 200)
        XCTAssertGreaterThan(GeoBox.meters(lat1: lat, lon1: lon, lat2: box.maxLat, lon2: box.maxLon), 280)
    }

    func testHaversineKnownDistance() {
        // One degree of latitude is about 111.2 km on a 6,371 km sphere.
        XCTAssertEqual(GeoBox.meters(lat1: 0, lon1: 0, lat2: 1, lon2: 0), 111_195, accuracy: 10)
        XCTAssertEqual(GeoBox.meters(lat1: lat, lon1: lon, lat2: lat, lon2: lon), 0, accuracy: 1e-9)
    }
}
