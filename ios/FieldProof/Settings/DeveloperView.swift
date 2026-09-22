import SwiftUI

/// Settings → Developer: the last duplicate check against every analyzed report, for tuning the threshold.
struct DeveloperView: View {

    // MARK: - State

    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [SimilarReport] = []

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack {
                    Text("LAST DUPLICATE CHECK").font(Theme.Typeface.display(32)).foregroundStyle(Theme.Palette.pine)
                    Spacer()
                    Button("Done") { dismiss() }.buttonStyle(PosterButtonStyle(kind: .outline)).fixedSize()
                }
                if let run = state.lastCheck {
                    Text("\(run.at.formatted(date: .omitted, time: .standard)) · threshold \(run.maxDistance, specifier: "%.2f") · radius 200 m · \(run.hitIds.count) hits")
                        .font(Theme.Typeface.label(14)).foregroundStyle(Theme.Palette.charcoal)
                    Text("Exact cosine distance from the captured photo to every analyzed report on this phone.")
                        .font(Theme.Typeface.body(13)).foregroundStyle(Theme.Palette.charcoal)
                    Grid(alignment: .leading, horizontalSpacing: Theme.Space.s, verticalSpacing: 4) {
                        GridRow {
                            ForEach(["DIST", "M", "REPORT", ""], id: \.self) {
                                Text($0).font(Theme.Typeface.heading(12)).foregroundStyle(Theme.Palette.pineLight)
                            }
                        }
                        ForEach(rows) { row in
                            GridRow {
                                Text(String(format: "%.3f", row.distance))
                                Text("\(Int(row.meters))")
                                Text(row.report.id.replacingOccurrences(of: "report::", with: "")).lineLimit(1)
                                Text(flag(row, run))
                            }
                            .font(Theme.Typeface.mono(12))
                            .foregroundStyle(run.hitIds.contains(row.id) ? Theme.Palette.sienna : Theme.Palette.charcoal)
                        }
                    }
                } else {
                    EmptyTrailView(message: "NO CHECK YET", detail: "Capture a photo; the duplicate check runs before you file.")
                }
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.Palette.paper)
        .task {
            guard let run = state.lastCheck else { return }
            rows = (try? state.repository.allDistances(to: run.embedding, lat: run.lat, lon: run.lon)) ?? []
        }
    }

    /// HIT = returned by the query. Otherwise why not: too far, resolved, attached, or above the threshold.
    private func flag(_ row: SimilarReport, _ run: DuplicateCheckRun) -> String {
        if run.hitIds.contains(row.id) { return "HIT" }
        if row.meters > 200 { return "far" }
        if row.report.status == .resolved { return "resolved" }
        if row.report.attachedTo != nil { return "attached" }
        return row.distance >= run.maxDistance ? "above" : "not returned"
    }
}
