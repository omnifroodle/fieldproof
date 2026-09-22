import SwiftUI

/// Circular rubber-stamp badge: VERIFIED in pine or MISMATCH in sienna, rotated −8°.
struct VerifiedBadge: View {

    // MARK: - Input

    let verified: Bool

    // MARK: - Body

    var body: some View {
        let color = verified ? Theme.Palette.pine : Theme.Palette.sienna
        ZStack {
            Circle().stroke(color, lineWidth: 3)
            Circle().inset(by: 6).stroke(color, lineWidth: 1.5)
            Text(verified ? "VERIFIED" : "MISMATCH")
                .font(Theme.Typeface.display(22))
                .tracking(1)
                .foregroundStyle(color)
        }
        .frame(width: 104, height: 104)
        .rotationEffect(.degrees(-8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(verified ? "Hash verified" : "Hash mismatch")
    }
}
