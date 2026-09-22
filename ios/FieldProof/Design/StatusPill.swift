import SwiftUI

/// Fully rounded status pill: open = sienna, in progress = mustard, resolved = pine.
struct StatusPill: View {

    // MARK: - Input

    let status: ReportStatus

    // MARK: - Body

    var body: some View {
        Text(status.label)
            .font(Theme.Typeface.heading(13))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(status == .inProgress ? Theme.Palette.charcoal : Theme.Palette.chalk)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(status.color, in: Capsule())
            .overlay(Capsule().stroke(Theme.Palette.charcoal, lineWidth: 1.5))
    }
}
