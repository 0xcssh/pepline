import SwiftUI

/// Shown once, when the user closes Apple's payment sheet on the yearly plan.
/// A real cheaper product (com.awdia.pepline.pro.yearly.offer), the billed
/// price as the big number, a real "before" price (the same yearly plan), and
/// a close button — no countdown, no "lowest price ever".
struct ExitOfferView: View {
    @ObservedObject private var subs = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var purchasing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer()
                Button {
                    Analytics.track(.exitOfferDismissed)
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text("Close"))
            }

            if let percent = subs.exitOfferPercent {
                Text("\(percent.formatted(.percent)) off Pepline Pro")
                    .font(.largeTitle.bold())
                    .foregroundStyle(PLColor.text)
            } else {
                Text("A better price for Pepline Pro")
                    .font(.largeTitle.bold())
                    .foregroundStyle(PLColor.text)
            }
            Text("Same app, same features. A lower yearly price, for as long as you stay subscribed.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                if let regular = subs.price(.yearly) {
                    Text(verbatim: regular)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                }
                if let price = subs.price(.exitOffer) {
                    Text("\(price) / year")
                        .plNumeral(size: 40)
                        .foregroundStyle(PLColor.text)
                }
                if let days = subs.trialDays(.exitOffer) {
                    Text("\(String(days)) days free, then billed yearly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer(minLength: 0)

            Button {
                purchasing = true
                Task {
                    let outcome = await subs.purchase(.exitOffer)
                    purchasing = false
                    if outcome == .success { dismiss() }
                }
            } label: {
                if purchasing { ProgressView().tint(PLColor.onAccent) } else { Text("Get this offer") }
            }
            .buttonStyle(.primaryPill)
            .disabled(purchasing || !subs.hasProduct(.exitOffer))

            PaywallFooter(plan: .exitOffer)
        }
        .padding(20)
        .background(PLBackground())
        .task { Analytics.track(.paywallShown, ["kind": "exitOffer"]) }
    }
}
