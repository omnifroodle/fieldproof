// Precomputes Vision results for the bundled sample photos, for the iOS Simulator only.
// Why: Vision's models cannot run on the iOS Simulator (REFERENCE.md §7.1). On a real iPhone the app runs them live.
// The Mac runs the same model (feature print revision 2); Mac and iPhone vectors for the same bytes differ by ~2e-6.
//
// Run from the repo root after changing any sample: swift scripts/embed-samples.swift
// Output: ios/FieldProof/Demo/Samples/analysis.json, keyed by the SHA-256 of each file's bytes.
import CryptoKit
import Foundation
import ImageIO
import Vision

let dir = URL(fileURLWithPath: "ios/FieldProof/Demo/Samples")
let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".jpg") }.sorted()

func round6(_ x: Float) -> Double { (Double(x) * 1_000_000).rounded() / 1_000_000 }

var items: [String: Any] = [:]
for file in files {
    let data = try Data(contentsOf: dir.appendingPathComponent(file))
    let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("cannot decode \(file)") }
    let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let orientation = CGImagePropertyOrientation(rawValue: props?[kCGImagePropertyOrientation] as? UInt32 ?? 1) ?? .up

    // Same requests and settings as ImageAnalyzer.swift.
    let classify = VNClassifyImageRequest()
    let print = VNGenerateImageFeaturePrintRequest()
    print.revision = VNGenerateImageFeaturePrintRequestRevision2
    print.imageCropAndScaleOption = .scaleFill
    try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([classify, print])

    let labels = (classify.results ?? [])
        .filter { $0.confidence >= 0.1 }
        .sorted { $0.confidence > $1.confidence }
        .prefix(5)
        .map { ["label": $0.identifier, "confidence": (Double($0.confidence) * 1000).rounded() / 1000] }
    guard let obs = print.results?.first, obs.elementCount == 768 else { fatalError("no 768-dim feature print for \(file)") }
    let vector = obs.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }.map(round6)

    items[hash] = ["file": file, "labels": labels, "embedding": vector]
    Swift.print("\(file.padding(toLength: 22, withPad: " ", startingAt: 0)) \(hash.prefix(12))  \(labels.map { $0["label"] as? String ?? "" })")
}

let out: [String: Any] = ["model": "vision-featureprint-r2", "items": items]
let json = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
try json.write(to: dir.appendingPathComponent("analysis.json"))
Swift.print("wrote analysis.json: \(items.count) samples, \(json.count / 1024) KB")
