import SwiftUI

/// Demo mode: pick a bundled photo instead of using the camera. The three capture photos come first.
struct SamplePickerView: View {

    // MARK: - Input

    let onPick: (URL) -> Void
    let onCancel: () -> Void

    // MARK: - Data

    private let samples: [URL] = {
        let all = Bundle.main.urls(forResourcesWithExtension: "jpg", subdirectory: nil) ?? []
        return all.sorted { a, b in
            let ca = a.lastPathComponent.hasPrefix("capture-"), cb = b.lastPathComponent.hasPrefix("capture-")
            return ca != cb ? ca : a.lastPathComponent < b.lastPathComponent
        }
    }()

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack {
                Text("DEMO CAMERA").font(Theme.Typeface.display(34)).foregroundStyle(Theme.Palette.pine)
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(PosterButtonStyle(kind: .outline)).fixedSize()
            }
            Text("Pick a photo as if you just took it.")
                .font(Theme.Typeface.body(15))
                .foregroundStyle(Theme.Palette.charcoal)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Theme.Space.s)], spacing: Theme.Space.s) {
                    ForEach(samples, id: \.self) { url in
                        Button { onPick(url) } label: { SampleTile(url: url) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(url.deletingPathExtension().lastPathComponent)
                    }
                }
            }
        }
        .padding(Theme.Space.l)
        .background(Theme.Palette.paper)
    }
}

/// A square tile with a downsampled preview and the file name.
private struct SampleTile: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 2) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { if let image { Image(uiImage: image).resizable().scaledToFill() } }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).stroke(Theme.Palette.charcoal, lineWidth: 2))
            Text(url.deletingPathExtension().lastPathComponent)
                .font(Theme.Typeface.label(12))
                .foregroundStyle(Theme.Palette.charcoal)
                .lineLimit(1)
        }
        .task { image = await UIImage(contentsOfFile: url.path)?.byPreparingThumbnail(ofSize: CGSize(width: 240, height: 240)) }
    }
}
