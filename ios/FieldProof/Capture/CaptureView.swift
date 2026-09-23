import SwiftUI

/// Capture flow: camera (or demo sample) → prepare and hash → on-device AI → duplicate check → review → save.
/// No network at any step.
struct CaptureView: View {

    // MARK: - Step

    private enum Step {
        case choose
        case preparing
        case analyzing(PreparedPhoto, done: Set<ImageAnalyzer.Stage>)
        case review(PreparedPhoto, AnalysisResult)
    }

    // MARK: - State

    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.choose
    @State private var capturedAt = Date()
    @State private var pinnedLocation: Report.Location?
    @State private var category = ReportCategory.pothole
    @State private var notes = ""
    @State private var duplicates: [SimilarReport] = []
    @State private var showDuplicates = false
    @State private var attachTo: Report?
    @State private var error: String?
    @State private var summary: String?
    @State private var summarizing = false
    @StateObject private var voice = VoiceNotes()

    private let radiusMeters = 200.0

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
                ProgressView().tint(Theme.Palette.pine)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Palette.paper)
            case .analyzing(let photo, let done):
                ReadingSceneView(image: photo.image, done: done)
            case .review(let photo, let analysis):
                review(photo, analysis)
            }
        }
        .onAppear { if !state.demoMode { state.location.start() } }
        .onDisappear { state.location.stop() }
        .sheet(isPresented: $showDuplicates, onDismiss: {
            // Save after the sheet has closed, so the capture screen can close cleanly too.
            if let parent = attachTo, case .review(let photo, let analysis) = step { save(photo, analysis, attachTo: parent) }
        }) {
            DuplicateReviewView(
                candidates: duplicates, radiusMeters: Int(radiusMeters),
                onAttach: { parent in attachTo = parent.report; showDuplicates = false },
                onFileNew: { showDuplicates = false }
            )
        }
    }

    // MARK: - Review

    private func review(_ photo: PreparedPhoto, _ analysis: AnalysisResult) -> some View {
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
                aiCard(analysis)
                Text("CATEGORY").font(Theme.Typeface.heading(15)).foregroundStyle(Theme.Palette.pineLight)
                CategoryChips(selection: $category)
                Text("NOTES").font(Theme.Typeface.heading(15)).foregroundStyle(Theme.Palette.pineLight)
                TextField("Where exactly, how big, anything the next crew should know", text: $notes, axis: .vertical)
                    .font(Theme.Typeface.body())
                    .lineLimit(3...6)
                    .padding(Theme.Space.s)
                    .background(Theme.Palette.chalk, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).stroke(Theme.Palette.charcoal, lineWidth: 1.5))
                HStack(spacing: Theme.Space.m) {
                    Button(voice.isRecording ? "Stop dictating" : "Dictate the note") { voice.toggle() }
                        .buttonStyle(PosterButtonStyle(kind: .outline))
                        .fixedSize()
                    if voice.isRecording {
                        Text("LISTENING · ON THIS DEVICE").font(Theme.Typeface.label(13)).foregroundStyle(Theme.Palette.sienna)
                    }
                }
                if let trouble = voice.trouble {
                    Text(trouble).font(Theme.Typeface.body(13)).foregroundStyle(Theme.Palette.pineLight)
                }
                if voice.isRecording, !voice.heard.isEmpty {
                    Text(voice.heard).font(Theme.Typeface.body(14)).foregroundStyle(Theme.Palette.pineLight)
                }
                if let error { Text(error).font(Theme.Typeface.body(14)).foregroundStyle(Theme.Palette.sienna) }
                if !duplicates.isEmpty {
                    Button("Review \(duplicates.count) similar report\(duplicates.count == 1 ? "" : "s")") { showDuplicates = true }
                        .buttonStyle(PosterButtonStyle(kind: .outline))
                }
                HStack(spacing: Theme.Space.m) {
                    Button("Cancel") { dismiss() }.buttonStyle(PosterButtonStyle(kind: .outline))
                    Button("File report") { save(photo, analysis) }
                        .buttonStyle(PosterButtonStyle())
                        .disabled(location == nil)
                }
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.Palette.paper)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: voice.isRecording) { _, recording in
            guard !recording, !voice.heard.isEmpty else { return }
            notes = notes.isEmpty ? voice.heard : notes + " " + voice.heard
        }
        .onDisappear { voice.stop() }
    }

    private func aiCard(_ analysis: AnalysisResult) -> some View {
        PosterCard {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("ON-DEVICE AI").font(Theme.Typeface.heading(15)).foregroundStyle(Theme.Palette.pine)
                fact("Labels", analysis.labels.isEmpty ? "None above 10%" :
                        analysis.labels.map { "\($0.label) \(Int($0.confidence * 100))%" }.joined(separator: " · "))
                fact("Text", analysis.ocrText.isEmpty ? "None found" : analysis.ocrText.replacingOccurrences(of: "\n", with: " / "))
                fact("Vector", analysis.embedding.isEmpty ? "Not available" : "\(analysis.embedding.count) floats")
                fact("Nearby", duplicates.isEmpty ? "No similar open reports" : "\(duplicates.count) similar open report\(duplicates.count == 1 ? "" : "s")")
                fact("Summary", ReportSummary.unavailableReason ?? (summarizing ? "Writing…" : (summary ?? "—")))
                if ReportSummary.isAvailable, !notes.isEmpty, !summarizing {
                    Button("Rewrite with my note") { makeSummary(analysis) }
                        .font(Theme.Typeface.label(13)).foregroundStyle(Theme.Palette.pineLight)
                }
                if analysis.precomputed {
                    Text("Simulator: labels and vector were computed on a Mac with the same Vision model.")
                        .font(Theme.Typeface.body(12)).foregroundStyle(Theme.Palette.pineLight)
                }
            }
        }
    }

    private func fact(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased()).font(Theme.Typeface.label(13)).foregroundStyle(Theme.Palette.pineLight).frame(width: 72, alignment: .leading)
            Text(value).font(mono ? Theme.Typeface.mono(14) : Theme.Typeface.body(15)).foregroundStyle(Theme.Palette.charcoal)
        }
    }

    // MARK: - Actions

    /// Resizes, encodes, and hashes off the main thread, then runs the on-device AI and the duplicate check.
    private func prepare(_ make: @escaping @Sendable () -> PreparedPhoto?) {
        capturedAt = Date()
        pinnedLocation = state.location.current(demo: state.demoMode)
        step = .preparing
        Task {
            guard let photo = await Task.detached(priority: .userInitiated, operation: make).value else {
                error = "That photo could not be read."
                step = .choose
                return
            }
            step = .analyzing(photo, done: [])
            let analysis = (try? await ImageAnalyzer.analyze(jpeg: photo.jpeg, hash: photo.hash) { stage in
                Task { @MainActor in
                    if case .analyzing(let p, var done) = step { done.insert(stage); step = .analyzing(p, done: done) }
                }
            }) ?? AnalysisResult(labels: [], ocrText: "", embedding: [], precomputed: false)
            checkForDuplicates(analysis)
            step = .review(photo, analysis)
            showDuplicates = !duplicates.isEmpty
            makeSummary(analysis)
        }
    }

    /// Talking point: a third model on the phone. Apple's language model writes the one-line title from the
    /// report's own facts, beside Vision and the database, with nothing sent anywhere.
    private func makeSummary(_ analysis: AnalysisResult) {
        guard ReportSummary.isAvailable else { return }
        summarizing = true
        Task {
            summary = await ReportSummary.write(
                category: category, labels: analysis.labels, ocrText: analysis.ocrText, notes: notes)
            summarizing = false
        }
    }

    /// The headline moment: a vector search on the phone for open reports nearby that look like this photo.
    private func checkForDuplicates(_ analysis: AnalysisResult) {
        guard let here = pinnedLocation ?? state.location.current(demo: false), !analysis.embedding.isEmpty else { return }
        duplicates = (try? state.repository.similar(to: analysis.embedding, lat: here.lat, lon: here.lon, radiusMeters: radiusMeters)) ?? []
        state.lastCheck = DuplicateCheckRun(
            embedding: analysis.embedding, lat: here.lat, lon: here.lon,
            maxDistance: DuplicateCheckQuery.defaultMaxDistance, hitIds: duplicates.map(\.id), at: Date()
        )
    }

    private func save(_ photo: PreparedPhoto, _ analysis: AnalysisResult, attachTo parent: Report? = nil) {
        guard let location = pinnedLocation ?? state.location.current(demo: false) else { return }
        var report = Report(
            id: Report.newId(), district: state.user.district, category: parent?.category ?? category, createdAt: capturedAt,
            createdBy: state.user.rawValue, deviceId: state.deviceId, location: location,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), imageHash: photo.hash, thumbnail: photo.thumbnail
        )
        report.aiLabels = analysis.labels
        report.ocrText = analysis.ocrText
        report.summary = summary ?? ""
        report.embedding = analysis.embedding
        if let parent {
            // Evidence is never dropped: the new capture is saved and linked to the report it duplicates.
            report.attachedTo = parent.id
            report.relatedReportIds = [parent.id]
        }
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
