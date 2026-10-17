import AuthenticationServices
import StoreKit
import SwiftUI

/// The onboarding, close to PeptidePal's rhythm (research/competitor-
/// onboarding.md) but honest: every answer configures the app, every fact is
/// sourced (docs/SOURCES.md), no account is required, no dose is suggested.
struct OnboardingView: View {
    @EnvironmentObject private var store: DataStore
    @StateObject private var model = OnboardingModel()
    @AppStorage("onboardingDone") private var onboardingDone = false

    var body: some View {
        Group {
            switch model.step {
            case .welcome: WelcomeScreen(model: model)
            case .hello: StatementScreen(model: model, text: String(localized: "Welcome to Pepline."), symbol: "sparkles")
            case .name: NameScreen(model: model)
            case .greeting:
                StatementScreen(model: model, text: model.answers.trimmedName.isEmpty
                    ? String(localized: "Nice to meet you.")
                    : String(localized: "Nice to meet you, \(model.answers.trimmedName)."), symbol: "hand.wave.fill")
            case .goals: GoalsScreen(model: model)
            case .sameMath:
                StatementScreen(model: model, text: String(localized: "Whatever the goal, it comes down to one number: the units on your syringe."), symbol: "scope")
            case .facts: FactsScreen(model: model)
            case .experience: ExperienceScreen(model: model)
            case .experienceEcho:
                StatementScreen(model: model, text: [.new, .starting].contains(model.answers.experience)
                    ? String(localized: "Then let's do your first vial together, step by step.")
                    : String(localized: "Then you'll like having every vial and schedule in one place."), symbol: "point.3.connected.trianglepath.dotted")
            case .compounds: CompoundsScreen(model: model)
            case .troubles: TroublesScreen(model: model)
            case .troublesEcho: TroublesEchoScreen(model: model)
            case .syringe: SyringeScreen(model: model)
            case .weight: WeightScreen(model: model)
            case .decimalMistake: DecimalMistakeScreen(model: model)
            case .firstVial: FirstVialScreen(model: model)
            case .protocolOverview: OverviewScreen(model: model)
            case .reminders: RemindersScreen(model: model)
            case .account: AccountScreen(model: model)
            case .disclaimer: DisclaimerScreen(model: model)
            case .building: BuildingScreen(model: model)
            case .ahead: AheadScreen(model: model) { finish() }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.step)
    }

    private func finish() {
        // The paywall greets the user by name (kept on this iPhone only).
        UserDefaults.standard.set(model.answers.trimmedName, forKey: "firstName")
        model.finish(into: store)
        onboardingDone = true
    }
}

// MARK: - Screens

private struct WelcomeScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("Let's set up Pepline."),
                       subtitle: Text("A few quick questions so the app fits what you take."),
                       buttonTitle: Text("Let's go"),
                       hero: AnyView(LogoHero(size: 132).padding(.vertical, 24))) {
            VStack(alignment: .leading, spacing: 14) {
                FeatureLine(symbol: "1.circle.fill", text: Text("What you take")).staggered(2)
                FeatureLine(symbol: "2.circle.fill", text: Text("Your vial")).staggered(3)
                FeatureLine(symbol: "3.circle.fill", text: Text("Your reminders")).staggered(4)
            }
            .font(.title3.weight(.semibold))
            TrustChips().staggered(5)
        }
    }
}

/// Three promises the competitors break, under the welcome.
private struct TrustChips: View {
    var body: some View {
        HStack(spacing: 8) {
            chip("person.crop.circle.badge.xmark", Text("No account"))
            chip("cpu", Text("No AI"))
            chip("iphone", Text("On your iPhone"))
        }
    }

    private func chip(_ symbol: String, _ text: Text) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            text.lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(PLColor.text)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(PLColor.card, in: Capsule())
        .overlay(Capsule().strokeBorder(PLColor.line))
    }
}

private struct NameScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("What should we call you?"),
                       subtitle: Text("Only used inside the app, on this iPhone."),
                       buttonTitle: model.answers.trimmedName.isEmpty ? Text("Skip") : Text("Continue"),
                       hero: AnyView(PulseRings(symbol: "hand.wave.fill", size: 200))) {
            TextField("Your first name", text: $model.answers.name)
                .textContentType(.givenName)
                .font(.title2.weight(.semibold))
                .padding(18)
                .background(PLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(PLColor.accent.opacity(0.5)))
                .submitLabel(.continue)
                .onSubmit(model.advance)
                .staggered(2)
        }
    }
}

private struct GoalsScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("What are you taking peptides for?"),
                       subtitle: Text("Select all that apply.")) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(OnboardingAnswers.Goal.allCases.enumerated()), id: \.element) { index, goal in
                    ChoiceTile(symbol: goal.symbol, title: goal.title, selected: model.answers.goals.contains(goal)) {
                        model.answers.goals.formSymmetricDifference([goal])
                    }
                    .staggered(index + 2)
                }
            }
        }
    }
}

private struct FactsScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("Small numbers, big mistakes."),
                       subtitle: Text("What the FDA found in 2024."),
                       hero: AnyView(PulseRings(symbol: "exclamationmark.triangle.fill", size: 170))) {
            TabView {
                fact("5–20×", Text("Overdoses reported to the FDA after doses were drawn from vials with insulin syringes."))
                fact("5 → 50", Text("A 5-unit dose drawn as 50 units on a 1 ml syringe: one of the errors it describes."))
                fact("0.1 ml = 10", Text("On a U-100 insulin syringe, every unit is 0.01 ml."))
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(height: 280)
            .staggered(2)
            Text("Source: FDA alert on compounded semaglutide dosing errors, July 2024.")
                .font(.caption)
                .foregroundStyle(PLColor.muted)
        }
    }

    private func fact(_ number: String, _ text: Text) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: number)
                .plNumeral(size: 56)
                .foregroundStyle(PLColor.accent)
                .plGlow()
            text.font(.title3.weight(.medium)).foregroundStyle(PLColor.text)
            Spacer()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard()
        .padding(.bottom, 36)
    }
}

private struct ExperienceScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("How familiar are you with mixing vials?"),
                       hero: AnyView(PulseRings(symbol: "flask.fill", size: 170))) {
            ForEach(Array(OnboardingAnswers.Experience.allCases.enumerated()), id: \.element) { index, level in
                ChoiceCard(symbol: level.symbol, title: level.title, detail: level.detail,
                           selected: model.answers.experience == level) {
                    model.answers.experience = level
                }
                .staggered(index + 2)
            }
        }
    }
}

private struct CompoundsScreen: View {
    @ObservedObject var model: OnboardingModel
    @State private var other = ""

    var body: some View {
        QuestionScreen(model: model, title: Text("What do you use?"),
                       subtitle: Text("Pick all that apply, or add your own. You can change this later."),
                       buttonTitle: model.answers.compounds.isEmpty ? Text("Skip") : Text("Continue"),
                       hero: AnyView(PulseRings(symbol: "cross.vial.fill", size: 170))) {
            let names = CompoundPreset.all.map(\.name) + model.answers.compounds.filter { CompoundPreset.named($0) == nil }
            FlowLayout(spacing: 10) {
                ForEach(names, id: \.self) { name in
                    let selected = model.answers.compounds.contains(name)
                    Button {
                        if selected { model.answers.compounds.removeAll { $0 == name } } else { model.answers.compounds.append(name) }
                    } label: {
                        HStack(spacing: 6) {
                            if selected { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                            Text(verbatim: name)
                        }
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(selected ? PLColor.accent : PLColor.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(selected ? PLColor.accent : PLColor.line))
                        .foregroundStyle(selected ? PLColor.onAccent : PLColor.text)
                        .shadow(color: selected ? PLColor.accent.opacity(0.4) : .clear, radius: 8)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: selected)
                }
            }
            .staggered(2)
            HStack {
                TextField("Another compound", text: $other)
                    .textInputAutocapitalization(.words)
                    .onSubmit(add)
                Button("Add", action: add).disabled(other.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
            .plCard()
            .staggered(3)
        }
    }

    private func add() {
        let name = other.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !model.answers.compounds.contains(name) else { return }
        model.answers.compounds.append(name)
        other = ""
    }
}

private struct TroublesScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("What gets in your way?"),
                       subtitle: Text("Select all that apply."),
                       buttonTitle: model.answers.troubles.isEmpty ? Text("Skip") : Text("Continue")) {
            ForEach(Array(OnboardingAnswers.Trouble.allCases.enumerated()), id: \.element) { index, trouble in
                ChoiceCard(symbol: trouble.symbol, title: trouble.title,
                           selected: model.answers.troubles.contains(trouble)) {
                    model.answers.troubles.formSymmetricDifference([trouble])
                }
                .staggered(index + 2)
            }
        }
    }
}

private struct TroublesEchoScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        let troubles = model.answers.orderedTroubles.isEmpty
            ? OnboardingAnswers.Trouble.allCases : model.answers.orderedTroubles
        QuestionScreen(model: model, title: Text("Pepline handles that."),
                       hero: AnyView(PulseRings(symbol: "checkmark.shield.fill", size: 180))) {
            ForEach(Array(troubles.enumerated()), id: \.element) { index, trouble in
                FeatureLine(symbol: trouble.symbol, text: trouble.answer)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .plCard()
                    .staggered(index + 2)
            }
        }
    }
}

/// A syringe whose plunger moves on its own, for the syringe question.
private struct LiveSyringe: View {
    let syringe: SyringeModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 1 : timeline.date.timeIntervalSinceReferenceDate
            let share = 0.15 + 0.45 * (sin(t * 0.9) + 1) / 2
            SyringeView(syringe: syringe, units: syringe.capacityUnits * Decimal(share))
        }
        .padding(18)
        .plCard()
    }
}

private struct SyringeScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("Which syringes do you use?"),
                       subtitle: Text("Look at the box: size in ml and the smallest mark. You can change it for each vial."),
                       hero: AnyView(LiveSyringe(syringe: model.answers.syringe))) {
            ForEach(Array(SyringeModel.presets.enumerated()), id: \.element) { index, syringe in
                ChoiceCard(symbol: "syringe", title: Text(verbatim: syringe.label),
                           selected: model.answers.syringe == syringe) {
                    withAnimation(.spring) { model.answers.syringe = syringe }
                }
                .staggered(index + 2)
            }
        }
    }
}

/// A curve from today's weight down to the goal: an illustration of the
/// chart the app will draw, with no dates and no promise of speed.
private struct GoalCurveHero: View {
    @State private var drawn = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                var grid = Path()
                for row in 1...3 {
                    let y = size.height * CGFloat(row) / 4
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(PLColor.line), lineWidth: 1)
                var goal = Path()
                goal.move(to: CGPoint(x: 0, y: size.height * 0.82))
                goal.addLine(to: CGPoint(x: size.width, y: size.height * 0.82))
                context.stroke(goal, with: .color(PLColor.accent.opacity(0.5)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            CurveShape()
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(PLColor.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .plGlow()
            Text("Goal")
                .font(.caption.weight(.bold))
                .foregroundStyle(PLColor.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.bottom, 2)
        }
        .frame(height: 170)
        .padding(18)
        .plCard()
        .onAppear { withAnimation(.easeInOut(duration: 1.8)) { drawn = true } }
        .accessibilityHidden(true)
    }

    private struct CurveShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.12))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.8),
                          control1: CGPoint(x: rect.width * 0.35, y: rect.height * 0.2),
                          control2: CGPoint(x: rect.width * 0.55, y: rect.height * 0.78))
            return path
        }
    }
}

private struct WeightScreen: View {
    @ObservedObject var model: OnboardingModel
    @AppStorage(WeightUnitSetting.key) private var unitSetting = WeightUnitSetting.defaultValue
    @State private var nowText = ""
    @State private var goalText = ""

    private var unit: UnitMass { WeightUnitSetting.unit(unitSetting) }

    var body: some View {
        QuestionScreen(model: model, title: Text("Your weight"),
                       subtitle: Text("Pepline draws your curve from here. Stays on this iPhone."),
                       buttonTitle: nowText.isEmpty ? Text("Skip") : Text("Continue"),
                       onContinue: save,
                       hero: AnyView(GoalCurveHero())) {
            VStack(spacing: 14) {
                DecimalField(title: "Today", text: $nowText, unit: unit.symbol)
                DecimalField(title: "Goal", text: $goalText, unit: unit.symbol)
            }
            .padding(16)
            .plCard()
            .staggered(2)
        }
    }

    private func save() {
        model.answers.weightKg = decimalValue(nowText).map { Fmt.kilograms($0, from: unit) }
        model.answers.goalWeightKg = decimalValue(goalText).map { Fmt.kilograms($0, from: unit) }
        model.advance()
    }
}

/// The competitor's best screen, made exact: the same vial read right and
/// read one mark-group off, with units, ml and mcg.
private struct DecimalMistakeScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("One misread mark changes the dose."),
                       subtitle: Text("Example: a 5 mg vial mixed with 2 ml of water.")) {
            example(units: 10, label: Text("Right: 10 units · 0.1 ml · 250 mcg"), wrong: false).staggered(2)
            example(units: 15, label: Text("Misread: 15 units · 0.15 ml · 375 mcg (+50%)"), wrong: true).staggered(3)
            FeatureLine(symbol: "scope", text: Text("Pepline shows the exact mark for your vial, in units, ml and mcg."))
                .font(.headline)
                .staggered(4)
        }
    }

    private func example(units: Decimal, label: Text, wrong: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                label.font(.subheadline.bold())
            } icon: {
                Image(systemName: wrong ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(wrong ? PLColor.warning : PLColor.accent)
            }
            SyringeView(syringe: model.answers.syringe.capacityMl >= 1 ? .ml10 : .ml03, units: units)
        }
        .padding(16)
        .plCard()
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(wrong ? PLColor.warning.opacity(0.5) : PLColor.accent.opacity(0.5)))
    }
}

private struct FirstVialScreen: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject private var calculator: CalculatorModel
    @Environment(\.requestReview) private var requestReview
    @AppStorage("reviewRequested") private var reviewRequested = false

    init(model: OnboardingModel) {
        self.model = model
        calculator = model.calculator
    }

    var body: some View {
        QuestionScreen(model: model, title: Text("Your vial"),
                       subtitle: Text("Enter the dose your prescriber gave you. Pepline does the math; it never suggests a dose."),
                       buttonTitle: calculator.draw == nil ? Text("Skip for now") : Text("Continue")) {
            VStack(spacing: 14) {
                if !model.answers.compounds.isEmpty {
                    Picker("Compound", selection: $model.vialCompound) {
                        ForEach(model.answers.compounds, id: \.self) { Text(verbatim: $0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DecimalField(title: "Powder in the vial", text: $calculator.vialText, unit: "mg")
                DecimalField(title: "Bacteriostatic water", text: $calculator.waterText, unit: "ml")
                DecimalField(title: "Dose", text: $calculator.doseText)
                Picker("Unit", selection: $calculator.doseUnit) {
                    Text(verbatim: "mcg").tag(DoseUnit.mcg)
                    Text(verbatim: "mg").tag(DoseUnit.mg)
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .plCard()
            .staggered(2)

            if let draw = calculator.draw, let reconstitution = calculator.reconstitution, let dose = calculator.dose {
                ResultCard(draw: draw, syringe: calculator.syringe, reconstitution: reconstitution, dose: dose)
                    .padding(16)
                    .plCard()
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .task {
                        // Rating prompt right after the first real result: the
                        // user has seen the value (decision 2026-10-15).
                        guard !reviewRequested else { return }
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        reviewRequested = true
                        requestReview()
                        Analytics.track(.reviewRequested, ["where": "onboardingVial"])
                    }
            } else {
                HStack(spacing: 14) {
                    PulseRings(symbol: "function", size: 90)
                    Text("Your result appears here, drawn on your syringe.")
                        .font(.headline)
                        .foregroundStyle(PLColor.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .plCard()
            }
        }
        .animation(.spring(duration: 0.5), value: calculator.draw != nil)
    }
}

private struct OverviewScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("Your whole protocol, in one place."),
                       hero: AnyView(LogoHero(size: 96).padding(.vertical, 12))) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                tile("syringe", Text("Calculator"), Text("Every vial saved, with the exact mark.")).staggered(2)
                tile("list.bullet.rectangle", Text("Journal"), Text("Each dose with its site, side and notes. Edit anything.")).staggered(3)
                tile("calendar", Text("Schedules"), Text("Daily, every other day, weekdays or on/off cycles.")).staggered(4)
                tile("chart.xyaxis.line", Text("Weight"), Text("Your curve, in kg or lb.")).staggered(5)
            }
        }
    }

    private func tile(_ symbol: String, _ title: Text, _ detail: Text) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(PLColor.accent)
                .frame(width: 48, height: 48)
                .background(PLColor.accent.opacity(0.12), in: Circle())
            title.font(.headline).foregroundStyle(PLColor.text)
            detail.font(.footnote).foregroundStyle(PLColor.muted).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .padding(14)
        .plCard()
    }
}

/// A lock-screen notification that slides in, so the user sees what the
/// reminder will look like before granting permission.
private struct NotificationPreview: View {
    let compound: String
    @State private var shown = false

    var body: some View {
        VStack(spacing: 22) {
            PulseRings(symbol: "bell.fill", size: 110)
            banner
        }
    }

    private var banner: some View {
        HStack(spacing: 12) {
            Image("Logo")
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: "Pepline").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("now").font(.caption).foregroundStyle(PLColor.muted)
                }
                Text("Scheduled dose: \(compound)").font(.subheadline)
            }
            .foregroundStyle(PLColor.text)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(PLColor.line))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .offset(y: shown ? 0 : -40)
        .opacity(shown ? 1 : 0)
        .frame(maxWidth: .infinity)
        .onAppear { withAnimation(.spring(duration: 0.7).delay(0.4)) { shown = true } }
        .sensoryFeedback(.success, trigger: shown)
    }
}

private struct RemindersScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("Never miss a dose."),
                       subtitle: model.reminderDose == nil
                           ? Text("Turn on notifications now; you'll set your schedules in the app.")
                           : Text("Pick when you take it. You can add more schedules later."),
                       buttonTitle: Text("Turn on reminders"),
                       secondary: (title: Text("Not now"), action: { model.advance() }),
                       onContinue: turnOn,
                       hero: AnyView(NotificationPreview(compound: model.vialCompound.isEmpty
                                                         ? (model.answers.compounds.first ?? "Pepline") : model.vialCompound))) {
            if model.reminderDose != nil {
                VStack(spacing: 14) {
                    Picker("Repeat", selection: $model.reminderRhythm) {
                        ForEach(ReminderRhythm.allCases, id: \.self) { Text(verbatim: $0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Time", selection: $model.reminderTime, displayedComponents: .hourAndMinute)
                }
                .padding(16)
                .plCard()
                .staggered(2)
            }
        }
    }

    private func turnOn() {
        Task {
            let granted = await NotificationScheduler.shared.requestPermission()
            Analytics.track(.notificationPermission, ["result": granted ? "granted" : "denied"])
            model.remindersOn = granted
            model.advance()
        }
    }
}

private struct AccountScreen: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject private var account = AppleAccount.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        QuestionScreen(model: model, title: Text("Keep Pro with your Apple ID"),
                       subtitle: Text("Optional. Your subscription follows you to a new iPhone. Your journal stays on this one."),
                       buttonTitle: account.isSignedIn ? Text("Continue") : Text("Not now"),
                       hero: AnyView(PulseRings(symbol: "apple.logo", size: 190))) {
            if account.isSignedIn {
                Label("Signed in with Apple", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(PLColor.text)
            } else {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    Task {
                        await account.handle(result)
                        if account.isSignedIn { model.advance() }
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .staggered(2)
            }
            Text("No password, no email shared, no data uploaded.")
                .font(.footnote)
                .foregroundStyle(PLColor.muted)
        }
    }
}

private struct DisclaimerScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("One last thing."),
                       buttonTitle: Text("I understand"),
                       hero: AnyView(PulseRings(symbol: "stethoscope", size: 190))) {
            Text("Pepline converts the dose your prescriber set into units on your syringe. It never recommends a dose, and it does not replace your doctor.")
                .font(.title3.weight(.medium))
                .foregroundStyle(PLColor.text)
                .staggered(2)
        }
    }
}

/// The setup being written, step by step, with a filling ring. Every line
/// is something `finish(into:)` really does with the user's answers.
private struct BuildingScreen: View {
    @ObservedObject var model: OnboardingModel
    @State private var done = 0

    private var steps: [Text] {
        var steps: [Text] = []
        if !model.answers.compounds.isEmpty || !model.vialCompound.isEmpty {
            steps.append(Text("Adding your compounds"))
        }
        steps.append(Text("Setting your syringe: \(model.answers.syringe.label)"))
        if model.calculator.reconstitution != nil { steps.append(Text("Saving your vial and its exact mark")) }
        if model.remindersOn && model.reminderDose != nil { steps.append(Text("Scheduling your reminders")) }
        if model.answers.asksWeight && model.answers.weightKg != nil { steps.append(Text("Starting your weight curve")) }
        steps.append(Text("Preparing your journal"))
        return steps
    }

    var body: some View {
        let steps = self.steps
        let progress = steps.isEmpty ? 1 : Double(done) / Double(steps.count)
        QuestionScreen(model: model, title: Text("Setting up your Pepline…"),
                       buttonTitle: done < steps.count ? Text("One moment…") : Text("Continue"),
                       hero: AnyView(
                        ZStack {
                            Circle().stroke(PLColor.accent.opacity(0.12), lineWidth: 10)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(PLColor.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .plGlow()
                            Text(verbatim: (progress).formatted(.percent.precision(.fractionLength(0))))
                                .plNumeral(size: 44)
                                .foregroundStyle(PLColor.accent)
                                .contentTransition(.numericText())
                        }
                        .frame(width: 180, height: 180)
                        .padding(.vertical, 10)
                        .animation(.easeInOut(duration: 0.5), value: done))) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        Image(systemName: index < done ? "checkmark.circle.fill" : "circle.dotted")
                            .font(.title3)
                            .foregroundStyle(index < done ? PLColor.accent : PLColor.muted)
                            .contentTransition(.symbolEffect(.replace))
                        step.font(.headline).foregroundStyle(index < done ? PLColor.text : PLColor.muted)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .plCard()
        }
        .disabled(done < steps.count)
        .sensoryFeedback(.success, trigger: done)
        .task {
            for index in 1...max(steps.count, 1) {
                try? await Task.sleep(nanoseconds: 650_000_000)
                withAnimation { done = index }
            }
        }
    }
}

/// Personalised summary before the paywall: everything the user set up is
/// already here (endowment), then the trial timeline.
private struct AheadScreen: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject private var subs = SubscriptionManager.shared
    let onFinish: () -> Void

    private var compounds: String {
        let names = model.answers.compounds + (model.vialCompound.isEmpty || model.answers.compounds.contains(model.vialCompound)
                                              ? [] : [model.vialCompound])
        return names.joined(separator: ", ")
    }

    var body: some View {
        let days = subs.trialDays(.yearly) ?? 7
        let name = model.answers.trimmedName
        QuestionScreen(model: model,
                       title: name.isEmpty ? Text("Your Pepline is ready.") : Text("Your Pepline is ready, \(name)."),
                       onContinue: onFinish,
                       hero: AnyView(LogoHero(size: 100).padding(.vertical, 10))) {
            VStack(alignment: .leading, spacing: 14) {
                if !compounds.isEmpty {
                    FeatureLine(symbol: "cross.vial.fill", text: Text(verbatim: compounds)).staggered(2)
                }
                FeatureLine(symbol: "syringe", text: Text(verbatim: model.answers.syringe.label)).staggered(3)
                if let draw = model.calculator.draw {
                    FeatureLine(symbol: "scope", text: Text("Draw to \(Fmt.number(draw.units)) units")).staggered(4)
                }
                if model.remindersOn && model.reminderDose != nil {
                    FeatureLine(symbol: "bell.fill", text: Text("Today: your reminders are set.")).staggered(5)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .plCard()

            VStack(alignment: .leading, spacing: 14) {
                FeatureLine(symbol: "lock.open.fill", text: Text("Today: \(String(days)) days of Pepline Pro, free."))
                FeatureLine(symbol: "bell.badge", text: Text("Day \(String(max(days - 2, 1))): we remind you before the trial ends."))
                FeatureLine(symbol: "creditcard", text: Text("Day \(String(days)): your subscription starts, unless you cancel."))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .plCard()
            .staggered(6)
        }
    }
}

// MARK: - Wording of the answers

extension OnboardingAnswers.Goal {
    var title: Text {
        switch self {
        case .weightLoss: return Text("Lose weight (GLP-1)")
        case .buildRecover: return Text("Build muscle and recover")
        case .heal: return Text("Heal an injury")
        case .skinHair: return Text("Skin and hair")
        case .sleep: return Text("Sleep better")
        case .longevity: return Text("Longevity")
        case .other: return Text("Something else")
        }
    }

    var symbol: String {
        switch self {
        case .weightLoss: return "scalemass"
        case .buildRecover: return "figure.strengthtraining.traditional"
        case .heal: return "bandage"
        case .skinHair: return "sparkles"
        case .sleep: return "moon.zzz"
        case .longevity: return "leaf"
        case .other: return "ellipsis.circle"
        }
    }
}

extension OnboardingAnswers.Experience {
    var symbol: String {
        switch self {
        case .new: return "leaf.fill"
        case .starting: return "figure.walk"
        case .experienced: return "checkmark.seal.fill"
        case .multiple: return "square.stack.3d.up.fill"
        }
    }

    var title: Text {
        switch self {
        case .new: return Text("Brand new")
        case .starting: return Text("Getting started")
        case .experienced: return Text("Comfortable")
        case .multiple: return Text("Advanced")
        }
    }

    var detail: Text {
        switch self {
        case .new: return Text("I haven't mixed a vial yet.")
        case .starting: return Text("I've mixed a few vials.")
        case .experienced: return Text("I mix my own vials regularly.")
        case .multiple: return Text("I run several compounds at once.")
        }
    }
}

extension OnboardingAnswers.Trouble {
    var title: Text {
        switch self {
        case .reconstitution: return Text("Reconstitution math")
        case .readingSyringe: return Text("Reading the syringe")
        case .remembering: return Text("Remembering my doses")
        case .rotatingSites: return Text("Rotating injection sites")
        case .runningOut: return Text("Running out of a vial")
        case .doctorLog: return Text("Keeping a log for my doctor")
        }
    }

    /// The mirrored line on "Pepline handles that".
    var answer: Text {
        switch self {
        case .reconstitution: return Text("Exact units for any vial, water and dose. Decimals included.")
        case .readingSyringe: return Text("Your syringe drawn to scale, filled to the mark.")
        case .remembering: return Text("A reminder for every scheduled dose.")
        case .rotatingSites: return Text("Every site and side logged, the last one shown.")
        case .runningOut: return Text("The date your vial runs out, and a reminder to reorder.")
        case .doctorLog: return Text("A clean CSV export of every dose.")
        }
    }

    var symbol: String {
        switch self {
        case .reconstitution: return "function"
        case .readingSyringe: return "syringe"
        case .remembering: return "bell"
        case .rotatingSites: return "figure.stand"
        case .runningOut: return "shippingbox"
        case .doctorLog: return "doc.text"
        }
    }
}

extension ReminderRhythm {
    var title: String {
        switch self {
        case .daily: return String(localized: "Every day")
        case .everyOtherDay: return String(localized: "Every other day")
        case .weekly: return String(localized: "Weekly")
        }
    }
}

/// Wrapping row of chips (iOS 16 Layout).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
