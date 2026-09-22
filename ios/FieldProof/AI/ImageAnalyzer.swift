import CoreGraphics
import CoreML
import Foundation
import ImageIO
import OSLog
import Vision

/// Classification, OCR, and an image embedding, all on the device with Apple's Vision framework. No cloud call.
enum ImageAnalyzer {

    // MARK: - Types

    enum Stage: Int, CaseIterable, Sendable {
        case classify, readText, fingerprint

        var title: String {
            switch self {
            case .classify: "Classify"
            case .readText: "Read text"
            case .fingerprint: "Fingerprint"
            }
        }
    }

    enum AnalyzerError: Error {
        case undecodableImage
    }

    // MARK: - Analyze

    /// Analyzes the exact JPEG bytes that will be stored, so the same stored photo always yields the same vector.
    /// `done` is called as each stage finishes.
    static func analyze(jpeg: Data, hash: String, done: @escaping @Sendable (Stage) -> Void = { _ in }) async throws -> AnalysisResult {
        try await Task.detached(priority: .userInitiated) {
            let (image, orientation) = try decode(jpeg)
            let handler = VNImageRequestHandler(cgImage: image, orientation: orientation)

            #if targetEnvironment(simulator)
            // Vision's image models cannot run on the simulator; use the Mac-computed results for bundled samples.
            let sample = SampleAnalysis.entry(forHash: hash)
            done(.classify)
            let text = attempt("ocr", "") { try readText(handler) }
            done(.readText)
            done(.fingerprint)
            return AnalysisResult(labels: sample?.labels ?? [], ocrText: text, embedding: sample?.embedding ?? [], precomputed: true)
            #else
            let labels = attempt("classify", []) { try classify(handler) }
            done(.classify)
            let text = attempt("ocr", "") { try readText(handler) }
            done(.readText)
            let vector = attempt("fingerprint", []) { try featurePrint(handler) }
            done(.fingerprint)
            return AnalysisResult(labels: labels, ocrText: text, embedding: vector, precomputed: false)
            #endif
        }.value
    }

    // MARK: - Requests

    /// Built-in classifier: keep the top 5 labels with confidence of at least 0.1.
    private static func classify(_ handler: VNImageRequestHandler) throws -> [AnalysisResult.Label] {
        let request = VNClassifyImageRequest()
        try handler.perform([request])
        return (request.results ?? [])
            .filter { $0.confidence >= 0.1 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(5)
            .map { AnalysisResult.Label(label: $0.identifier, confidence: Double($0.confidence)) }
    }

    /// OCR for asset tags and signs: top candidate per line, newline separated, at most 500 characters.
    private static func readText(_ handler: VNImageRequestHandler) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        useCPUOnSimulator(request)
        try handler.perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return String(lines.joined(separator: "\n").prefix(500))
    }

    /// Image embedding: Vision feature print revision 2, a normalized vector of 768 floats.
    private static func featurePrint(_ handler: VNImageRequestHandler) throws -> [Float] {
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision2   // pin the model so vectors stay comparable
        request.imageCropAndScaleOption = .scaleFill
        try handler.perform([request])
        guard let observation = request.results?.first, observation.elementType == .float,
              observation.elementCount == Embedding.dimensions else { return [] }
        return Embedding.normalized(observation.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) })
    }

    // MARK: - Helpers

    private static let log = Logger(subsystem: "com.couchbase.demo.fieldproof", category: "ImageAnalyzer")

    /// AI results are supporting evidence: a failure is logged, and the capture still goes ahead.
    private static func attempt<T>(_ name: String, _ fallback: T, _ body: () throws -> T) -> T {
        do { return try body() } catch {
            log.error("\(name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            return fallback
        }
    }

    /// OCR runs on the simulator only when pinned to the CPU. (A device uses its default, the Neural Engine.)
    private static func useCPUOnSimulator(_ request: VNRequest) {
        #if targetEnvironment(simulator)
        guard let stages = try? request.supportedComputeStageDevices else { return }
        for (stage, devices) in stages {
            if let cpu = devices.first(where: { if case .cpu = $0 { return true } else { return false } }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
        #endif
    }

    // MARK: - Decoding

    private static func decode(_ jpeg: Data) throws -> (CGImage, CGImagePropertyOrientation) {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw AnalyzerError.undecodableImage
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let raw = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        return (image, CGImagePropertyOrientation(rawValue: raw) ?? .up)
    }
}
