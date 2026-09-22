import SwiftUI

/// Home screen: poster header, filters, and every report on the device, newest first. Works fully offline.
struct ReportListView: View {

    // MARK: - State

    @EnvironmentObject private var state: AppState
    @State private var category: ReportCategory?
    @State private var status: ReportStatus?
    @State private var showCapture = false
    @State private var showSettings = false

    private var filtered: [Report] {
        state.reports.filter { report in
            (category == nil || report.category == category) && (status == nil || report.status == status)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    SyncBanner(sync: state.sync)
                    filters
                    if filtered.isEmpty {
                        EmptyTrailView()
                    } else {
                        LazyVStack(spacing: Theme.Space.m) {
                            ForEach(filtered) { report in
                                NavigationLink(value: report.id) { ReportRow(report: report) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(Theme.Space.l)
                    }
                }
                .padding(.bottom, 96)
            }
            .ignoresSafeArea(edges: .top)
            .background(Theme.Palette.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { ReportDetailView(reportId: $0) }
            .overlay(alignment: .bottom) { captureButton }
        }
        .fullScreenCover(isPresented: $showCapture) { CaptureView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    // MARK: - Sections

    private var header: some View {
        PosterHeader(subtitle: state.user.headerLine, height: 170)
            .overlay(alignment: .topTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.Palette.charcoal)
                        .frame(width: 44, height: 44)
                }
                .padding(.top, 52)
                .padding(.trailing, Theme.Space.s)
                .accessibilityLabel("Settings")
            }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.s) {
                    ChoiceChip(title: "All", selected: category == nil) { category = nil }
                    ForEach(ReportCategory.allCases) { c in
                        ChoiceChip(title: c.label, selected: category == c) { category = (category == c ? nil : c) }
                    }
                }
                .padding(.horizontal, Theme.Space.l)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.s) {
                    ChoiceChip(title: "Any status", selected: status == nil) { status = nil }
                    ForEach(ReportStatus.allCases) { s in
                        ChoiceChip(title: s.label, selected: status == s) { status = (status == s ? nil : s) }
                    }
                    Text("\(filtered.count) REPORTS")
                        .font(Theme.Typeface.label(13))
                        .foregroundStyle(Theme.Palette.pineLight)
                        .padding(.leading, Theme.Space.s)
                }
                .padding(.horizontal, Theme.Space.l)
            }
        }
        .padding(.top, Theme.Space.m)
    }

    private var captureButton: some View {
        Button { showCapture = true } label: {
            Label("Report a problem", systemImage: "camera.fill")
        }
        .buttonStyle(PosterButtonStyle())
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.s)
        .background(
            LinearGradient(colors: [Theme.Palette.paper.opacity(0), Theme.Palette.paper], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }
}
