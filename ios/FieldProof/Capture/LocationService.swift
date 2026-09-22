import CoreLocation
import Foundation

/// GPS position and compass heading, or a simulated position near Yosemite Village in demo mode.
@MainActor
final class LocationService: NSObject, ObservableObject {

    // MARK: - Demo location

    static let demoLat = 37.7460
    static let demoLon = -119.5860
    static let demoHeading = 184.0

    // MARK: - Published

    @Published private(set) var latest: CLLocation?
    @Published private(set) var heading: CLLocationDirection?
    @Published private(set) var denied = false

    // MARK: - Private

    private let manager = CLLocationManager()

    // MARK: - Control

    func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    /// The position to stamp on a report. Demo mode: the demo point plus up to 15 m of jitter. Otherwise the latest fix.
    func current(demo: Bool) -> Report.Location? {
        if demo {
            let meters = { Double.random(in: -15...15) }
            return Report.Location(
                lat: Self.demoLat + meters() / 111_320,
                lon: Self.demoLon + meters() / (111_320 * cos(Self.demoLat * .pi / 180)),
                accuracy: 8, altitude: 1210, heading: Self.demoHeading
            )
        }
        guard let fix = latest else { return nil }
        return Report.Location(
            lat: fix.coordinate.latitude, lon: fix.coordinate.longitude,
            accuracy: fix.horizontalAccuracy, altitude: fix.altitude,
            heading: heading ?? (fix.course >= 0 ? fix.course : 0)
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let fix = locations.last else { return }
        Task { @MainActor in self.latest = fix }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in self.heading = value }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.denied = status == .denied || status == .restricted }
    }
}
