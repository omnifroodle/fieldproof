// Generates the near-duplicate pothole photos from pothole-01.jpg with Core Image.
// Run from the repo root: swift scripts/make-variants.swift
// Outputs (committed): pothole-01b.jpg, pothole-01c.jpg (seeded), capture-pothole.jpg (the demo capture, not seeded).
import CoreImage
import Foundation

let dir = URL(fileURLWithPath: "ios/FieldProof/Demo/Samples")
let context = CIContext()
guard let base = CIImage(contentsOf: dir.appendingPathComponent("pothole-01.jpg")) else {
    fatalError("pothole-01.jpg not found; run from the repo root")
}

/// Center crop to a fraction of the original, optionally nudged off center.
func crop(_ image: CIImage, _ fraction: CGFloat, dx: CGFloat = 0, dy: CGFloat = 0) -> CIImage {
    let e = image.extent
    let w = e.width * fraction, h = e.height * fraction
    let rect = CGRect(x: e.midX - w / 2 + dx * e.width, y: e.midY - h / 2 + dy * e.height, width: w, height: h)
    return image.cropped(to: rect).transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
}

func adjust(_ image: CIImage, brightness: Double = 0, saturation: Double = 1, hue: Double = 0) -> CIImage {
    var out = image.applyingFilter("CIColorControls", parameters: [
        kCIInputBrightnessKey: brightness, kCIInputSaturationKey: saturation, kCIInputContrastKey: 1.0,
    ])
    if hue != 0 { out = out.applyingFilter("CIHueAdjust", parameters: [kCIInputAngleKey: hue]) }
    return out
}

func rotate(_ image: CIImage, degrees: CGFloat) -> CIImage {
    let rotated = image.transformed(by: CGAffineTransform(rotationAngle: degrees * .pi / 180))
    let moved = rotated.transformed(by: CGAffineTransform(translationX: -rotated.extent.minX, y: -rotated.extent.minY))
    return crop(moved, 0.86)   // trim the empty corners the rotation leaves behind
}

func save(_ image: CIImage, _ name: String) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let options = [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.85]
    guard let data = context.jpegRepresentation(of: image, colorSpace: space, options: options) else {
        fatalError("could not encode \(name)")
    }
    try data.write(to: dir.appendingPathComponent(name))
    print("\(name): \(Int(image.extent.width))x\(Int(image.extent.height)), \(data.count / 1024) KB")
}

try save(crop(base, 0.92), "pothole-01b.jpg")
try save(adjust(rotate(base, degrees: 3), brightness: 0.08), "pothole-01c.jpg")
try save(adjust(crop(base, 0.88, dx: 0.02, dy: -0.01), saturation: 1.12, hue: 0.06), "capture-pothole.jpg")
