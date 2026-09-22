import CoreGraphics
import CoreML
import Foundation
import ImageIO
import OSLog
import Vision

/// Classification, OCR, and an image embedding, all on the device with Apple's Vision framework.
enum ImageAnalyzer {

    // MARK: - Errors

    enum AnalyzerError: Error {
        case undecodableImage
        case noFeaturePrint
        case unexpectedFeaturePrint(count: Int)
    }

    // MARK: - Analyze

    /// Analyzes the exact JPEG bytes that will be stored, so the same stored photo always yields the same vector.
    static func analyze(jpeg: Data) async throws -> AnalysisResult {
        try await Task.detached(priority: .userInitiated) {
            let (image, orientation) = try decode(jpeg)
            let handler = VNImageRequestHandler(cgImage: image, orientation: orientation)
            return AnalysisResult(
                labels: attempt("classify", []) { try classify(handler) },
                ocrText: attempt("ocr", "") { try readText(handler) },
                embedding: try featurePrint(handler)
            )
        }.value
    }

    // MARK: - Requests

    /// Built-in classifier: keep the top 5 labels with confidence of at least 0.1.
    private static func classify(_ handler: VNImageRequestHandler) throws -> [AnalysisResult.Label] {
        let request = VNClassifyImageRequest()
        useCPUOnSimulator(request)
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
        useCPUOnSimulator(request)
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try handler.perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return String(lines.joined(separator: "\n").prefix(500))
    }

    /// Image embedding: Vision feature print revision 2, a normalized vector of 768 floats.
    private static func featurePrint(_ handler: VNImageRequestHandler) throws -> [Float] {
        let request = VNGenerateImageFeaturePrintRequest()
        useCPUOnSimulator(request)
        request.revision = VNGenerateImageFeaturePrintRequestRevision2   // pin the model so vectors stay comparable
        request.imageCropAndScaleOption = .scaleFill
        try handler.perform([request])
        guard let observation = request.results?.first, observation.elementType == .float else {
            throw AnalyzerError.noFeaturePrint
        }
        guard observation.elementCount == Embedding.dimensions else {
            throw AnalyzerError.unexpectedFeaturePrint(count: observation.elementCount)
        }
        return observation.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    // MARK: - Helpers

    private static let log = Logger(subsystem: "com.couchbase.demo.fieldproof", category: "ImageAnalyzer")

    /// Labels and OCR are supporting evidence: a failure is logged, and the capture still goes ahead.
    private static func attempt<T>(_ name: String, _ fallback: T, _ body: () throws -> T) -> T {
        do { return try body() } catch {
            log.error("\(name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            return fallback
        }
    }

    /// The simulator has no Neural Engine or GPU for Vision's models, so pin every stage to the CPU there.
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
