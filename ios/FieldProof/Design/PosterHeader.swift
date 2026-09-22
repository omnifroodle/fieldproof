import SwiftUI

/// Hero header: cream sky, mustard sun, three layers of flat mountains, and the FIELDPROOF title.
struct PosterHeader: View {

    // MARK: - Input

    var subtitle: String
    var height: CGFloat = 150

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Theme.Palette.paper
            Circle()
                .fill(Theme.Palette.mustard)
                .frame(width: 72, height: 72)
                .padding(.top, 58)
                .padding(.trailing, 56)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            Ridge(points: [(0, 0.62), (0.18, 0.30), (0.34, 0.52), (0.55, 0.22), (0.78, 0.48), (1, 0.34)])
                .fill(Theme.Palette.pineLight)
            Ridge(points: [(0, 0.78), (0.22, 0.50), (0.42, 0.70), (0.66, 0.44), (0.86, 0.66), (1, 0.56)])
                .fill(Theme.Palette.pine)
            Ridge(points: [(0, 0.92), (0.30, 0.76), (0.60, 0.88), (0.82, 0.74), (1, 0.84)])
                .fill(Theme.Palette.charcoal)
            VStack(alignment: .leading, spacing: 0) {
                Text("FIELDPROOF")
                    .font(Theme.Typeface.display(48))
                    .tracking(1.5)
                    .foregroundStyle(Theme.Palette.chalk)
                Text(subtitle)
                    .font(Theme.Typeface.label(14))
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.mustard)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.bottom, Theme.Space.s)
        }
        .frame(height: height)
        .clipped()
        .accessibilityElement(children: .combine)
    }
}

/// A flat mountain silhouette from normalized (x, y) ridge points, filled down to the bottom edge.
private struct Ridge: Shape {
    let points: [(CGFloat, CGFloat)]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for (x, y) in points {
            path.addLine(to: CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
