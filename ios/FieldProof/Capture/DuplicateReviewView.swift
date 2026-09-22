import SwiftUI

/// "Looks familiar": open reports nearby whose photos look like this one, found on the phone before saving.
struct DuplicateReviewView: View {

    // MARK: - Input

    let candidates: [SimilarReport]
    let radiusMeters: Int
    let onAttach: (SimilarReport) -> Void
    let onFileNew: () -> Void

    // MARK: - State

    @State private var selectedId: String?

    private var selected: SimilarReport? {
        candidates.first { $0.id == selectedId } ?? candidates.first
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("LOOKS FAMILIAR")
                .font(Theme.Typeface.display(40))
                .foregroundStyle(Theme.Palette.pine)
            Text(subtitle)
                .font(Theme.Typeface.body(16))
                .foregroundStyle(Theme.Palette.charcoal)
            Text("Found on this phone with a vector search. No network needed.")
                .font(Theme.Typeface.label(13))
                .foregroundStyle(Theme.Palette.pineLight)
            ScrollView {
                VStack(spacing: Theme.Space.s) {
                    ForEach(candidates) { item in
                        Button { selectedId = item.id } label: {
                            SimilarReportRow(item: item, selected: item.id == selected?.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            PosterDivider()
            Button("Attach to existing") { if let selected { onAttach(selected) } }
                .buttonStyle(PosterButtonStyle())
            Button("File as new", action: onFileNew)
                .buttonStyle(PosterButtonStyle(kind: .outline))
        }
        .padding(Theme.Space.l)
        .background(Theme.Palette.paper)
        .interactiveDismissDisabled()
    }

    private var subtitle: String {
        let n = candidates.count
        return "\(n) open report\(n == 1 ? "" : "s") within \(radiusMeters) m look\(n == 1 ? "s" : "") like this one."
    }
}
