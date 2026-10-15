import SwiftUI

/// Hard paywall shown after onboarding (no close button: RepLock's passed
/// review). Honest by design (docs/SOURCES.md, research teardown): the billed
/// price is the big number, the trial timeline says when money is taken, and
/// the 3.1.2 line names the subscription, its length and its price.
struct PaywallView: View {
    @ObservedObject private var subs = SubscriptionManager.shared
    @AppStorage("exitOfferShown") private var exitOfferShown = false
    @State private var purchasing = false
    @State private var showingExitOffer = false
    @State private var storeUnavailable = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(verbatim: "Pepline Pro")
                    .font(.subheadline.bold())
                    .foregroundStyle(PLColor.accent.opacity(0.7))
                Text("Everything to get every dose right.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(PLColor.text)

                SyringeView(syringe: .ml10, units: 10)
                    .padding(.vertical, 4)
                    .plCard()

                VStack(alignment: .leading, spacing: 14) {
                    bullet("function", Text("Get the dose math right"), Text("Vial, water, dose: units on your syringe, exact."))
                    bullet("list.bullet.clipboard", Text("Every site and dose, remembered"), Text("Edit or delete anything. Export to CSV."))
                    bullet("bell.badge", Text("Never run out of a vial"), Text("Reminders for each dose and for reordering."))
                }

                VStack(spacing: 10) {
                    planCard(.yearly)
                    planCard(.monthly)
                }

                if let days = subs.trialDays(subs.selectedPlan) {
                    TrialTimeline(days: days, price: subs.price(subs.selectedPlan))
                }

                Button(action: purchaseTapped) {
                    if purchasing {
                        ProgressView().tint(PLColor.onAccent)
                    } else {
                        Text(ctaTitle)
                    }
                }
                .buttonStyle(.primaryPill)
                .disabled(purchasing)

                PaywallFooter(plan: subs.selectedPlan)
            }
            .padding(20)
        }
        .background(PLBackground())
        .task {
            Analytics.track(.paywallShown, ["kind": "main"])
            if !subs.hasProduct(.yearly) { await subs.refresh() }
        }
        .sheet(isPresented: $showingExitOffer) { ExitOfferView() }
        .alert("Couldn't reach the App Store", isPresented: $storeUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
    }

    private var ctaTitle: LocalizedStringKey {
        if let days = subs.trialDays(subs.selectedPlan) {
            return "Start my \(String(days))-day free trial"
        }
        return "Subscribe"
    }

    private func bullet(_ symbol: String, _ title: Text, _ detail: Text) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(PLColor.text)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                title.font(.headline).foregroundStyle(PLColor.text)
                detail.font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func planCard(_ plan: SubscriptionManager.Plan) -> some View {
        let selected = subs.selectedPlan == plan
        return Button { subs.selectedPlan = plan } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    (plan == .yearly ? Text("Yearly") : Text("Monthly"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    // The billed price is the big number (3.1.2, and the
                    // opposite of the competitor's inflated per-month figure).
                    if let price = subs.price(plan) {
                        (plan == .yearly ? Text("\(price) / year") : Text("\(price) / month"))
                            .font(.title3.bold())
                            .foregroundStyle(PLColor.text)
                    }
                    if plan == .yearly {
                        if let days = subs.trialDays(.yearly), let perMonth = subs.perMonth(.yearly) {
                            Text("\(String(days)) days free · about \(perMonth) / month")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } else if subs.trialDays(.monthly) == nil {
                        Text("No free trial").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? PLColor.accent : Color.secondary.opacity(0.4))
            }
            .padding(16)
            .background(PLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? PLColor.accent : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func purchaseTapped() {
        purchasing = true
        Task {
            // A missing product (slow network, review sandbox) is retried, then
            // surfaced: a button that does nothing is a 2.1(a) rejection.
            if !subs.hasProduct(subs.selectedPlan) { await subs.refresh() }
            guard subs.hasProduct(subs.selectedPlan) else {
                purchasing = false
                storeUnavailable = true
                return
            }
            let outcome = await subs.purchase(subs.selectedPlan)
            purchasing = false
            // Closing Apple's sheet on the yearly plan opens the exit offer,
            // once per install (the competitor's pattern the user liked).
            if outcome == .cancelled, subs.selectedPlan == .yearly, !exitOfferShown, subs.hasProduct(.exitOffer) {
                exitOfferShown = true
                showingExitOffer = true
            }
        }
    }
}

/// "Today → reminder → billed" — when money is taken, in plain words.
struct TrialTimeline: View {
    let days: Int
    let price: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            step("lock.open.fill", Text("Today"), Text("Full access. Nothing to pay now."))
            step("bell.fill", Text("Day \(String(max(days - 2, 1)))"), Text("We remind you that your trial ends soon."))
            step("creditcard.fill", Text("Day \(String(days))"),
                 price.map { Text("You're billed \($0) unless you cancel before.") }
                     ?? Text("Your subscription starts unless you cancel before."))
        }
        .padding(16)
        .background(PLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func step(_ symbol: String, _ title: Text, _ detail: Text) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(PLColor.text).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                title.font(.subheadline.bold()).foregroundStyle(PLColor.text)
                detail.font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

/// Guideline 3.1.2: title, length, price and auto-renewal, plus Restore,
/// Privacy and Terms, legible.
struct PaywallFooter: View {
    @ObservedObject private var subs = SubscriptionManager.shared
    let plan: SubscriptionManager.Plan

    static let privacyURL = URL(string: "https://0xcssh.github.io/pepline-legal/privacy.html")!
    static let termsURL = URL(string: "https://0xcssh.github.io/pepline-legal/terms.html")!

    var body: some View {
        VStack(spacing: 10) {
            Group {
                let title = subs.title(plan)
                if let price = subs.price(plan) {
                    if plan == .monthly {
                        Text("\(title): 1-month subscription, \(price) per month. Auto-renews monthly. Cancel anytime in your App Store settings, at least 24 hours before renewal.")
                    } else {
                        Text("\(title): 1-year subscription, \(price) per year. Auto-renews yearly. Cancel anytime in your App Store settings, at least 24 hours before renewal.")
                    }
                } else {
                    Text("Auto-renews until cancelled. Cancel anytime in your App Store settings, at least 24 hours before renewal.")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            HStack(spacing: 22) {
                Link(destination: Self.privacyURL) { Text("Privacy") }
                Button { Task { await subs.restore() } } label: { Text("Restore Purchases") }
                Link(destination: Self.termsURL) { Text("Terms") }
            }
            .font(.footnote)
            .foregroundStyle(PLColor.text)
        }
        .frame(maxWidth: .infinity)
    }
}
