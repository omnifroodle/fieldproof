import CouchbaseLiteSwift
import SwiftUI

/// Phase 0 only: shows the spike results on screen. Replaced by the real UI in Phase 1.
struct SpikeView: View {

    // MARK: - State

    let database: Database
    @State private var lines: [String] = ["Running Phase 0 checks…"]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("FIELDPROOF · PHASE 0").font(.headline)
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(line.hasPrefix("FAIL") ? .red : .primary)
                }
            }
            .padding()
        }
        .task { lines = await Phase0Spike.run(db: database) }
    }
}
