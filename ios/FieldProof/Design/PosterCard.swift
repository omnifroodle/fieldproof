import SwiftUI

/// Card with a 2 pt charcoal outline and a solid offset shadow, like a screen print.
struct PosterCard<Content: View>: View {

    // MARK: - Content

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        content
            .padding(Theme.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.paperDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.Palette.charcoal, lineWidth: 2))
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.Palette.charcoal.opacity(0.15))
                    .offset(x: 3, y: 3)
            )
    }
}
