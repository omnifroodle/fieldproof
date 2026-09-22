import SwiftUI

/// Capture flow: camera (or demo sample) → prepare and hash → review metadata → save. No network at any step.
struct CaptureView: View {

    // MARK: - Step

    private enum Step {
        case choose
        case preparing
        case review(PreparedPhoto)
    }

    // MARK: - State

    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.choose
    @State private var capturedAt = Date()
    @State private var pinnedLocation: Report.Location?
    @State private var category = ReportCategory.pothole
    @State private var notes = ""
    @State private var error: String?

    // MARK: - Body

    var body: some View {
        Group {
            switch step {
            case .choose:
                if state.demoMode {
                    SamplePickerView(
                        onPick: { url in prepare { (try? Data(contentsOf: url)).flatMap(PreparedPhoto.from(sampleJPEG:)) } },
                        onCancel: { dismiss() }
                    )
                } else {
                    CameraPicker { image in
                        guard let image else { return dismiss() }
                        prepare { PreparedPhoto.from(image: image) }
                    }
                    .ignoresSafeArea()
                }
            case .preparing:
                VStack(spacing: Theme.Space.m) {
                    ProgressView().tint(Theme.Palette.pine)
                    Text("PREPARING THE PHOTO").font(Theme.Typeface.display(28)).foregroundStyle(Theme.Palette.pine)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Palette.paper)
            case .review(let photo):
                review(photo)
            }
        }
        .onAppear { if !state.demoMode { state.location.start() } }
        .onDisappear { state.location.stop() }
    }

    // MARK: - Review

    private func review(_ photo: PreparedPhoto) -> some View {
        // The position is pinned when the photo is taken; without a fix yet, keep watching for one.
        let location = pinnedLocation ?? state.location.current(demo: false)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                Text("REVIEW THE REPORT").font(Theme.Typeface.display(34)).foregroundStyle(Theme.Palette.pine)
                Image(uiImage: photo.image)
                    .resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.Palette.charcoal, lineWidth: 2))
                PosterCard {
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Text("CAPTURED ON THIS DEVICE").font(Theme.Typeface.heading(15)).foregroundStyle(Theme.Palette.pine)
                        fact("Time", capturedAt.formatted(date: .abbreviated, time: .standard))
                        if let location {
                            fact("GPS", String(format: "%.5f, %.5f  ±%.0f m", location.lat, location.lon, location.accuracy))
                            fact("Heading", String(format: "%.0f°", location.heading))
                        } else {
                            fact("GPS", state.location.denied ? "Location access is off" : "Waiting for a fix…")
                        }
                        fact("SHA-256", EvidenceHash.short(photo.hash), mono: true)
                        fact("Size", ByteCountFormatter.string(fromByteCount: Int64(photo.jpeg.count), countStyle: .file))
                    }
                }
                Text("CATEGORY").font(Theme.Typeface.heading(15)).foregroundStyle(Theme.Palette.pineLight)
                CategoryChips(selection: $category)
                Text("NOTES").font(Theme.Typeface.heading(15)).foregroundStyle(Theme.Palette.pineLight)
                TextField("Where exactly, how big, anything the next crew should know", text: $notes, axis: .vertical)
                    .font(Theme.Typeface.body())
                    .lineLimit(3...6)
                    .padding(Theme.Space.s)
                    .background(Theme.Palette.chalk, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).stroke(Theme.Palette.charcoal, lineWidth: 1.5))
                if let error { Text(error).font(Theme.Typeface.body(14)).foregroundStyle(Theme.Palette.sienna) }
                HStack(spacing: Theme.Space.m) {
                    Button("Cancel") { dismiss() }.buttonStyle(PosterButtonStyle(kind: .outline))
                    Button("File report") { save(photo, at: location) }
                        .buttonStyle(PosterButtonStyle())
                        .disabled(location == nil)
                }
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.Palette.paper)
        .scrollDismissesKeyboard(.interactively)
    }

    private func fact(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased()).font(Theme.Typeface.label(13)).foregroundStyle(Theme.Palette.pineLight).frame(width: 72, alignment: .leading)
            Text(value).font(mono ? Theme.Typeface.mono(14) : Theme.Typeface.body(15)).foregroundStyle(Theme.Palette.charcoal)
        }
    }

    // MARK: - Actions

    /// Resizes, encodes, and hashes off the main thread.
    private func prepare(_ make: @escaping @Sendable () -> PreparedPhoto?) {
        capturedAt = Date()
        pinnedLocation = state.location.current(demo: state.demoMode)
        step = .preparing
        Task {
            let photo = await Task.detached(priority: .userInitiated) { make() }.value
            if let photo { step = .review(photo) } else { error = "That photo could not be read."; step = .choose }
        }
    }

    private func save(_ photo: PreparedPhoto, at location: Report.Location?) {
        guard let location else { return }
        let report = Report(
            id: Report.newId(), district: state.user.district, category: category, createdAt: capturedAt,
            createdBy: state.user.rawValue, deviceId: state.deviceId, location: location,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), imageHash: photo.hash, thumbnail: photo.thumbnail
        )
        do {
            try state.repository.save(report, photo: photo)
            dismiss()
        } catch {
            self.error = "Could not save: \(error.localizedDescription)"
        }
    }
}

/// Category choice as a scrolling row of chips, the same look as the list filters.
private struct CategoryChips: View {
    @Binding var selection: ReportCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.s) {
                ForEach(ReportCategory.allCases) { c in
                    ChoiceChip(title: c.label, selected: selection == c) { selection = c }
                }
            }
        }
    }
}
