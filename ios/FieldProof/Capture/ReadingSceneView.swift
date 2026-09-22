import SwiftUI

/// Progress while Vision runs: a three-step trail (Classify → Read text → Fingerprint), each turning pine when done.
struct ReadingSceneView: View {

    // MARK: - Input

    let image: UIImage
    let done: Set<ImageAnalyzer.Stage>

    // MARK: - Body

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            Image(uiImage: image)
                .resizable().scaledToFit()
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.Palette.charcoal, lineWidth: 2))
            Text("READING THE SCENE")
                .font(Theme.Typeface.display(36))
                .foregroundStyle(Theme.Palette.pine)
            HStack(spacing: Theme.Space.s) {
                ForEach(ImageAnalyzer.Stage.allCases, id: \.self) { stage in
                    if stage != .classify {
                        Rectangle().fill(Theme.Palette.charcoal).frame(width: 18, height: 2)
                    }
                    let complete = done.contains(stage)
                    Label(stage.title, systemImage: complete ? "checkmark.circle.fill" : "circle.dotted")
                        .font(Theme.Typeface.label(14))
                        .foregroundStyle(complete ? Theme.Palette.chalk : Theme.Palette.charcoal)
                        .padding(.horizontal, Theme.Space.s)
                        .padding(.vertical, 6)
                        .background(complete ? Theme.Palette.pine : Theme.Palette.paperDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).stroke(Theme.Palette.charcoal, lineWidth: 1.5))
                }
            }
            Text("On-device AI. Nothing leaves the phone.")
                .font(Theme.Typeface.body(14))
                .foregroundStyle(Theme.Palette.charcoal)
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.paper)
        .animation(.easeOut(duration: 0.25), value: done)
    }
}
