import SwiftUI

/// A similar report: framed thumbnail, similarity as a big number, distance, age, and status.
struct SimilarReportRow: View {

    // MARK: - Input

    let item: SimilarReport
    var selected = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            ReportThumbnail(data: item.report.thumbnail, size: 72)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.report.category.label.uppercased())
                    .font(Theme.Typeface.heading(16))
                    .foregroundStyle(Theme.Palette.pine)
                Text("\(Int(item.meters.rounded())) m away · \(item.report.createdAt.formatted(.relative(presentation: .named)))")
                    .font(Theme.Typeface.label(13))
                    .foregroundStyle(Theme.Palette.charcoal)
                StatusPill(status: item.report.status)
            }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text("\(item.similarityPercent)%")
                    .font(Theme.Typeface.display(38))
                    .foregroundStyle(Theme.Palette.sienna)
                Text("ALIKE").font(Theme.Typeface.label(11)).foregroundStyle(Theme.Palette.pineLight)
            }
        }
        .padding(Theme.Space.s)
        .background(selected ? Theme.Palette.chalk : Theme.Palette.paperDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(selected ? Theme.Palette.sienna : Theme.Palette.charcoal, lineWidth: selected ? 3 : 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
