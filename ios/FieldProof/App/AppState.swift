import CouchbaseLiteSwift
import Foundation

/// App-wide state: the database, the live report list, the selected user, and demo mode.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Published

    @Published private(set) var repository: ReportRepository
    @Published private(set) var reports: [Report] = []
    @Published var user: AppUser {
        didSet { UserDefaults.standard.set(user.rawValue, forKey: Keys.user) }
    }
    @Published var demoMode: Bool {
        didSet { UserDefaults.standard.set(demoMode, forKey: Keys.demoMode) }
    }

    // MARK: - Services

    let location = LocationService()
    let deviceId: String

    // MARK: - Init

    init(database: Database) throws {
        let defaults = UserDefaults.standard
        user = AppUser(rawValue: defaults.string(forKey: Keys.user) ?? "") ?? .crewValley
        #if targetEnvironment(simulator)
        demoMode = defaults.object(forKey: Keys.demoMode) as? Bool ?? true   // no camera on the simulator
        #else
        demoMode = defaults.bool(forKey: Keys.demoMode)
        #endif
        if let id = defaults.string(forKey: Keys.deviceId) {
            deviceId = id
        } else {
            deviceId = UUID().uuidString
            defaults.set(deviceId, forKey: Keys.deviceId)
        }
        repository = try ReportRepository(database: database)
        try startFeed()
    }

    // MARK: - Reset

    /// Deletes the on-device database and starts fresh (Settings → Reset local data).
    func resetLocalData() throws {
        try repository.close()
        try Database.delete(withName: DatabaseManager.databaseName)
        repository = try ReportRepository(database: DatabaseManager.open())
        reports = []
        try startFeed()
    }

    // MARK: - Private

    private func startFeed() throws {
        try repository.observeReports { [weak self] list in self?.reports = list }
    }

    private enum Keys {
        static let user = "user"
        static let demoMode = "demoMode"
        static let deviceId = "deviceId"
    }
}
