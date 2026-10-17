import SwiftUI

/// Shown once, when the user closes Apple's payment sheet on either plan.
/// A real cheaper product (com.awdia.pepline.pro.yearly.offer) against a real
/// "before" price (the same yearly plan): the saving in money and per month,
/// what the user keeps, and the same trial timeline as the paywall (SOSA 2026
/// p78: clarity converts). Honest scarcity only: it is shown once, which is
/// true. No countdown (p70: under 2% of apps, a cheap-app signal).
struct ExitOfferView: View {
    @ObservedObject private var subs = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var purchasing = false
    @State private var appeared = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            // Text a notch or two smaller before ever scrolling, unless the
            // user chose larger text in Settings (then it scrolls).
            if typeSize <= .large {
                content.dynamicTypeSize(.medium)
                content.dynamicTypeSize(.small)
                content.dynamicTypeSize(.xSmall)
            }
            ScrollView { content }
        }
        .background(PLBackground())
        .task {
            Analytics.track(.paywallShown, ["kind": "exitOffer"])
            withAnimation(.spring(duration: 0.6).delay(0.15)) { appeared = true }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label { Text("One-time offer") } icon: { Image(systemName: "gift.fill") }
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(PLColor.onAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(PLColor.accent, in: Capsule())
                Spacer()
                Button {
                    Analytics.track(.exitOfferDismissed)
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(PLColor.muted)
                }
                .accessibilityLabel(Text("Close"))
            }

            Group {
                if let percent = subs.exitOfferPercent {
                    Text("Wait: \(percent.formatted(.percent)) off, just for you")
                } else {
                    Text("A better price for Pepline Pro")
                }
            }
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(PLColor.text)
            .fixedSize(horizontal: false, vertical: true)

            Text("Same app, same features. A lower yearly price, for as long as you stay subscribed.")
                .font(.body)
                .foregroundStyle(PLColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            priceCard
                .scaleEffect(appeared ? 1 : 0.94)
                .opacity(appeared ? 1 : 0)

            VStack(alignment: .leading, spacing: 10) {
                keep("function", Text("Exact units for every vial and dose."))
                keep("bell.badge", Text("Reminders, and a warning before the vial runs out."))
                keep("doc.richtext", Text("Your journal, nutrition and doctor report."))
            }

            if let days = subs.trialDays(.exitOffer) {
                TrialTimeline(days: days, price: subs.price(.exitOffer))
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button(action: purchase) {
                    if purchasing {
                        ProgressView().tint(PLColor.onAccent)
                    } else if let days = subs.trialDays(.exitOffer) {
                        Text("Start my \(String(days))-day free trial")
                    } else {
                        Text("Get this offer")
                    }
                }
                .buttonStyle(.primaryPill)
                .disabled(purchasing || !subs.hasProduct(.exitOffer))
                Text("This offer is shown only once.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PLColor.muted)
            }
            .frame(maxWidth: .infinity)

            PaywallFooter(plan: .exitOffer)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                if let regular = subs.price(.yearly) {
                    Text(verbatim: regular)
                        .font(.title3.weight(.semibold))
                        .strikethrough()
                        .foregroundStyle(PLColor.muted)
                }
                Spacer()
                if let saving = subs.exitOfferSaving {
                    Text("You save \(saving) a year")
                        .font(.footnote.weight(.heavy))
                        .foregroundStyle(PLColor.onAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(PLColor.accent, in: Capsule())
                }
            }
            if let price = subs.price(.exitOffer) {
                Text("\(price) / year")
                    .plNumeral(size: 44)
                    .foregroundStyle(PLColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            if let perMonth = subs.perMonth(.exitOffer) {
                Text("Only \(perMonth) / month")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PLColor.accent)
                    .plGlow()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PLColor.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(PLColor.accent, lineWidth: 2))
        .shadow(color: PLColor.accent.opacity(0.25), radius: 16)
    }

    private func keep(_ symbol: String, _ text: Text) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PLColor.accent)
                .frame(width: 28, height: 28)
                .background(PLColor.accent.opacity(0.12), in: Circle())
            text.font(.subheadline).foregroundStyle(PLColor.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func purchase() {
        purchasing = true
        Task {
            let outcome = await subs.purchase(.exitOffer)
            purchasing = false
            if outcome == .success { dismiss() }
        }
    }
}
