import SwiftUI

/// The only button look in the app: filled sienna (primary) or outlined (secondary). No default blue buttons.
struct PosterButtonStyle: ButtonStyle {

    // MARK: - Kind

    enum Kind {
        case primary
        case outline
    }

    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    // MARK: - Body

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typeface.heading(17))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(kind == .primary ? Theme.Palette.chalk : Theme.Palette.charcoal)
            .padding(.vertical, Theme.Space.m)
            .padding(.horizontal, Theme.Space.l)
            .frame(maxWidth: .infinity)
            .background(
                kind == .primary ? Theme.Palette.sienna : Theme.Palette.paper,
                in: RoundedRectangle(cornerRadius: Theme.Radius.chip)
            )
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).stroke(Theme.Palette.charcoal, lineWidth: 2))
            .opacity(isEnabled ? 1 : 0.45)
            .offset(y: configuration.isPressed ? 2 : 0)
    }
}
