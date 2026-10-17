import StoreKit
import SwiftUI

/// "Why are you leaving?", one tap, optional. Shown before Apple's
/// subscription page when opened from Pepline, and once when auto-renew is
/// found turned off elsewhere (iOS does not tell an app when someone cancels).
/// The reason is sent as an enum only (Core/DailyLoop.swift CancelReason).
struct CancelSurveyView: View {
    @Environment(\.dismiss) private var dismiss
    /// Opens Apple's subscription page afterwards (from Settings).
    var thenManage = false
    @State private var reason: CancelReason?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Before you go: what is not working for you?")
                        .font(.title2.bold())
                        .foregroundStyle(PLColor.text)
                    Text("One tap helps us make Pepline better. It stays anonymous.")
                        .font(.subheadline)
                        .foregroundStyle(PLColor.muted)
                    VStack(spacing: 10) {
                        ForEach(CancelReason.allCases, id: \.self) { item in
                            ChoiceCard(symbol: item.symbol, title: item.title, selected: reason == item) {
                                reason = item
                            }
                        }
                    }
                    if reason == .missingFeature || reason == .hardToUse {
                        Link(destination: URL(string: "mailto:awdianthony@gmail.com?subject=Pepline")!) {
                            Label { Text("Tell us what is missing: we answer every email.") } icon: {
                                Image(systemName: "envelope.fill")
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .padding(20)
            }
            .background(PLBackground())
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button(action: finish) {
                        (thenManage ? Text("Continue to my subscription") : Text("Send"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryPill)
                    .disabled(reason == nil && !thenManage)
                    Button { close() } label: { Text("Not now") }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PLColor.muted)
                }
                .padding(20)
            }
        }
        .onAppear { UserDefaults.standard.set(true, forKey: "cancelSurveyAsked") }
    }

    private func finish() {
        if let reason { Analytics.track(.cancelReason, ["reason": reason.rawValue]) }
        close()
    }

    private func close() {
        dismiss()
        guard thenManage else { return }
        Task {
            // After the sheet is gone, so Apple's page can present.
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            try? await AppStore.showManageSubscriptions(in: scene)
        }
    }
}

extension CancelReason {
    var title: Text {
        switch self {
        case .tooExpensive: return Text("Too expensive")
        case .stoppedTreatment: return Text("I stopped my treatment")
        case .missingFeature: return Text("A feature I need is missing")
        case .hardToUse: return Text("Hard to use")
        case .otherApp: return Text("I use another app")
        case .other: return Text("Something else")
        }
    }

    var symbol: String {
        switch self {
        case .tooExpensive: return "creditcard"
        case .stoppedTreatment: return "pause.circle"
        case .missingFeature: return "puzzlepiece"
        case .hardToUse: return "questionmark.circle"
        case .otherApp: return "arrow.left.arrow.right"
        case .other: return "ellipsis.circle"
        }
    }
}
