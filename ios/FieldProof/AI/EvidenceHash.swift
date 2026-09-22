import CryptoKit
import Foundation

/// Chain of custody: SHA-256 of the exact JPEG bytes that are stored and synced.
enum EvidenceHash {

    /// Lowercase hex, 64 characters.
    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// "9f86d081…0f00a08" style short form for the UI.
    static func short(_ hex: String) -> String {
        guard hex.count > 16 else { return hex }
        return "\(hex.prefix(8))…\(hex.suffix(8))"
    }
}
