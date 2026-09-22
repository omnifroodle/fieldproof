import SwiftUI

/// One report in the list: thumbnail in a poster frame, category, status, age, and the start of the notes.
struct ReportRow: View {

    // MARK: - Input

    let report: Report

    // MARK: - Body

    var body: some View {
        PosterCard {
            HStack(alignment: .top, spacing: Theme.Space.m) {
                ReportThumbnail(data: report.thumbnail, size: 76)
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    HStack(spacing: Theme.Space.s) {
                        Text(report.category.label.uppercased())
                            .font(Theme.Typeface.heading(17))
                            .foregroundStyle(Theme.Palette.pine)
                        Spacer(minLength: 0)
                        StatusPill(status: report.status)
                    }
                    Text(report.notes.isEmpty ? "No notes" : report.notes)
                        .font(Theme.Typeface.body(14))
                        .foregroundStyle(Theme.Palette.charcoal)
                        .lineLimit(2)
                    Text("\(report.createdAt.formatted(.relative(presentation: .named))) · \(report.district.capitalized)\(links)")
                        .font(Theme.Typeface.label(13))
                        .foregroundStyle(Theme.Palette.pineLight)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var links: String {
        if report.attachedTo != nil { return " · attached capture" }
        return report.relatedReportIds.isEmpty ? "" : " · +\(report.relatedReportIds.count) attached"
    }
}
