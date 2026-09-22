import SwiftUI

/// Sunburst rule: a thin line with a small diamond in the middle.
struct PosterDivider: View {

    // MARK: - Body

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            line
            Rectangle()
                .fill(Theme.Palette.mustard)
                .frame(width: 9, height: 9)
                .overlay(Rectangle().stroke(Theme.Palette.charcoal, lineWidth: 1.5))
                .rotationEffect(.degrees(45))
            line
        }
        .padding(.vertical, Theme.Space.s)
        .accessibilityHidden(true)
    }

    private var line: some View {
        Rectangle().fill(Theme.Palette.charcoal).frame(height: 1.5)
    }
}
