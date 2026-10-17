import SwiftUI

/// Hard paywall shown after onboarding (no close button: RepLock's passed
/// review). The yearly plan leads with its monthly equivalent (decision
/// 2026-10-17, like the category leader; SOSA p22); the billed amount stays
/// readable under it, in the trial timeline and in the 3.1.2 footer.
struct PaywallView: View {
    @ObservedObject private var subs = SubscriptionManager.shared
    @AppStorage("exitOfferShown") private var exitOfferShown = false
    @AppStorage("firstName") private var firstName = ""
    @Environment(\.dismiss) private var dismiss
    /// Opened from the hidden developer menu while subscribed: closable.
    var preview = false
    @State private var purchasing = false
    @State private var showingExitOffer = false
    @State private var storeUnavailable = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 10) {
                    LogoHero(size: 92)
                    Text(verbatim: "PEPLINE PRO")
                        .font(.caption.weight(.heavy))
                        .tracking(3)
                        .foregroundStyle(PLColor.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                // Personalised: the user just built their setup (endowment).
                (firstName.isEmpty ? Text("Everything to get every dose right.") : Text("Your Pepline is ready, \(firstName)."))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(PLColor.text)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    FeatureLine(symbol: "function", text: Text("Vial, water, dose: units on your syringe, exact.")).staggered(1)
                    FeatureLine(symbol: "list.bullet.clipboard", text: Text("Edit or delete anything. Export to CSV.")).staggered(2)
                    FeatureLine(symbol: "bell.badge", text: Text("Reminders for each dose and for reordering.")).staggered(3)
                    FeatureLine(symbol: "lock.shield", text: Text("No account. Your data stays on this iPhone.")).staggered(4)
                }

                VStack(spacing: 12) {
                    planCard(.yearly)
                    planCard(.monthly)
                }

                if let days = subs.trialDays(subs.selectedPlan) {
                    TrialTimeline(days: days, price: subs.price(subs.selectedPlan))
                }

                VStack(spacing: 10) {
                    Button(action: purchaseTapped) {
                        if purchasing {
                            ProgressView().tint(PLColor.onAccent)
                        } else {
                            Text(ctaTitle)
                        }
                    }
                    .buttonStyle(.primaryPill)
                    .disabled(purchasing)
                    if subs.trialDays(subs.selectedPlan) != nil {
                        Label("No payment now. Cancel anytime in two taps.", systemImage: "checkmark.shield.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(PLColor.text)
                    }
                }
                .frame(maxWidth: .infinity)

                PaywallFooter(plan: subs.selectedPlan)
            }
            .padding(20)
        }
        .background(OnboardingBackdrop())
        .overlay(alignment: .topTrailing) {
            if preview {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(PLColor.muted)
                }
                .padding(16)
                .accessibilityLabel(Text("Close"))
            }
        }
        .task {
            guard !preview else { return }
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

    /// Yearly shown per month (SOSA p22: framing the yearly plan as its
    /// monthly equivalent raised trial starts 30% with no loss in trial-to-
    /// paid), with the billed amount right under it in readable type, and
    /// again in the trial timeline and the 3.1.2 footer.
    private func planCard(_ plan: SubscriptionManager.Plan) -> some View {
        let selected = subs.selectedPlan == plan
        return Button { subs.selectedPlan = plan } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        (plan == .yearly ? Text("Yearly") : Text("Monthly"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PLColor.muted)
                        if plan == .yearly, let percent = subs.yearlySavingsPercent {
                            Text("Save \(percent.formatted(.percent))")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(PLColor.onAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(PLColor.accent, in: Capsule())
                        }
                    }
                    if plan == .yearly {
                        if let perMonth = subs.perMonth(.yearly) {
                            Text("Only \(perMonth) / month")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(selected ? PLColor.accent : PLColor.text)
                        }
                        if let price = subs.price(.yearly) {
                            Group {
                                if let days = subs.trialDays(.yearly) {
                                    Text("\(price) per year · \(String(days)) days free")
                                } else {
                                    Text("\(price) per year")
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PLColor.text)
                        }
                    } else {
                        if let price = subs.price(.monthly) {
                            Text("\(price) / month")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(PLColor.text)
                        }
                        Text("No free trial").font(.subheadline).foregroundStyle(PLColor.muted)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(selected ? PLColor.accent : PLColor.muted.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(18)
            .background(selected ? PLColor.accent.opacity(0.1) : PLColor.card,
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(selected ? PLColor.accent : PLColor.line, lineWidth: selected ? 2 : 1))
            .shadow(color: selected ? PLColor.accent.opacity(0.25) : .clear, radius: 16)
            .animation(.spring(duration: 0.3), value: selected)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
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
            if outcome == .cancelled, subs.selectedPlan == .yearly, !exitOfferShown || preview, subs.hasProduct(.exitOffer) {
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
