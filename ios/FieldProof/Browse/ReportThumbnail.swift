import SwiftUI

/// A JPEG thumbnail in a 2 pt poster frame. Evidence photos are shown as taken, never filtered.
struct ReportThumbnail: View {

    // MARK: - Input

    let data: Data?
    var size: CGFloat = 76

    // MARK: - Body

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.Palette.paper.overlay(Image(systemName: "photo").foregroundStyle(Theme.Palette.pineLight))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).stroke(Theme.Palette.charcoal, lineWidth: 2))
        .accessibilityHidden(true)
    }
}
