import SwiftUI

/// Who is using the phone, demo mode, sample data, and reset.
struct SettingsView: View {

    // MARK: - State

    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var seeding: (done: Int, total: Int)?
    @State private var message: String?
    @State private var confirmReset = false

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
                            Button { state.user = user } label: {
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

                if let message {
                    Text(message).font(Theme.Typeface.body(14)).foregroundStyle(Theme.Palette.pine)
                }
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.Palette.paper)
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

    private func heading(_ text: String) -> some View {
        Text(text).font(Theme.Typeface.heading(15)).tracking(0.8).foregroundStyle(Theme.Palette.pineLight)
    }

    // MARK: - Actions

    private func loadSamples() {
        seeding = (0, 0)
        message = nil
        let repository = state.repository, deviceId = state.deviceId
        Task {
            do {
                let written = try await Task.detached {
                    try await SeedData.load(into: repository, deviceId: deviceId) { done, total in seeding = (done, total) }
                }.value
                message = "Loaded \(written) sample reports."
            } catch {
                message = "Sample load failed: \(error.localizedDescription)"
            }
            seeding = nil
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
