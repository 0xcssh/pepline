import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject private var store: DataStore
    @State private var editing: RegimenEditor.Draft?
    @State private var logging: DoseEditor.Draft?

    var body: some View {
        List {
            if store.journal.regimens.isEmpty {
                Text("No schedule yet. Tap + to add the schedule your prescriber gave you.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.journal.regimens) { regimen in
                Button { editing = RegimenEditor.Draft(regimen) } label: { row(regimen) }
                    .tint(.primary)
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            store.update { $0.deleteRegimen(regimen.id) }
                        }
                    }
            }
            Section {
                DisclaimerText()
            }
        }
        .navigationTitle("Schedules")
        .toolbar {
            Button { editing = RegimenEditor.Draft() } label: { Image(systemName: "plus") }
                .accessibilityLabel(Text("Add a schedule"))
        }
        .sheet(item: $editing) { RegimenEditor(draft: $0) }
        .sheet(item: $logging) { DoseEditor(draft: $0) }
    }

    private func row(_ regimen: Regimen) -> some View {
        let journal = store.journal
        let compound = journal.compound(regimen.compoundID)
        let next = regimen.schedule.next(after: Date(), calendar: .current)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: compound?.name ?? "—").font(.headline)
                Spacer()
                Text(verbatim: Fmt.dose(regimen.dose)).font(.headline).monospacedDigit()
            }
            Text(verbatim: describe(regimen.schedule))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let next {
                Text("Next: \(next.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
            }
            if let runOut = runOut(regimen, compound: compound) {
                Text("Vial runs out on \(runOut.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button {
                logging = DoseEditor.Draft(regimen: regimen, journal: journal)
            } label: {
                Label("Log this dose", systemImage: "checkmark.circle")
            }
            .buttonStyle(.bordered)
            .tint(PLColor.navy)
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    private func runOut(_ regimen: Regimen, compound: Compound?) -> Date? {
        let journal = store.journal
        guard let vial = journal.vials
                .filter({ $0.compoundID == regimen.compoundID && !$0.isArchived })
                .max(by: { $0.mixedAt < $1.mixedAt }),
              let dose = regimen.dose.mass(compound?.iuConversion)
        else { return nil }
        return VialForecast.runOutDate(remaining: journal.remaining(in: vial), dose: dose,
                                       schedule: regimen.schedule, after: Date(), calendar: .current)
    }

    private func describe(_ schedule: DoseSchedule) -> String {
        let times = schedule.times.sorted().map { time in
            Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date())?
                .formatted(date: .omitted, time: .shortened) ?? ""
        }.joined(separator: ", ")
        return "\(PatternKind.describe(schedule.pattern)) · \(times)"
    }
}

/// The repeat choices offered in the editor, and their wording.
enum PatternKind: Hashable, CaseIterable {
    case daily, everyOtherDay, everyNDays, weekdays, cycle

    init(_ pattern: DoseSchedule.Pattern) {
        switch pattern {
        case .everyNDays(1): self = .daily
        case .everyNDays(2): self = .everyOtherDay
        case .everyNDays: self = .everyNDays
        case .weekdays: self = .weekdays
        case .cycle: self = .cycle
        }
    }

    var title: String {
        switch self {
        case .daily: return String(localized: "Every day")
        case .everyOtherDay: return String(localized: "Every other day")
        case .everyNDays: return String(localized: "Every few days")
        case .weekdays: return String(localized: "Specific weekdays")
        case .cycle: return String(localized: "Days on, days off")
        }
    }

    static func describe(_ pattern: DoseSchedule.Pattern) -> String {
        switch pattern {
        case .everyNDays(1): return String(localized: "Every day")
        case .everyNDays(2): return String(localized: "Every other day")
        case .everyNDays(let n): return String(localized: "Every \(String(n)) days")
        case .weekdays(let days):
            // Weekday names from the system calendar, in the user's language
            // and week order.
            let calendar = Calendar.current
            let ordered = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
            return ordered.filter(days.contains)
                .map { calendar.shortWeekdaySymbols[$0 - 1] }
                .joined(separator: ", ")
        case .cycle(let on, let off):
            return String(localized: "\(String(on)) days on, \(String(off)) days off")
        }
    }
}
