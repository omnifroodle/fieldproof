import Foundation

/// The inputs and hits of the most recent duplicate check, kept for the Developer screen.
struct DuplicateCheckRun {
    let embedding: [Float]
    let lat: Double
    let lon: Double
    let maxDistance: Double
    let hitIds: [String]
    let at: Date
}
