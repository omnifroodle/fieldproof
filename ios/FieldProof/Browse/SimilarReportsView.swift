import SwiftUI

/// "Find similar" from a report: the same vector query, a wider radius, and resolved work included.
struct SimilarReportsView: View {

    // MARK: - Input

    let source: Report

    // MARK: - State

    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var results: [SimilarReport]?

    static let radiusMeters = 2_000.0

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    HStack {
                        Text("SIMILAR REPORTS").font(Theme.Typeface.display(36)).foregroundStyle(Theme.Palette.pine)
                        Spacer()
                        Button("Done") { dismiss() }.buttonStyle(PosterButtonStyle(kind: .outline)).fixedSize()
                    }
                    Text("Photos that look like this one, within 2 km, any status. Searched on this phone.")
                        .font(Theme.Typeface.body(15)).foregroundStyle(Theme.Palette.charcoal)
                    if let results, results.isEmpty {
                        EmptyTrailView(message: "NOTHING ALIKE NEARBY", detail: "No report within 2 km has a photo like this one.")
                    }
                    ForEach(results ?? []) { item in
                        NavigationLink(value: item.id) { SimilarReportRow(item: item) }.buttonStyle(.plain)
                    }
                }
                .padding(Theme.Space.l)
            }
            .background(Theme.Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { ReportDetailView(reportId: $0) }
        }
        .task {
            // Talking point: the same duplicate-check query, reused with a wider radius and no status filter.
            results = (try? state.repository.similar(
                to: source.embedding, lat: source.location.lat, lon: source.location.lon,
                radiusMeters: Self.radiusMeters, excludeId: source.id, includeResolved: true
            )) ?? []
        }
    }
}
