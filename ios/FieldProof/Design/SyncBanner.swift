import CouchbaseLiteSwift
import SwiftUI

/// Full-width strip under the header: OFFLINE / SYNCING n / SYNCED / SYNC PAUSED.
struct SyncBanner: View {

    // MARK: - Input

    @ObservedObject var sync: SyncManager

    // MARK: - Body

    var body: some View {
        let look = self.look
        Label(look.text, systemImage: look.symbol)
            .font(Theme.Typeface.heading(14))
            .tracking(0.8)
            .foregroundStyle(look.foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.s)
            .background(look.background)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.charcoal).frame(height: 2) }
            .animation(.easeOut(duration: 0.2), value: look.text)
            .accessibilityElement(children: .combine)
    }

    // MARK: - State to look

    private struct Look {
        let text: String
        let symbol: String
        let foreground: Color
        let background: Color
    }

    private var look: Look {
        let n = sync.pendingCount
        let reports = "\(n) REPORT\(n == 1 ? "" : "S")"
        if !sync.isConfigured || sync.simulatedOffline || sync.activity == .offline || sync.activity == .stopped {
            let text = n > 0 ? "OFFLINE · \(reports) SAFE ON DEVICE" : "OFFLINE · REPORTS SAFE ON DEVICE"
            return Look(text: text, symbol: "wifi.slash", foreground: Theme.Palette.charcoal, background: Theme.Palette.mustard)
        }
        if sync.lastError != nil, sync.activity != .busy {
            return Look(text: "SYNC PAUSED · CHECK CONNECTION", symbol: "exclamationmark.triangle.fill",
                        foreground: Theme.Palette.chalk, background: Theme.Palette.sienna)
        }
        if n > 0 || sync.activity == .busy || sync.activity == .connecting {
            let text = n > 0 ? "SYNCING · \(reports) ON THE TRAIL" : "SYNCING"
            return Look(text: text, symbol: "arrow.triangle.2.circlepath", foreground: Theme.Palette.chalk, background: Theme.Palette.sky)
        }
        return Look(text: "SYNCED · ALL REPORTS FILED", symbol: "checkmark.seal.fill", foreground: Theme.Palette.chalk, background: Theme.Palette.pine)
    }
}
