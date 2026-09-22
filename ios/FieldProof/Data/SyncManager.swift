import CouchbaseLiteSwift
import Foundation

/// Runs the Couchbase Lite replicator to Capella App Services and publishes what it is doing.
@MainActor
final class SyncManager: ObservableObject {

    // MARK: - Published

    @Published private(set) var activity: Replicator.ActivityLevel = .stopped
    @Published private(set) var pendingCount = 0
    @Published private(set) var lastError: String?
    /// "Simulate offline": the simulator has no airplane mode, so this stops the replicator.
    @Published var simulatedOffline = UserDefaults.standard.bool(forKey: "simulatedOffline") {
        didSet {
            UserDefaults.standard.set(simulatedOffline, forKey: "simulatedOffline")
            simulatedOffline ? replicator?.stop() : replicator?.start()
            refreshPending()
        }
    }

    /// False when Secrets.plist is missing: the app then works fully offline and never syncs.
    var isConfigured: Bool { Secrets.appServicesURL != nil }

    // MARK: - Private

    private var replicator: Replicator?
    private var repository: ReportRepository?
    private var tokens: [ListenerToken] = []

    // MARK: - Start and stop

    /// Builds a replicator for this database and user, and starts it unless offline is simulated.
    func start(repository: ReportRepository, user: AppUser) {
        stop()
        self.repository = repository
        guard let url = Secrets.appServicesURL, let password = Secrets.password(for: user) else { return }

        // Talking point: one replicator syncs both collections. The user's channels decide what it pulls:
        // a crew phone only ever receives its own district.
        var config = ReplicatorConfiguration(
            collections: [CollectionConfiguration(collection: repository.reports), CollectionConfiguration(collection: repository.photos)],
            target: URLEndpoint(url: url)
        )
        config.replicatorType = .pushAndPull
        config.continuous = true
        config.authenticator = BasicAuthenticator(username: user.rawValue, password: password)
        let replicator = Replicator(config: config)

        // Talking point: the app shows exactly what the replicator is doing: offline, busy, idle.
        tokens.append(replicator.addChangeListener(withQueue: .main) { [weak self] change in
            MainActor.assumeIsolated {
                self?.activity = change.status.activity
                self?.lastError = change.status.error?.localizedDescription
                self?.refreshPending()
            }
        })
        // Saves made while offline change the pending count too, so watch the local collection as well.
        tokens.append(repository.reports.addChangeListener(queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPending() }
        })
        self.replicator = replicator
        if !simulatedOffline { replicator.start() }
        refreshPending()
    }

    func stop() {
        replicator?.stop()
        tokens.forEach { $0.remove() }
        tokens.removeAll()
        replicator = nil
        activity = .stopped
    }

    // MARK: - Pending

    /// Talking point: Couchbase Lite knows which local changes have not reached the server yet.
    private func refreshPending() {
        guard let replicator, let repository else { pendingCount = 0; return }
        pendingCount = (try? replicator.pendingDocumentIds(collection: repository.reports).count) ?? 0
    }

    /// Waits until reports and photos are all pushed and the replicator is idle (used before a user switch).
    func waitUntilPushed(timeout: TimeInterval = 120) async -> Bool {
        guard let replicator, let repository else { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let reports = (try? replicator.pendingDocumentIds(collection: repository.reports).count) ?? 1
            let photos = (try? replicator.pendingDocumentIds(collection: repository.photos).count) ?? 1
            if reports + photos == 0, replicator.status.activity == .idle { return true }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return false
    }
}
