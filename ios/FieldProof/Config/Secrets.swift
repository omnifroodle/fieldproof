import Foundation

/// Reads `Secrets.plist` (git-ignored; copy `Secrets.example.plist`). Without it the app still works, offline only.
enum Secrets {

    // MARK: - Values

    /// `wss://<id>.apps.cloud.couchbase.com:4984/fieldproof`, or nil if not configured.
    static var appServicesURL: URL? {
        guard let text = values["APP_SERVICES_URL"], !text.contains("YOUR-ID") else { return nil }
        return URL(string: text)
    }

    static func password(for user: AppUser) -> String? {
        switch user {
        case .crewValley: values["USER_CREW_VALLEY"]
        case .crewTuolumne: values["USER_CREW_TUOLUMNE"]
        case .supervisor: values["USER_SUPERVISOR"]
        }
    }

    // MARK: - Loading

    private static let values: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else { return [:] }
        return plist
    }()
}
