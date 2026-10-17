import Charts
import SwiftUI
import TipKit

/// The daily screen, built around one action (SOSA 2026 p116: build the
/// loop around the result five-star reviews reward): know what to draw,
/// inject, log it in one tap, see the week move. Then nutrition, the week's
/// recap, the estimated level and the vial.
struct TodayView: View {
    @EnvironmentObject private var store: DataStore
    @AppStorage("firstName") private var firstName = ""
    @AppStorage(WeightUnitSetting.key) private var unitSetting = WeightUnitSetting.defaultValue
    @State private var logging: DoseEditor.Draft?
    @State private var reward: DoseReward?
    @State private var addingSideEffect = false
    @State private var addingWeight = false
    @State private var now = Date()

    private var journal: Journal { store.journal }
    private var calendar: Calendar { .current }
    private var unit: UnitMass { WeightUnitSetting.unit(unitSetting) }

    private var todayDoses: [ScheduledDose] {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start)!
        return Adherence.doses(in: journal, from: start, through: end, now: now, calendar: calendar)
    }

    /// The next dose still to take: one already logged early is not "next".
    private var nextDose: (scheduled: ScheduledDose, regimen: Regimen)? {
        Adherence.upcoming(in: journal, now: now, calendar: calendar, limit: 1).first.flatMap { scheduled in
            journal.regimens.first { $0.id == scheduled.regimenID }.map { (scheduled, $0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if journal.activeRegimens.isEmpty {
                    emptyState
                } else {
                    TipView(InjectTip())
                        .tipBackground(PLColor.card)
                    heroCard
                    if todayDoses.count > 1 || todayDoses.contains(where: { $0.status == .missed || isSkipped($0) }) {
                        todayCard
                    }
                }
                NutritionGlance()
                recapCard
                levelCard
                vialCard
                quickActions
            }
            .padding(20)
        }
        .background(PLBackground())
        .navigationTitle(Text("Today"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $logging) { DoseEditor(draft: $0) }
        .sheet(item: $reward) { reward in
            DoseLoggedView(starCount: reward.stars, summary: reward.summary, dosesLeft: reward.dosesLeft,
                           next: reward.next) { self.reward = nil }
        }
        .sheet(isPresented: $addingSideEffect) { SideEffectSheet() }
        .sheet(isPresented: $addingWeight) { WeightEditor(draft: WeightEditor.Draft(), unit: unit) }
        .task {
            // Keep the countdown and "upcoming → missed" states fresh.
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: now.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PLColor.muted)
            greeting
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(PLColor.text)
        }
    }

    private var greeting: Text {
        let hour = calendar.component(.hour, from: now)
        let name = firstName.trimmingCharacters(in: .whitespaces)
        switch (hour, name.isEmpty) {
        case (5..<12, true): return Text("Good morning")
        case (5..<12, false): return Text("Good morning, \(name)")
        case (12..<18, true): return Text("Good afternoon")
        case (12..<18, false): return Text("Good afternoon, \(name)")
        case (_, true): return Text("Good evening")
        case (_, false): return Text("Good evening, \(name)")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            PulseRings(symbol: "calendar.badge.plus", size: 110)
            Text("Add the schedule your prescriber gave you to see your doses here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(PLColor.text)
            NavigationLink { SchedulesView() } label: { Text("Add a schedule") }
                .buttonStyle(.primaryPill)
        }
        .frame(maxWidth: .infinity)
        .plCard()
    }

    // MARK: Hero: the next dose and the one-tap log

    @ViewBuilder
    private var heroCard: some View {
        if let next = nextDose {
            let due = next.scheduled.date <= now
            let units = NotificationScheduler.unitsToDraw(next.regimen, in: journal)
            let syringe = latestVial(next.regimen)?.syringe
            let zone = SiteRotation.leastRecent(lastUse: SiteRotation.lastUse(in: journal))
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: compoundName(next.regimen.compoundID) + " · " + Fmt.dose(next.regimen.dose))
                        .font(.headline)
                        .foregroundStyle(PLColor.text)
                    Spacer()
                    Group {
                        if due {
                            Text("Due now").foregroundStyle(PLColor.warning)
                        } else if calendar.isDate(next.scheduled.date, inSameDayAs: now) {
                            Text(next.scheduled.date, style: .relative).foregroundStyle(PLColor.muted)
                        } else {
                            Text(next.scheduled.date, format: .dateTime.weekday(.abbreviated).hour().minute())
                                .foregroundStyle(PLColor.muted)
                        }
                    }
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                if let units {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Draw to").font(.subheadline).foregroundStyle(PLColor.muted)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(verbatim: Fmt.units(units))
                                .plNumeral(size: 56)
                                .foregroundStyle(PLColor.accent)
                                .plGlow()
                            Text("units").font(.title3.weight(.semibold)).foregroundStyle(PLColor.text)
                        }
                    }
                    if let syringe {
                        SyringeView(syringe: syringe, units: units).frame(height: 64)
                    }
                } else {
                    NavigationLink { CalculatorView() } label: {
                        Label { Text("Save your vial to see the units to draw here.") } icon: { Image(systemName: "flask") }
                            .font(.subheadline)
                    }
                }
                Label { Text("Most rested site: \(Fmt.site(zone.site, zone.side))") } icon: {
                    Image(systemName: "figure.stand")
                }
                .font(.footnote)
                .foregroundStyle(PLColor.muted)

                Button { quickLog(next.regimen, slot: next.scheduled.date) } label: {
                    Label { Text("I injected") } icon: { Image(systemName: "checkmark.circle.fill") }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryPill)
                HStack {
                    Button {
                        logging = DoseEditor.Draft(regimen: next.regimen, journal: journal,
                                                   date: QuickLog.date(forSlot: next.scheduled.date, now: now))
                    } label: { Text("Log with details") }
                    Spacer()
                    Button { skip(next.scheduled) } label: { Text("Skip this dose") }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PLColor.muted)
            }
            .plCard()
        } else {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(PLColor.accent).plGlow()
                Text("All caught up").font(.headline).foregroundStyle(PLColor.text)
            }
            .frame(maxWidth: .infinity)
            .plCard()
        }
    }

    private func quickLog(_ regimen: Regimen, slot: Date) {
        let entry = QuickLog.dose(for: regimen, in: journal, at: QuickLog.date(forSlot: slot, now: Date()))
        store.update { $0.save(entry) }
        Analytics.track(.doseLogged, ["isNew": "true", "hasSite": "true", "from": "oneTap"])
        InjectTip().invalidate(reason: .actionPerformed)
        reward = DoseReward(after: entry.id, in: store.journal)
    }

    // MARK: Today's checklist

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's doses")
                .font(.headline)
                .foregroundStyle(PLColor.text)
            ForEach(todayDoses, id: \.self) { scheduled in
                if let regimen = journal.regimens.first(where: { $0.id == scheduled.regimenID }) {
                    todayRow(scheduled, regimen: regimen)
                }
            }
        }
        .plCard()
    }

    private func isSkipped(_ scheduled: ScheduledDose) -> Bool {
        if case .skipped = scheduled.status { return true }
        return false
    }

    private func todayRow(_ scheduled: ScheduledDose, regimen: Regimen) -> some View {
        HStack(spacing: 12) {
            statusIcon(scheduled.status)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: compoundName(regimen.compoundID) + " · " + Fmt.dose(regimen.dose))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PLColor.text)
                Text(verbatim: scheduled.date.formatted(date: .omitted, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(PLColor.muted)
            }
            Spacer(minLength: 0)
            switch scheduled.status {
            case .upcoming, .missed:
                Button { quickLog(regimen, slot: scheduled.date) } label: { Text("Log") }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PLColor.onAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(PLColor.accent, in: Capsule())
            case .skipped(let id):
                // A skip tapped by mistake can be taken back.
                Button { store.update { $0.deleteSkipped(id) } } label: { Text("Undo") }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PLColor.muted)
            case .taken:
                EmptyView()
            }
        }
    }

    private func statusIcon(_ status: ScheduledDose.Status) -> some View {
        let (symbol, color): (String, Color) = {
            switch status {
            case .taken: return ("checkmark.circle.fill", PLColor.accent)
            case .skipped: return ("forward.circle.fill", PLColor.muted)
            case .missed: return ("exclamationmark.circle.fill", PLColor.warning)
            case .upcoming: return ("circle.dashed", PLColor.muted)
            }
        }()
        return Image(systemName: symbol).font(.title2).foregroundStyle(color)
            .contentTransition(.symbolEffect(.replace))
    }

    private func skip(_ scheduled: ScheduledDose) {
        store.update { $0.save(SkippedDose(regimenID: scheduled.regimenID, scheduledAt: scheduled.date)) }
        Analytics.track(.doseSkipped)
    }

    // MARK: Weekly recap

    @ViewBuilder
    private var recapCard: some View {
        let recap = WeeklyRecap.make(journal, now: now, calendar: calendar)
        if !recap.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("This week").font(.headline).foregroundStyle(PLColor.text)
                HStack(spacing: 10) {
                    recapStat("checkmark.circle.fill", "\(recap.taken)/\(recap.due)", Text("Doses"))
                    recapStat("flame.fill", "\(recap.streak)", Text("Streak"))
                    recapStat("scalemass.fill", recap.weightChangeKg.map { ($0 > 0 ? "+" : "") + Fmt.weight($0, in: unit) } ?? "—",
                              Text("Weight"))
                    recapStat("waveform.path.ecg", "\(recap.sideEffects)", Text("Side effects"))
                }
            }
            .plCard()
        }
    }

    private func recapStat(_ symbol: String, _ value: String, _ label: Text) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.footnote).foregroundStyle(PLColor.accent)
            Text(verbatim: value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(PLColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            label.font(.caption2).foregroundStyle(PLColor.muted).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Estimated level

    @ViewBuilder
    private var levelCard: some View {
        if let compound = journal.compounds.first(where: { $0.halfLifeHours != nil && !journal.levelDoses(of: $0.id).isEmpty }),
           let halfLife = compound.halfLifeHours {
            let doses = journal.levelDoses(of: compound.id)
            let from = calendar.date(byAdding: .day, value: -28, to: now)!
            let through = calendar.date(byAdding: .day, value: 7, to: now)!
            let series = MedicationLevel.series(doses: doses, halfLifeHours: NSDecimalNumber(decimal: halfLife).doubleValue,
                                                from: from, through: through)
            let current = MedicationLevel.amount(at: now, doses: doses, halfLifeHours: NSDecimalNumber(decimal: halfLife).doubleValue)
            NavigationLink { LevelsView(compoundID: compound.id) } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Estimated level").font(.headline).foregroundStyle(PLColor.text)
                        Spacer()
                        Text(verbatim: compound.name).font(.subheadline).foregroundStyle(PLColor.muted)
                    }
                    Text(verbatim: Fmt.number(Decimal(current), digits: 2) + " mg")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(PLColor.text)
                    Chart(series, id: \.date) { point in
                        AreaMark(x: .value("Date", point.date), y: .value("mg", point.mg))
                            .foregroundStyle(LinearGradient(colors: [PLColor.accent.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Date", point.date), y: .value("mg", point.mg))
                            .foregroundStyle(PLColor.accent)
                        RuleMark(x: .value("Date", now)).foregroundStyle(PLColor.muted.opacity(0.5))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 80)
                    Text("Estimate from your logged doses, not a measurement.")
                        .font(.caption2)
                        .foregroundStyle(PLColor.muted)
                }
                .plCard()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Vial

    @ViewBuilder
    private var vialCard: some View {
        if let vial = journal.vials.filter({ !$0.isArchived }).max(by: { $0.mixedAt < $1.mixedAt }) {
            let remaining = journal.remaining(in: vial)
            let total = vial.reconstitution.vial
            let share = total.mcg > 0 ? min(max(NSDecimalNumber(decimal: remaining.mcg / total.mcg).doubleValue, 0), 1) : 0
            HStack(spacing: 16) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(PLColor.line, lineWidth: 2)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(PLColor.accent.opacity(0.6))
                        .frame(height: 64 * share)
                        .padding(3)
                }
                .frame(width: 34, height: 70)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: compoundName(vial.compoundID)).font(.headline).foregroundStyle(PLColor.text)
                    Text("\(Fmt.mass(remaining)) left").font(.subheadline).foregroundStyle(PLColor.text)
                    if let regimen = journal.activeRegimens.first(where: { $0.compoundID == vial.compoundID }),
                       let dose = regimen.dose.mass(journal.compound(vial.compoundID)?.iuConversion),
                       let runOut = VialForecast.runOutDate(remaining: remaining, dose: dose, schedule: regimen.schedule,
                                                            after: now, calendar: calendar) {
                        Text("Runs out on \(runOut.formatted(date: .abbreviated, time: .omitted))")
                            .font(.footnote).foregroundStyle(PLColor.muted)
                    }
                }
                Spacer(minLength: 0)
            }
            .plCard()
        }
    }

    // MARK: Quick actions

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            action("plus.circle.fill", Text("Log a dose")) { logging = DoseEditor.Draft() }
            action("waveform.path.ecg", Text("Side effect")) { addingSideEffect = true }
            action("scalemass.fill", Text("Log weight")) { addingWeight = true }
            NavigationLink { SchedulesView() } label: {
                actionLabel("calendar", Text("Schedules"))
            }
            .buttonStyle(.plain)
        }
    }

    private func action(_ symbol: String, _ title: Text, perform: @escaping () -> Void) -> some View {
        Button(action: perform) { actionLabel(symbol, title) }.buttonStyle(.plain)
    }

    private func actionLabel(_ symbol: String, _ title: Text) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(PLColor.accent)
                .frame(width: 36, height: 36)
                .background(PLColor.accent.opacity(0.12), in: Circle())
            title.font(.subheadline.weight(.semibold)).foregroundStyle(PLColor.text)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(PLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(PLColor.line))
    }

    // MARK: Helpers

    private func compoundName(_ id: Compound.ID) -> String { journal.compound(id)?.name ?? "—" }

    private func latestVial(_ regimen: Regimen) -> Vial? {
        journal.vials.filter { $0.compoundID == regimen.compoundID && !$0.isArchived }.max { $0.mixedAt < $1.mixedAt }
    }
}

/// Today's protein, water and calories at a glance, with the two actions
/// people repeat all day (add a food, add water); the full nutrition screen
/// is one tap away (and a tab).
private struct NutritionGlance: View {
    @EnvironmentObject private var store: DataStore
    @State private var addingFood = false

    var body: some View {
        let totals = store.journal.nutrition(on: Date(), calendar: .current)
        let goals = store.journal.nutritionGoals
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink { NutritionView() } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Nutrition").font(.headline).foregroundStyle(PLColor.text)
                        Spacer()
                        Text("See all").font(.subheadline.weight(.semibold)).foregroundStyle(PLColor.accent)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(PLColor.accent)
                    }
                    HStack(spacing: 10) {
                        ring(Text("Protein"), totals.protein, goals.protein, "\(Fmt.number(totals.protein, digits: 0)) g", PLColor.accent)
                        ring(Text("Water"), totals.waterMl, goals.waterMl, Fmt.water(totals.waterMl), PLColor.water)
                        ring(Text("Calories"), totals.kcal, goals.kcal, Fmt.number(totals.kcal, digits: 0), PLColor.warning)
                    }
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: 10) {
                Button { addingFood = true } label: {
                    Label { Text("Add food") } icon: { Image(systemName: "plus") }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChipStyle(selected: true))
                Button {
                    store.update { $0.save(WaterEntry(date: Date(), milliliters: 250)) }
                    Analytics.track(.waterLogged)
                } label: {
                    Label { Text(verbatim: "+250 ml") } icon: { Image(systemName: "drop.fill") }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChipStyle(selected: false))
                .sensoryFeedback(.increase, trigger: totals.waterMl)
            }
        }
        .plCard()
        .sheet(isPresented: $addingFood) { AddFoodSheet(day: Date()) }
    }

    private func ring(_ title: Text, _ value: Decimal, _ goal: Decimal?, _ text: String, _ color: Color) -> some View {
        let progress = goal.map { $0 > 0 ? min(NSDecimalNumber(decimal: value / $0).doubleValue, 1) : 0 } ?? 0
        return VStack(spacing: 6) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: text)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(PLColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(8)
            }
            .frame(width: 66, height: 66)
            title.font(.caption2.weight(.semibold)).foregroundStyle(PLColor.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
