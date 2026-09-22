import Foundation

/// A latitude/longitude box around a point, plus exact great-circle distance for display.
struct GeoBox: Equatable {

    // MARK: - Fields

    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double

    // MARK: - Init

    /// About 111,320 m per degree of latitude; a degree of longitude shrinks with cos(latitude).
    init(lat: Double, lon: Double, radiusMeters: Double) {
        let dLat = radiusMeters / 111_320
        let dLon = radiusMeters / (111_320 * cos(lat * .pi / 180))
        minLat = lat - dLat
        maxLat = lat + dLat
        minLon = lon - dLon
        maxLon = lon + dLon
    }

    // MARK: - Distance

    /// Haversine distance in meters.
    static func meters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }
}
