import CouchbaseLiteSwift
import UIKit
import Vision
import ImageIO

/// Phase 0 only: proves the risky pieces (vector extension, Vision, the duplicate query) on this device.
/// Removed in Phase 1.
enum Phase0Spike {

    // MARK: - Run

    static func run(db: Database) async -> [String] {
        var out: [String] = []
        func log(_ line: String) { out.append(line); print("[SPIKE] \(line)") }

        // Diagnostic: which compute devices does the simulator offer, and do any give distinct vectors?
        await probeComputeDevices(log)

        // Cross-platform check: the same bundled JPEG, analyzed here, to compare with the Mac's vector.
        if let url = Bundle.main.url(forResource: "phase0-test", withExtension: "jpg"),
           let data = try? Data(contentsOf: url),
           let v = try? await ImageAnalyzer.analyze(jpeg: data).embedding {
            print("[SPIKE] VEC " + v.map { String($0) }.joined(separator: ","))
            log("  bundled phase0-test.jpg analyzed (\(data.count) bytes)")
        }

        // Step 2: extension, database, collections, indexes (done at app startup).
        do {
            let reports = try require(db.collection(name: DatabaseManager.reportsName, scope: DatabaseManager.scopeName))
            log("PASS step2 db=\(db.name) collections=\(try db.collections(scope: DatabaseManager.scopeName).map(\.name).sorted()) indexes=\(try reports.indexes().sorted())")
        } catch { log("FAIL step2 \(error)") }

        // Step 3: Vision on a rendered test image.
        let base = render(pothole: true, crop: 1.0, text: "ASSET 4471")
        do {
            let t0 = Date()
            let a = try await ImageAnalyzer.analyze(jpeg: base)
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            let again = try await ImageAnalyzer.analyze(jpeg: base)
            let norm = sqrt(a.embedding.reduce(0) { $0 + $1 * $1 })
            log("PASS step3 elementCount=\(a.embedding.count) norm=\(String(format: "%.4f", norm)) deterministic=\(a.embedding == again.embedding) time=\(ms)ms")
            log("  labels=\(a.labels.map { "\($0.label):\(String(format: "%.2f", $0.confidence))" })")
            log("  ocr=\(a.ocrText.replacingOccurrences(of: "\n", with: " | "))")
            log("  first4=\(a.embedding.prefix(4).map { String(format: "%.5f", $0) })")
        } catch { log("FAIL step3 \(error)") }

        // Step 4: three documents with embeddings, then the duplicate query.
        do {
            let reports = try require(db.collection(name: DatabaseManager.reportsName, scope: DatabaseManager.scopeName))
            let lat = 37.7460, lon = -119.5860
            let fixtures: [(String, Data, Double, String)] = [
                ("spike::near-dup", render(pothole: true, crop: 0.92, text: "ASSET 4471"), 0.0003, "open"),
                ("spike::similar", render(pothole: true, crop: 0.80, text: "LOT C"), 0.0005, "open"),
                ("spike::different", render(pothole: false, crop: 1.0, text: ""), 0.0004, "open"),
            ]
            let query = try await ImageAnalyzer.analyze(jpeg: base).embedding
            for (id, jpeg, dLat, status) in fixtures {
                let e = try await ImageAnalyzer.analyze(jpeg: jpeg).embedding
                log("  exact cosine \(id) = \(String(format: "%.4f", Embedding.cosineDistance(query, e)))")
                let doc = MutableDocument(id: id)
                doc.setString("report", forKey: "type")
                doc.setString(status, forKey: "status")
                doc.setString("pothole", forKey: "category")
                doc.setDictionary(MutableDictionaryObject(data: ["lat": lat + dLat, "lon": lon]), forKey: "location")
                doc.setArray(MutableArrayObject(data: e.map { $0 as NSNumber }), forKey: "embedding")
                try reports.save(document: doc)
            }
            let raw = try db.createQuery("SELECT META().id AS id, APPROX_VECTOR_DISTANCE(embedding, $v, 'COSINE') AS d FROM evidence.reports ORDER BY APPROX_VECTOR_DISTANCE(embedding, $v, 'COSINE') LIMIT 5")
            let rp = Parameters(); rp.setArray(MutableArrayObject(data: query.map { $0 as NSNumber }), forName: "v"); raw.parameters = rp
            for r in try raw.execute() { log("  raw \(r.toDictionary())") }
            let hits = try DuplicateCheckQuery.run(in: db, embedding: query, lat: lat, lon: lon, maxDistance: 2.0)
            let ordered = zip(hits, hits.dropFirst()).allSatisfy { $0.vectorDistance <= $1.vectorDistance }
            log("PASS step4 hits=\(hits.count) ordered=\(ordered)")
            for h in hits {
                log("  \(h.id) distance=\(String(format: "%.4f", h.vectorDistance)) meters=\(Int(h.meters))")
            }
            let strict = try DuplicateCheckQuery.run(in: db, embedding: query, lat: lat, lon: lon)
            log("  with maxDistance 0.35: \(strict.map(\.id))")

            for (id, _, _, _) in fixtures {
                if let d = try reports.document(id: id) { try reports.delete(document: d) }
            }
            // Does Couchbase Lite accept SQL comments inside the query string?
            do {
                _ = try db.createQuery("SELECT META().id FROM evidence.reports -- trailing comment\nWHERE type = 'report'")
                log("  sql -- comments: accepted")
            } catch { log("  sql -- comments: rejected (\(error.localizedDescription))") }
        } catch { log("FAIL step4 \(error)") }
        return out
    }

    // MARK: - Compute device probe

    private static func probeComputeDevices(_ log: (String) -> Void) async {
        let a = render(pothole: true, crop: 1.0, text: ""), b = render(pothole: false, crop: 1.0, text: "")
        func fp(_ jpeg: Data, _ configure: (VNRequest) -> Void) throws -> [Float] {
            let src = CGImageSourceCreateWithData(jpeg as CFData, nil)!
            let cg = CGImageSourceCreateImageAtIndex(src, 0, nil)!
            let req = VNGenerateImageFeaturePrintRequest()
            req.revision = VNGenerateImageFeaturePrintRequestRevision2
            req.imageCropAndScaleOption = .scaleFill
            configure(req)
            try VNImageRequestHandler(cgImage: cg).perform([req])
            return req.results!.first!.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }
        let probe = VNGenerateImageFeaturePrintRequest()
        probe.revision = VNGenerateImageFeaturePrintRequestRevision2
        let stages = (try? probe.supportedComputeStageDevices) ?? [:]
        for (stage, devices) in stages { log("  stage \(stage.rawValue): \(devices.map { "\($0)" })") }
        var variants: [(String, (VNRequest) -> Void)] = [("default", { _ in })]
        for (stage, devices) in stages {
            for d in devices { variants.append(("\(stage.rawValue)=\(d)".prefix(60).description, { $0.setComputeDevice(d, for: stage) })) }
        }
        variants.append(("all-cpu", { r in
            for (st, ds) in stages { if let c = ds.first(where: { if case .cpu = $0 { return true } else { return false } }) { r.setComputeDevice(c, for: st) } }
        }))
        for (name, cfg) in variants {
            do {
                let va = try fp(a, cfg), vb = try fp(b, cfg)
                log("  probe \(name): d=\(String(format: "%.4f", Embedding.cosineDistance(va, vb))) first=\(String(format: "%.4f", va[0]))")
            } catch { log("  probe \(name): error \(error.localizedDescription)") }
        }
    }

    // MARK: - Helpers

    private struct Missing: Error {}
    private static func require<T>(_ value: T?) throws -> T {
        guard let value else { throw Missing() }
        return value
    }

    /// A simple road scene: sky, asphalt, an optional dark pothole, optional painted text.
    private static func render(pothole: Bool, crop: CGFloat, text: String) -> Data {
        let size = CGSize(width: 800, height: 600)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: size.width / 2, y: size.height / 2)
            c.scaleBy(x: 1 / crop, y: 1 / crop)
            c.translateBy(x: -size.width / 2, y: -size.height / 2)
            UIColor(red: 0.55, green: 0.72, blue: 0.85, alpha: 1).setFill()
            c.fill(CGRect(x: 0, y: 0, width: 800, height: 220))
            UIColor(white: pothole ? 0.38 : 0.2, alpha: 1).setFill()
            c.fill(CGRect(x: 0, y: 220, width: 800, height: 380))
            if pothole {
                UIColor(white: 0.12, alpha: 1).setFill()
                c.fillEllipse(in: CGRect(x: 280, y: 380, width: 260, height: 120))
            } else {
                UIColor(red: 0.2, green: 0.45, blue: 0.2, alpha: 1).setFill()
                for i in 0..<5 { c.fillEllipse(in: CGRect(x: 40 + i * 150, y: 120, width: 120, height: 200)) }
            }
            if !text.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 56), .foregroundColor: UIColor.white]
                (text as NSString).draw(at: CGPoint(x: 220, y: 250), withAttributes: attrs)
            }
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}
