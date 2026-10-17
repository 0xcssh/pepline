import Charts
import SwiftUI

/// The daily screen (Shotsy's summary, Peptide Tracker's "clear plan"): the
/// next dose with a countdown, today's doses to log or skip in one tap, the
/// units to draw, streak and adherence, the estimated level and the vial.
struct TodayView: View {
    @EnvironmentObject private var store: DataStore
    @AppStorage("firstName") private var firstName = ""
    @AppStorage(WeightUnitSetting.key) private var unitSetting = WeightUnitSetting.defaultValue
    @State private var logging: DoseEditor.Draft?
    @State private var addingSideEffect = false
    @State private var addingWeight = false
    @State private var now = Date()

    private var journal: Journal { store.journal }
    private var calendar: Calendar { .current }

    private var todayDoses: [ScheduledDose] {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start)!
        return Adherence.doses(in: journal, from: start, through: end, now: now, calendar: calendar)
    }

    private var recentDoses: [ScheduledDose] {
        let start = calendar.date(byAdding: .day, value: -30, to: now)!
        return Adherence.doses(in: journal, from: start, through: now, now: now, calendar: calendar)
    }

    private var nextDose: (date: Date, regimen: Regimen)? {
        journal.regimens
            .compactMap { regimen in regimen.schedule.next(after: now, calendar: calendar).map { ($0, regimen) } }
            .min { $0.0 < $1.0 }
            .map { (date: $0.0, regimen: $0.1) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if journal.regimens.isEmpty {
                    emptyState
                } else {
                    nextDoseCard
                    if !todayDoses.isEmpty { todayCard }
                    statsRow
                }
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
        .sheet(isPresented: $addingSideEffect) { SideEffectSheet() }
        .sheet(isPresented: $addingWeight) { WeightEditor(draft: WeightEditor.Draft(), unit: WeightUnitSetting.unit(unitSetting)) }
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
            PulseRings(symbol: "calendar.badge.plus", size: 120)
            Text("Add the schedule your prescriber gave you to see your doses here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(PLColor.text)
            NavigationLink { SchedulesView() } label: { Text("Add a schedule") }
                .buttonStyle(.primaryPill)
        }
        .frame(maxWidth: .infinity)
        .plCard()
    }

    // MARK: Next dose

    private var nextDoseCard: some View {
        let next = nextDose
        let isToday = next.map { calendar.isDate($0.date, inSameDayAs: now) } ?? false
        let previous = next.flatMap { journal.doses(of: $0.regimen.compoundID).first?.date }
        let fill: Double = {
            guard let next, let previous, next.date > previous else { return 0 }
            return min(max(now.timeIntervalSince(previous) / next.date.timeIntervalSince(previous), 0), 1)
        }()
        return HStack(spacing: 18) {
            ZStack {
                Circle().stroke(PLColor.accent.opacity(0.12), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(fill, 0.02))
                    .stroke(PLColor.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .plGlow()
                Image(systemName: isToday ? "syringe.fill" : "hourglass")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(PLColor.accent)
                    .symbolEffect(.pulse, isActive: isToday)
            }
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 4) {
                if let next {
                    (isToday ? Text("It's dose day") : Text("Next dose"))
                        .font(.title2.bold())
                        .foregroundStyle(PLColor.text)
                    Text(verbatim: compoundName(next.regimen.compoundID) + " · " + Fmt.dose(next.regimen.dose))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PLColor.text)
                    Text(next.date, style: .relative)
                        .font(.subheadline)
                        .foregroundStyle(PLColor.muted)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
        .plCard()
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

    private func todayRow(_ scheduled: ScheduledDose, regimen: Regimen) -> some View {
        HStack(spacing: 12) {
            statusIcon(scheduled.status)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: compoundName(regimen.compoundID) + " · " + Fmt.dose(regimen.dose))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PLColor.text)
                HStack(spacing: 6) {
                    Text(verbatim: scheduled.date.formatted(date: .omitted, time: .shortened))
                    if let units = unitsToDraw(regimen) {
                        Text(verbatim: "·")
                        Text("Draw to \(Fmt.number(units)) units")
                    }
                }
                .font(.footnote)
                .foregroundStyle(PLColor.muted)
            }
            Spacer(minLength: 0)
            switch scheduled.status {
            case .upcoming, .missed:
                Button { skip(scheduled) } label: { Text("Skip") }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PLColor.muted)
                Button { logging = DoseEditor.Draft(regimen: regimen, journal: journal) } label: { Text("Log") }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PLColor.onAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(PLColor.accent, in: Capsule())
            case .taken, .skipped:
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

    // MARK: Stats

    private var statsRow: some View {
        let doses = recentDoses
        let summary = Adherence.summary(doses)
        return HStack(spacing: 12) {
            stat(symbol: "flame.fill", value: "\(Adherence.streak(doses))", label: Text("Streak"))
            stat(symbol: "chart.pie.fill",
                 value: summary.rate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—",
                 label: Text("On schedule, 30 days"))
        }
    }

    private func stat(symbol: String, value: String, label: Text) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(PLColor.accent)
            Text(verbatim: value).plNumeral(size: 30).foregroundStyle(PLColor.text)
            label.font(.caption).foregroundStyle(PLColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard()
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
                        .plNumeral(size: 28)
                        .foregroundStyle(PLColor.accent)
                    Chart(series, id: \.date) { point in
                        AreaMark(x: .value("Date", point.date), y: .value("mg", point.mg))
                            .foregroundStyle(LinearGradient(colors: [PLColor.accent.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Date", point.date), y: .value("mg", point.mg))
                            .foregroundStyle(PLColor.accent)
                        RuleMark(x: .value("Date", now)).foregroundStyle(PLColor.muted.opacity(0.5))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 90)
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
            let share = total.mcg > 0 ? NSDecimalNumber(decimal: remaining.mcg / total.mcg).doubleValue : 0
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
                    if let regimen = journal.regimens.first(where: { $0.compoundID == vial.compoundID }),
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
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(PLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(PLColor.line))
    }

    // MARK: Helpers

    private func compoundName(_ id: Compound.ID) -> String { journal.compound(id)?.name ?? "—" }

    /// Units to draw for the regimen's dose from its newest active vial.
    private func unitsToDraw(_ regimen: Regimen) -> Decimal? {
        guard let vial = journal.vials.filter({ $0.compoundID == regimen.compoundID && !$0.isArchived })
                .max(by: { $0.mixedAt < $1.mixedAt }),
              let dose = regimen.dose.mass(journal.compound(regimen.compoundID)?.iuConversion),
              let draw = try? vial.reconstitution.draw(dose, with: vial.syringe)
        else { return nil }
        return draw.units
    }
}
