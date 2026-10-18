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
    /// How a preview closes when it is not a sheet (after a replayed onboarding).
    var onClose: (() -> Void)?
    @State private var purchasing = false
    @State private var showingExitOffer = false
    @State private var storeUnavailable = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // One screen, no scrolling (decision 2026-10-17): everything needed to
        // decide is in view at once. Small phones (SE) fall back to a scroll
        // rather than cutting anything 3.1.2 requires.
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
        .background(OnboardingBackdrop())
        .overlay(alignment: .topTrailing) {
            if preview {
                Button { (onClose ?? { dismiss() })() } label: {
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

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image("Logo")
                    .resizable()
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: PLColor.accent.opacity(0.4), radius: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "PEPLINE PRO")
                        .font(.caption2.weight(.heavy))
                        .tracking(2.5)
                        .foregroundStyle(PLColor.accent)
                    // Personalised: the user just built their setup (endowment).
                    (firstName.isEmpty ? Text("Everything to get every dose right.") : Text("Your Pepline is ready, \(firstName)."))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PLColor.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 11) {
                benefit("function", Text("Vial, water, dose: units on your syringe, exact.")).staggered(1)
                benefit("list.bullet.clipboard", Text("Edit or delete anything. Export to CSV.")).staggered(2)
                benefit("bell.badge", Text("Reminders for each dose and for reordering.")).staggered(3)
                benefit("lock.shield", Text("No account. Your data stays on this iPhone.")).staggered(4)
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                planCard(.yearly)
                planCard(.monthly)
            }

            if let days = subs.trialDays(subs.selectedPlan) {
                TrialTimeline(days: days, price: subs.price(subs.selectedPlan))
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PLColor.text)
                }
            }
            .frame(maxWidth: .infinity)

            PaywallFooter(plan: subs.selectedPlan)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func benefit(_ symbol: String, _ text: Text) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PLColor.accent)
                .frame(width: 32, height: 32)
                .background(PLColor.accent.opacity(0.12), in: Circle())
            text.font(.body).foregroundStyle(PLColor.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
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
                VStack(alignment: .leading, spacing: 4) {
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
                                .font(.title.weight(.heavy))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
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
                            .font(.body.weight(.semibold))
                            .foregroundStyle(PLColor.text)
                        }
                    } else {
                        if let price = subs.price(.monthly) {
                            // No "no free trial" line: the trial badge, the
                            // timeline and the CTA already say it (decision
                            // 2026-10-18).
                            Text("\(price) / month")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(PLColor.text)
                        }
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(selected ? PLColor.accent : PLColor.muted.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
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
            // Closing Apple's sheet on either plan opens the exit offer, once
            // per install (the competitor's pattern the user liked).
            if outcome == .cancelled, !exitOfferShown || preview, subs.hasProduct(.exitOffer) {
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
    /// The user picks the reminder day (Duolingo: the choice built trust and
    /// raised conversion, SOSA 2026 p78). Read again at purchase time.
    @AppStorage("trialReminderDay") private var reminderDay = 0

    private var chosenDay: Int { reminderDay > 0 ? min(reminderDay, max(days - 1, 1)) : max(days - 2, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            step("lock.open.fill", Text("Today"), Text("Full access. Nothing to pay now."))
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "bell.fill").font(.subheadline).foregroundStyle(PLColor.accent).frame(width: 22)
                Menu {
                    ForEach(1..<max(days, 2), id: \.self) { day in
                        Button { reminderDay = day } label: { Text("Day \(String(day))") }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text("Day \(String(chosenDay))").bold().foregroundStyle(PLColor.accent)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(PLColor.accent)
                    }
                }
                (Text(verbatim: "· ") + Text("We remind you that your trial ends soon."))
                    .foregroundStyle(PLColor.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline)
            .accessibilityElement(children: .contain)
            step("creditcard.fill", Text("Day \(String(days))"),
                 price.map { Text("You're billed \($0) unless you cancel before.") }
                     ?? Text("Your subscription starts unless you cancel before."))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PLColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func step(_ symbol: String, _ title: Text, _ detail: Text) -> some View {
        // One line per step: "Today · Full access. Nothing to pay now."
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).font(.subheadline).foregroundStyle(PLColor.accent).frame(width: 22)
            (title.bold().foregroundColor(PLColor.text) + Text(verbatim: " · ") + detail.foregroundColor(PLColor.muted))
                .font(.subheadline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Guideline 3.1.2: title, length, price and auto-renewal, plus Restore,
/// Privacy and Terms, legible.
struct PaywallFooter: View {
    @ObservedObject private var subs = SubscriptionManager.shared
    let plan: SubscriptionManager.Plan
    @State private var restoreResult: Bool??

    static let privacyURL = URL(string: "https://0xcssh.github.io/pepline-legal/privacy.html")!
    static let termsURL = URL(string: "https://0xcssh.github.io/pepline-legal/terms.html")!

    var body: some View {
        VStack(spacing: 6) {
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
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 22) {
                Link(destination: Self.privacyURL) { Text("Privacy") }
                Button { Task { restoreResult = .some(await subs.restore()) } } label: { Text("Restore Purchases") }
                Link(destination: Self.termsURL) { Text("Terms") }
            }
            .font(.subheadline)
            .foregroundStyle(PLColor.text)
        }
        .frame(maxWidth: .infinity)
        // Restore always answers: found, nothing to restore, or offline.
        .alert(isPresented: Binding(get: { restoreResult != nil }, set: { if !$0 { restoreResult = nil } })) {
            switch restoreResult {
            case .some(.some(true)):
                return Alert(title: Text("Pepline Pro is restored."))
            case .some(.some(false)):
                return Alert(title: Text("No subscription to restore"),
                             message: Text("No active Pepline Pro was found for this Apple ID."))
            default:
                return Alert(title: Text("Couldn't reach the App Store"), message: Text("Check your connection and try again."))
            }
        }
    }
}
