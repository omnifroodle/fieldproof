import SwiftUI

/// Bold SF Symbol for a category inside a paper circle with an outline.
struct CategoryIcon: View {

    // MARK: - Input

    let category: ReportCategory
    var size: CGFloat = 36

    // MARK: - Body

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(Theme.Palette.charcoal)
            .frame(width: size, height: size)
            .background(Theme.Palette.paper, in: Circle())
            .overlay(Circle().stroke(Theme.Palette.charcoal, lineWidth: 2))
            .accessibilityLabel(category.label)
    }
}
