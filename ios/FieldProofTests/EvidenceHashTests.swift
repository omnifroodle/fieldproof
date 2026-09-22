import XCTest
@testable import FieldProof

/// SHA-256 against the published FIPS 180-2 test vectors.
final class EvidenceHashTests: XCTestCase {

    func testKnownVectors() {
        XCTAssertEqual(EvidenceHash.sha256Hex(Data("abc".utf8)),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(EvidenceHash.sha256Hex(Data()),
                       "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testOneByteChangesTheHash() {
        var bytes = Data("fieldproof photo".utf8)
        let before = EvidenceHash.sha256Hex(bytes)
        bytes[0] ^= 0x01
        XCTAssertNotEqual(before, EvidenceHash.sha256Hex(bytes))
    }

    func testShortForm() {
        let hex = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        XCTAssertEqual(EvidenceHash.short(hex), "ba7816bf…f20015ad")
        XCTAssertEqual(EvidenceHash.short("abcd"), "abcd")
    }
}
