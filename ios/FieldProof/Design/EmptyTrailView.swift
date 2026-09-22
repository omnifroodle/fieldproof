import SwiftUI

/// Empty state: a small mountain silhouette and trail-sign copy.
struct EmptyTrailView: View {

    // MARK: - Input

    var message = "NO REPORTS ON THIS TRAIL YET"
    var detail = "Photograph the problem. Reports stay on the device until you are back in range."

    // MARK: - Body

    var body: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Theme.Palette.pineLight)
            Text(message)
                .font(Theme.Typeface.display(26))
                .foregroundStyle(Theme.Palette.pine)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(Theme.Typeface.body(15))
                .foregroundStyle(Theme.Palette.charcoal)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity)
    }
}
