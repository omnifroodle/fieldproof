import SwiftUI

/// Who is using the phone, demo mode, sample data, and reset.
struct SettingsView: View {

    // MARK: - State

    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var sync: SyncManager
    @State private var pendingUser: AppUser?
    @Environment(\.dismiss) private var dismiss
    @State private var seeding: (done: Int, total: Int)?
    @State private var message: String?
    @State private var confirmReset = false
    @State private var showDeveloper = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                HStack {
                    Text("SETTINGS").font(Theme.Typeface.display(38)).foregroundStyle(Theme.Palette.pine)
                    Spacer()
                    Button("Done") { dismiss() }.buttonStyle(PosterButtonStyle(kind: .outline)).fixedSize()
                }

                heading("SIGNED IN AS")
                PosterCard {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        ForEach(AppUser.allCases) { user in
                            Button { if user != state.user { pendingUser = user } } label: {
                                HStack {
                                    Image(systemName: state.user == user ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(Theme.Palette.pine)
                                    VStack(alignment: .leading) {
                                        Text(user.rawValue).font(Theme.Typeface.heading(16)).foregroundStyle(Theme.Palette.charcoal)
                                        Text(user.label).font(Theme.Typeface.body(14)).foregroundStyle(Theme.Palette.pineLight)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        Text("For the demo, pick a user. In production this is your identity provider.")
                            .font(Theme.Typeface.body(13)).foregroundStyle(Theme.Palette.charcoal)
                    }
                }

                heading("SYNC")
                PosterCard {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        Toggle(isOn: $sync.simulatedOffline) {
                            VStack(alignment: .leading) {
                                Text("Simulate offline").font(Theme.Typeface.heading(16))
                                Text("Stops sync, like airplane mode. Capture keeps working.").font(Theme.Typeface.body(13))
                            }
                            .foregroundStyle(Theme.Palette.charcoal)
                        }
                        .tint(Theme.Palette.pine)
                        Text(syncStatus).font(Theme.Typeface.mono(12)).foregroundStyle(Theme.Palette.charcoal)
                    }
                }

                heading("DEMO")
                PosterCard {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        Toggle(isOn: $state.demoMode) {
                            VStack(alignment: .leading) {
                                Text("Demo mode").font(Theme.Typeface.heading(16))
                                Text("Sample photos instead of the camera, and a fixed spot near Yosemite Village.")
                                    .font(Theme.Typeface.body(13))
                            }
                            .foregroundStyle(Theme.Palette.charcoal)
                        }
                        .tint(Theme.Palette.pine)
                        Button(seedTitle) { loadSamples() }
                            .buttonStyle(PosterButtonStyle(kind: .outline))
                            .disabled(seeding != nil)
                    }
                }

                heading("DATA ON THIS PHONE")
                PosterCard {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        Text("\(state.reports.count) reports stored on this device.")
                            .font(Theme.Typeface.body(15)).foregroundStyle(Theme.Palette.charcoal)
                        Button("Reset local data") { confirmReset = true }
                            .buttonStyle(PosterButtonStyle())
                    }
                }

                heading("DEVELOPER")
                PosterCard {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text("Duplicate threshold \(DuplicateCheckQuery.defaultMaxDistance, specifier: "%.2f") (cosine distance), radius 200 m.")
                            .font(Theme.Typeface.body(14)).foregroundStyle(Theme.Palette.charcoal)
                        Button("Last duplicate check") { showDeveloper = true }
                            .buttonStyle(PosterButtonStyle(kind: .outline))
                    }
                }

                if let message {
                    Text(message).font(Theme.Typeface.body(14)).foregroundStyle(Theme.Palette.pine)
                }
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.Palette.paper)
        .sheet(isPresented: $showDeveloper) { DeveloperView() }
        .confirmationDialog(
            "Switch to \(pendingUser?.rawValue ?? "")?", isPresented: Binding(get: { pendingUser != nil }, set: { if !$0 { pendingUser = nil } }),
            titleVisibility: .visible
        ) {
            Button("Switch and reload", role: .destructive) { if let user = pendingUser { switchUser(to: user) } }
        } message: {
            Text("The phone clears its local reports and pulls this user's districts from the server."
                 + (sync.pendingCount > 0 ? " \(sync.pendingCount) unsynced reports will be lost." : ""))
        }
        .confirmationDialog("Delete every report on this phone?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Delete local data", role: .destructive) { reset() }
        } message: {
            Text("Reports that have not synced will be lost.")
        }
    }

    // MARK: - Pieces

    private var seedTitle: String {
        guard let seeding else { return "Load sample reports" }
        return "Loading \(seeding.done) of \(seeding.total)…"
    }

    private var syncStatus: String {
        guard sync.isConfigured else { return "Not configured: add Config/Secrets.plist to sync." }
        let error = sync.lastError.map { "\nerror: \($0)" } ?? ""
        return "replicator: \(String(describing: sync.activity)) · pending reports: \(sync.pendingCount)\(error)"
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(Theme.Typeface.heading(15)).tracking(0.8).foregroundStyle(Theme.Palette.pineLight)
    }

    // MARK: - Actions

    /// Seeds as the supervisor (who can write every district), waits for the push, then hands the phone back.
    /// Without sync configured, seeds stay on this phone.
    private func loadSamples() {
        let online = sync.isConfigured && !sync.simulatedOffline
        if sync.isConfigured && !online {
            message = "Turn off Simulate offline first: samples sync up as the supervisor."
            return
        }
        seeding = (0, 0)
        message = nil
        let original = state.user
        Task {
            do {
                if online && original != .supervisor { try state.switchUser(to: .supervisor, reset: false) }
                let repository = state.repository, deviceId = state.deviceId
                let written = try await Task.detached {
                    try await SeedData.load(into: repository, deviceId: deviceId) { done, total in seeding = (done, total) }
                }.value
                if online {
                    message = "Syncing samples up…"
                    let pushed = await sync.waitUntilPushed()
                    if original != .supervisor {
                        if pushed { try state.switchUser(to: original, reset: true) } else { try state.switchUser(to: original, reset: false) }
                    }
                    message = pushed ? "Loaded \(written) sample reports and synced them." : "Loaded \(written) sample reports; sync has not finished."
                } else {
                    message = "Loaded \(written) sample reports on this phone."
                }
            } catch {
                message = "Sample load failed: \(error.localizedDescription)"
            }
            seeding = nil
        }
    }

    private func switchUser(to user: AppUser) {
        do {
            try state.switchUser(to: user, reset: true)
            message = "Signed in as \(user.rawValue). Pulling that user's reports."
        } catch {
            message = "Switch failed: \(error.localizedDescription)"
        }
    }

    private func reset() {
        do {
            try state.resetLocalData()
            message = "Local data deleted."
        } catch {
            message = "Reset failed: \(error.localizedDescription)"
        }
    }
}
