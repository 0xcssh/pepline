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
            case .hello: StatementScreen(model: model, text: String(localized: "Welcome to Pepline."))
            case .name: NameScreen(model: model)
            case .greeting:
                StatementScreen(model: model, text: model.answers.trimmedName.isEmpty
                    ? String(localized: "Nice to meet you.")
                    : String(localized: "Nice to meet you, \(model.answers.trimmedName)."))
            case .goals: GoalsScreen(model: model)
            case .sameMath:
                StatementScreen(model: model, text: String(localized: "Whatever the goal, it comes down to one number: the units on your syringe."))
            case .facts: FactsScreen(model: model)
            case .experience: ExperienceScreen(model: model)
            case .experienceEcho:
                StatementScreen(model: model, text: [.new, .starting].contains(model.answers.experience)
                    ? String(localized: "Then let's do your first vial together, step by step.")
                    : String(localized: "Then you'll like having every vial and schedule in one place."))
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
            case .ahead: AheadScreen(model: model) { finish() }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.step)
    }

    private func finish() {
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
                       buttonTitle: Text("Let's go")) {
            VStack(alignment: .leading, spacing: 14) {
                FeatureLine(symbol: "1.circle.fill", text: Text("What you take"))
                FeatureLine(symbol: "2.circle.fill", text: Text("Your vial"))
                FeatureLine(symbol: "3.circle.fill", text: Text("Your reminders"))
            }
            .font(.title3)
            .padding(.top, 12)
        }
    }
}

private struct NameScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("What should we call you?"),
                       subtitle: Text("Only used inside the app, on this iPhone."),
                       buttonTitle: model.answers.trimmedName.isEmpty ? Text("Skip") : Text("Continue")) {
            TextField("Your first name", text: $model.answers.name)
                .textContentType(.givenName)
                .font(.title3)
                .padding(16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                .submitLabel(.continue)
                .onSubmit(model.advance)
        }
    }
}

private struct GoalsScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("What are you taking peptides for?"),
                       subtitle: Text("Select all that apply.")) {
            ForEach(OnboardingAnswers.Goal.allCases, id: \.self) { goal in
                ChoiceCard(symbol: goal.symbol, title: goal.title, selected: model.answers.goals.contains(goal)) {
                    model.answers.goals.formSymmetricDifference([goal])
                }
            }
        }
    }
}

private struct FactsScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("Small numbers, big mistakes."),
                       subtitle: Text("What the FDA found in 2024.")) {
            TabView {
                fact("5–20×", Text("Overdoses reported to the FDA after doses were drawn from vials with insulin syringes."))
                fact("5 → 50", Text("A 5-unit dose drawn as 50 units on a 1 ml syringe: one of the errors it describes."))
                fact("0.1 ml = 10", Text("On a U-100 insulin syringe, every unit is 0.01 ml."))
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(height: 300)
            Text("Source: FDA alert on compounded semaglutide dosing errors, July 2024.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func fact(_ number: String, _ text: Text) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: number)
                .plNumeral(size: 52)
                .foregroundStyle(PLColor.navy)
            text.font(.title3).foregroundStyle(PLColor.navy)
            Spacer()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
        .padding(.bottom, 36)
    }
}

private struct ExperienceScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("How familiar are you with mixing vials?")) {
            ForEach(OnboardingAnswers.Experience.allCases, id: \.self) { level in
                ChoiceCard(symbol: nil, title: level.title, detail: level.detail,
                           selected: model.answers.experience == level) {
                    model.answers.experience = level
                }
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
                       buttonTitle: model.answers.compounds.isEmpty ? Text("Skip") : Text("Continue")) {
            let names = CompoundPreset.all.map(\.name) + model.answers.compounds.filter { CompoundPreset.named($0) == nil }
            FlowLayout(spacing: 8) {
                ForEach(names, id: \.self) { name in
                    let selected = model.answers.compounds.contains(name)
                    Button {
                        if selected { model.answers.compounds.removeAll { $0 == name } } else { model.answers.compounds.append(name) }
                    } label: {
                        Text(verbatim: name)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(selected ? PLColor.navy : Color.white, in: Capsule())
                            .foregroundStyle(selected ? Color.white : PLColor.navy)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("Another compound", text: $other)
                    .textInputAutocapitalization(.words)
                    .onSubmit(add)
                Button("Add", action: add).disabled(other.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
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
            ForEach(OnboardingAnswers.Trouble.allCases, id: \.self) { trouble in
                ChoiceCard(symbol: trouble.symbol, title: trouble.title,
                           selected: model.answers.troubles.contains(trouble)) {
                    model.answers.troubles.formSymmetricDifference([trouble])
                }
            }
        }
    }
}

private struct TroublesEchoScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        let troubles = model.answers.orderedTroubles.isEmpty
            ? OnboardingAnswers.Trouble.allCases : model.answers.orderedTroubles
        QuestionScreen(model: model, title: Text("Pepline handles that.")) {
            ForEach(troubles, id: \.self) { trouble in
                FeatureLine(symbol: trouble.symbol, text: trouble.answer)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

private struct SyringeScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("Which syringes do you use?"),
                       subtitle: Text("Look at the box: size in ml and the smallest mark. You can change it for each vial.")) {
            ForEach(SyringeModel.presets, id: \.self) { syringe in
                ChoiceCard(symbol: "syringe", title: Text(verbatim: syringe.label),
                           selected: model.answers.syringe == syringe) {
                    model.answers.syringe = syringe
                }
            }
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
                       onContinue: save) {
            VStack(spacing: 14) {
                DecimalField(title: "Today", text: $nowText, unit: unit.symbol)
                DecimalField(title: "Goal", text: $goalText, unit: unit.symbol)
            }
            .padding(16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
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
            example(units: 10, label: Text("Right: 10 units · 0.1 ml · 250 mcg"), wrong: false)
            example(units: 15, label: Text("Misread: 15 units · 0.15 ml · 375 mcg (+50%)"), wrong: true)
            Text("Pepline shows the exact mark for your vial, in units, ml and mcg.")
                .font(.headline)
                .foregroundStyle(PLColor.navy)
        }
    }

    private func example(units: Decimal, label: Text, wrong: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                label.font(.subheadline.bold())
            } icon: {
                Image(systemName: wrong ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(wrong ? Color.orange : Color.green)
            }
            SyringeView(syringe: model.answers.syringe.capacityMl >= 1 ? .ml10 : .ml03, units: units)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
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
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))

            if let draw = calculator.draw, let reconstitution = calculator.reconstitution, let dose = calculator.dose {
                ResultCard(draw: draw, syringe: calculator.syringe, reconstitution: reconstitution, dose: dose)
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                    .task {
                        // Rating prompt right after the first real result: the
                        // user has seen the value (decision 2026-10-15).
                        guard !reviewRequested else { return }
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        reviewRequested = true
                        requestReview()
                        Analytics.track(.reviewRequested, ["where": "onboardingVial"])
                    }
            }
        }
    }
}

private struct OverviewScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("Your whole protocol, in one place.")) {
            card("syringe", Text("Calculator"), Text("Every vial saved, with the exact mark."))
            card("list.bullet.rectangle", Text("Journal"), Text("Each dose with its site, side and notes. Edit anything."))
            card("calendar", Text("Schedules"), Text("Daily, every other day, weekdays or on/off cycles."))
            card("chart.xyaxis.line", Text("Weight"), Text("Your curve, in kg or lb."))
        }
    }

    private func card(_ symbol: String, _ title: Text, _ detail: Text) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(PLColor.navy).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                title.font(.headline).foregroundStyle(PLColor.navy)
                detail.font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
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
                       onContinue: turnOn) {
            if model.reminderDose != nil {
                VStack(spacing: 14) {
                    Picker("Repeat", selection: $model.reminderRhythm) {
                        ForEach(ReminderRhythm.allCases, id: \.self) { Text(verbatim: $0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Time", selection: $model.reminderTime, displayedComponents: .hourAndMinute)
                }
                .padding(16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
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

    var body: some View {
        QuestionScreen(model: model, title: Text("Keep Pro with your Apple ID"),
                       subtitle: Text("Optional. Your subscription follows you to a new iPhone. Your journal stays on this one."),
                       buttonTitle: account.isSignedIn ? Text("Continue") : Text("Not now")) {
            if account.isSignedIn {
                Label("Signed in with Apple", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(PLColor.navy)
            } else {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    Task {
                        await account.handle(result)
                        if account.isSignedIn { model.advance() }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
            }
            Text("No password, no email shared, no data uploaded.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DisclaimerScreen: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        QuestionScreen(model: model, title: Text("One last thing."),
                       buttonTitle: Text("I understand")) {
            Text("Pepline converts the dose your prescriber set into units on your syringe. It never recommends a dose, and it does not replace your doctor.")
                .font(.title3)
                .foregroundStyle(PLColor.navy)
        }
    }
}

private struct AheadScreen: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject private var subs = SubscriptionManager.shared
    let onFinish: () -> Void

    var body: some View {
        let days = subs.trialDays(.yearly) ?? 7
        QuestionScreen(model: model, title: Text("Here's what's ahead."), onContinue: onFinish) {
            VStack(alignment: .leading, spacing: 16) {
                if model.calculator.reconstitution != nil {
                    FeatureLine(symbol: "checkmark.circle.fill", text: Text("Today: your vial is saved, with its exact mark."))
                }
                if model.remindersOn && model.reminderDose != nil {
                    FeatureLine(symbol: "bell.fill", text: Text("Today: your reminders are set."))
                }
                FeatureLine(symbol: "lock.open.fill", text: Text("Today: \(String(days)) days of Pepline Pro, free."))
                FeatureLine(symbol: "bell.badge", text: Text("Day \(String(max(days - 2, 1))): we remind you before the trial ends."))
                FeatureLine(symbol: "creditcard", text: Text("Day \(String(days)): your subscription starts, unless you cancel."))
            }
            .padding(16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
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
