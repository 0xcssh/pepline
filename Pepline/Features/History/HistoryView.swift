import SwiftUI

/// Month calendar with a dot per scheduled dose (taken, skipped, missed),
/// the month's adherence, and the selected day's doses and side effects.
/// The full list and CSV stay one tap away (JournalView).
struct HistoryView: View {
    @EnvironmentObject private var store: DataStore
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())!.start
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var editing: DoseEditor.Draft?
    @State private var addingSideEffect = false

    private var calendar: Calendar { .current }

    private var monthDoses: [ScheduledDose] {
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: month)!
        return Adherence.doses(in: store.journal, from: month, through: end, now: Date(), calendar: calendar)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthHeader
                calendarGrid
                adherenceCard
                dayDetail
                NavigationLink { JournalView() } label: {
                    Label("All doses", systemImage: "list.bullet")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .plCard()
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(PLBackground())
        .navigationTitle(Text("History"))
        .toolbar {
            Button { editing = DoseEditor.Draft() } label: { Image(systemName: "plus") }
                .accessibilityLabel(Text("Log a dose"))
        }
        .sheet(item: $editing) { DoseEditor(draft: $0) }
        .sheet(isPresented: $addingSideEffect) { SideEffectSheet() }
    }

    // MARK: Month

    private var monthHeader: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left").font(.headline) }
                .accessibilityLabel(Text("Previous month"))
            Spacer()
            Text(verbatim: month.formatted(.dateTime.month(.wide).year()).capitalized)
                .font(.title3.bold())
                .foregroundStyle(PLColor.text)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right").font(.headline) }
                .accessibilityLabel(Text("Next month"))
        }
        .foregroundStyle(PLColor.accent)
    }

    private func shift(_ months: Int) {
        withAnimation(.spring(duration: 0.35)) {
            month = calendar.date(byAdding: .month, value: months, to: month)!
        }
    }

    private var days: [Date?] {
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        let firstWeekday = calendar.component(.weekday, from: month)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading)
            + (0..<count).map { calendar.date(byAdding: .day, value: $0, to: month)! }
    }

    private var calendarGrid: some View {
        let doses = monthDoses
        let symbols = (0..<7).map { calendar.veryShortWeekdaySymbols[(calendar.firstWeekday - 1 + $0) % 7] }
        return VStack(spacing: 8) {
            HStack {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    Text(verbatim: symbol).font(.caption.weight(.semibold)).foregroundStyle(PLColor.muted).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day, doses: doses.filter { calendar.isDate($0.date, inSameDayAs: day) })
                    } else {
                        Color.clear.frame(height: 46)
                    }
                }
            }
        }
        .plCard()
    }

    private func dayCell(_ day: Date, doses: [ScheduledDose]) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selectedDay)
        let today = calendar.isDateInToday(day)
        let hasSideEffect = !store.journal.sideEffects(on: day, calendar: calendar).isEmpty
        return Button {
            selectedDay = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 4) {
                Text(verbatim: "\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(today ? .heavy : .medium))
                    .foregroundStyle(selected ? PLColor.onAccent : PLColor.text)
                HStack(spacing: 2) {
                    ForEach(Array(doses.prefix(3).enumerated()), id: \.offset) { _, dose in
                        Circle().fill(color(dose.status)).frame(width: 5, height: 5)
                    }
                    if hasSideEffect {
                        Circle().strokeBorder(PLColor.warning, lineWidth: 1).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(selected ? PLColor.accent : (today ? PLColor.accent.opacity(0.12) : .clear),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func color(_ status: ScheduledDose.Status) -> Color {
        switch status {
        case .taken: return PLColor.accent
        case .skipped: return PLColor.muted
        case .missed: return PLColor.warning
        case .upcoming: return PLColor.muted.opacity(0.35)
        }
    }

    // MARK: Adherence

    private var adherenceCard: some View {
        let summary = Adherence.summary(monthDoses)
        return HStack(spacing: 18) {
            ZStack {
                Circle().stroke(PLColor.accent.opacity(0.12), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: summary.rate ?? 0)
                    .stroke(PLColor.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: summary.rate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(PLColor.text)
            }
            .frame(width: 74, height: 74)
            VStack(alignment: .leading, spacing: 6) {
                legendRow(PLColor.accent, Text("\(String(summary.taken)) taken"))
                legendRow(PLColor.muted, Text("\(String(summary.skipped)) skipped"))
                legendRow(PLColor.warning, Text("\(String(summary.missed)) missed"))
            }
            Spacer(minLength: 0)
        }
        .plCard()
    }

    private func legendRow(_ color: Color, _ text: Text) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 9, height: 9)
            text.font(.subheadline).foregroundStyle(PLColor.text)
        }
    }

    // MARK: Day detail

    private var dayDetail: some View {
        let journal = store.journal
        let doses = journal.doses.filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }.sorted { $0.date < $1.date }
        let effects = journal.sideEffects(on: selectedDay, calendar: calendar)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(verbatim: selectedDay.formatted(date: .complete, time: .omitted).capitalized)
                    .font(.headline)
                    .foregroundStyle(PLColor.text)
                Spacer()
                Button { addingSideEffect = true } label: { Image(systemName: "waveform.path.ecg") }
                    .accessibilityLabel(Text("Side effect"))
            }
            if doses.isEmpty && effects.isEmpty {
                Text("Nothing logged this day.").font(.subheadline).foregroundStyle(PLColor.muted)
            }
            ForEach(doses) { dose in
                Button { editing = DoseEditor.Draft(dose) } label: { DoseRow(dose: dose, showDate: false) }
                    .buttonStyle(.plain)
            }
            ForEach(effects) { effect in
                HStack(spacing: 10) {
                    Image(systemName: effect.symptom.symbol).foregroundStyle(PLColor.warning).frame(width: 26)
                    if effect.symptom == .other, !effect.customName.isEmpty {
                        Text(verbatim: effect.customName)
                    } else {
                        effect.symptom.title
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { level in
                            Capsule().fill(level <= effect.severity ? PLColor.warning : PLColor.line).frame(width: 5, height: 12)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(PLColor.text)
                .swipeActions {
                    Button("Delete", role: .destructive) { store.update { $0.deleteSideEffect(effect.id) } }
                }
                .contextMenu {
                    Button("Delete", role: .destructive) { store.update { $0.deleteSideEffect(effect.id) } }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard()
    }
}
