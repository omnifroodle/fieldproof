import SwiftUI

/// Small outlined chip used for filters and single choices. Filled pine when selected.
struct ChoiceChip: View {

    // MARK: - Input

    let title: String
    let selected: Bool
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typeface.label(14))
                .foregroundStyle(selected ? Theme.Palette.chalk : Theme.Palette.charcoal)
                .padding(.horizontal, Theme.Space.m)
                .padding(.vertical, 6)
                .background(selected ? Theme.Palette.pine : Theme.Palette.paperDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).stroke(Theme.Palette.charcoal, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
