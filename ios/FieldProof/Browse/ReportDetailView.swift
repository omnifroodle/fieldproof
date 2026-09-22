import SwiftUI

/// One report: the full photo, where and when it was taken, AI findings, and the evidence hash.
struct ReportDetailView: View {

    // MARK: - Input

    let reportId: String

    // MARK: - State

    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var photo: Data?
    @State private var verified: Bool?

    private var report: Report? { state.reports.first { $0.id == reportId } }

    // MARK: - Body

    var body: some View {
        ScrollView {
            if let report {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    titleBar(report)
                    photoView(report)
                    EvidencePanel(report: report)
                    if !report.notes.isEmpty { section("NOTES", report.notes) }
                    if !report.aiLabels.isEmpty {
                        section("ON-DEVICE LABELS", report.aiLabels.map { "\($0.label) \(Int($0.confidence * 100))%" }.joined(separator: " · "))
                    }
                    if !report.ocrText.isEmpty { section("TEXT IN PHOTO", report.ocrText) }
                    PosterDivider()
                    hashPanel(report)
                }
                .padding(Theme.Space.l)
            } else {
                EmptyTrailView(message: "REPORT NOT ON THIS DEVICE", detail: "It may have been removed by a reset or a sync.")
            }
        }
        .background(Theme.Palette.paper)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: report?.imageHash) {
            guard let report else { return }
            photo = try? state.repository.photoData(for: report)
        }
    }

    // MARK: - Sections

    private func titleBar(_ report: Report) -> some View {
        HStack(alignment: .center, spacing: Theme.Space.m) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Palette.charcoal)
                    .frame(width: 40, height: 40)
                    .background(Theme.Palette.paperDeep, in: Circle())
                    .overlay(Circle().stroke(Theme.Palette.charcoal, lineWidth: 2))
            }
            .accessibilityLabel("Back")
            CategoryIcon(category: report.category, size: 40)
            Text(report.category.label.uppercased())
                .font(Theme.Typeface.display(34))
                .foregroundStyle(Theme.Palette.pine)
            Spacer(minLength: 0)
            StatusPill(status: report.status)
        }
    }

    private func photoView(_ report: Report) -> some View {
        let data = photo ?? report.thumbnail
        return Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Theme.Palette.paperDeep.frame(height: 220)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.Palette.charcoal, lineWidth: 2))
        .overlay(alignment: .bottomLeading) {
            if photo == nil {
                Text("THUMBNAIL · FULL PHOTO NOT SYNCED YET")
                    .font(Theme.Typeface.label(12))
                    .padding(6)
                    .background(Theme.Palette.mustard)
                    .padding(Theme.Space.s)
            }
        }
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title).font(Theme.Typeface.heading(15)).tracking(0.8).foregroundStyle(Theme.Palette.pineLight)
            Text(text).font(Theme.Typeface.body()).foregroundStyle(Theme.Palette.charcoal)
        }
    }

    private func hashPanel(_ report: Report) -> some View {
        PosterCard {
            HStack(alignment: .center, spacing: Theme.Space.m) {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text("EVIDENCE HASH · SHA-256").font(Theme.Typeface.heading(15)).foregroundStyle(Theme.Palette.pine)
                    HStack(spacing: Theme.Space.s) {
                        Text(EvidenceHash.short(report.imageHash)).font(Theme.Typeface.mono(14)).foregroundStyle(Theme.Palette.charcoal)
                        Button { UIPasteboard.general.string = report.imageHash } label: {
                            Image(systemName: "doc.on.doc").foregroundStyle(Theme.Palette.charcoal)
                        }
                        .accessibilityLabel("Copy full hash")
                    }
                    Text("Computed on this device when the photo was taken.")
                        .font(Theme.Typeface.body(13)).foregroundStyle(Theme.Palette.charcoal)
                    Button("Recompute") {
                        verified = photo.map { EvidenceHash.sha256Hex($0) == report.imageHash }
                    }
                    .buttonStyle(PosterButtonStyle(kind: .outline))
                    .disabled(photo == nil)
                }
                if let verified { VerifiedBadge(verified: verified) }
            }
        }
    }
}

/// When, where, who: the metadata captured with the photo.
private struct EvidencePanel: View {
    let report: Report

    var body: some View {
        PosterCard {
            Grid(alignment: .leading, horizontalSpacing: Theme.Space.m, verticalSpacing: Theme.Space.xs) {
                row("TAKEN", report.createdAt.formatted(date: .abbreviated, time: .shortened))
                row("WHERE", String(format: "%.5f, %.5f  ±%.0f m", report.location.lat, report.location.lon, report.location.accuracy))
                row("HEADING", String(format: "%.0f°  ·  %.0f m elevation", report.location.heading, report.location.altitude))
                row("DISTRICT", report.district.capitalized)
                row("FILED BY", report.createdBy)
                row("ID", report.id)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).font(Theme.Typeface.heading(13)).foregroundStyle(Theme.Palette.pineLight)
            Text(value).font(Theme.Typeface.body(15)).foregroundStyle(Theme.Palette.charcoal)
        }
    }
}
