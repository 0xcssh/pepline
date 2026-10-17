import SwiftUI
import WidgetKit

@main
struct PeplineWidgets: WidgetBundle {
    var body: some Widget {
        NextDoseWidget()
    }
}

/// Next dose on the Home Screen and Lock Screen (Shotsy, MeAgain and
/// Peptide Tracker all ship one): compound, dose, time left, units to draw.
struct NextDoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextDose", provider: NextDoseProvider()) { entry in
            NextDoseView(entry: entry)
                .containerBackground(for: .widget) { PLColor.background }
        }
        .configurationDisplayName(Text("Next dose"))
        .description(Text("Your next dose, its time and the units to draw."))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct NextDoseEntry: TimelineEntry {
    let date: Date
    /// The dose to show: the first one not yet 12 h overdue.
    let dose: WidgetSnapshot.Dose?
    let following: [WidgetSnapshot.Dose]
}

struct NextDoseProvider: TimelineProvider {
    /// Same window the app uses before a dose counts as missed.
    static let tolerance: TimeInterval = 12 * 3600

    func placeholder(in context: Context) -> NextDoseEntry {
        NextDoseEntry(date: Date(), dose: WidgetSnapshot.Dose(date: Date().addingTimeInterval(5400), compound: "Semaglutide",
                                                              dose: "0.25 mg", units: "10"), following: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (NextDoseEntry) -> Void) {
        let entries = Self.entries(WidgetSnapshot.read(), now: Date())
        completion(context.isPreview && entries[0].dose == nil ? placeholder(in: context) : entries[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextDoseEntry>) -> Void) {
        let now = Date()
        let entries = Self.entries(WidgetSnapshot.read(), now: now)
        // The app reloads the widget whenever the journal changes; otherwise
        // check again after the last planned switch, or in six hours.
        completion(Timeline(entries: entries, policy: entries.count > 1 ? .atEnd : .after(now.addingTimeInterval(6 * 3600))))
    }

    /// One entry now, then one when each dose becomes due ("Due now") and
    /// one when it drops off 12 h later.
    static func entries(_ snapshot: WidgetSnapshot?, now: Date) -> [NextDoseEntry] {
        let doses = (snapshot?.doses ?? []).filter { $0.date.addingTimeInterval(tolerance) > now }
        func entry(at date: Date) -> NextDoseEntry {
            let remaining = doses.filter { $0.date.addingTimeInterval(tolerance) > date }
            return NextDoseEntry(date: date, dose: remaining.first, following: Array(remaining.dropFirst().prefix(2)))
        }
        var dates = [now]
        for dose in doses.prefix(6) {
            dates.append(contentsOf: [dose.date, dose.date.addingTimeInterval(tolerance)].filter { $0 > now })
        }
        return Array(Set(dates)).sorted().map(entry(at:))
    }
}

struct NextDoseView: View {
    let entry: NextDoseEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryInline: inline
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .systemMedium: medium
            default: small
            }
        }
        .fontDesign(.rounded)
    }

    private func isDue(_ dose: WidgetSnapshot.Dose) -> Bool { dose.date <= entry.date }

    @ViewBuilder
    private func when(_ dose: WidgetSnapshot.Dose) -> some View {
        if isDue(dose) {
            Text("Due now")
        } else if Calendar.current.isDate(dose.date, inSameDayAs: entry.date) {
            Text(dose.date, style: .relative)
        } else {
            Text(dose.date, format: .dateTime.weekday(.abbreviated).hour().minute())
        }
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label { Text("Next dose") } icon: { Image(systemName: "syringe") }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PLColor.muted)
            if let dose = entry.dose {
                Spacer(minLength: 0)
                Text(verbatim: dose.compound)
                    .font(.headline)
                    .foregroundStyle(PLColor.text)
                    .lineLimit(1)
                Text(verbatim: dose.dose)
                    .font(.subheadline)
                    .foregroundStyle(PLColor.muted)
                if let units = dose.units {
                    Text("Draw to \(units) units")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PLColor.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                when(dose)
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(isDue(dose) ? PLColor.warning : PLColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Spacer(minLength: 0)
                empty
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            small
            if !entry.following.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Then")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PLColor.muted)
                    ForEach(Array(entry.following.enumerated()), id: \.offset) { _, dose in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: "\(dose.compound) · \(dose.dose)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PLColor.text)
                                .lineLimit(1)
                            Text(dose.date, format: .dateTime.weekday(.abbreviated).hour().minute())
                                .font(.caption2)
                                .foregroundStyle(PLColor.muted)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("No dose scheduled")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PLColor.text)
            Text("Plan a schedule in Pepline.")
                .font(.caption)
                .foregroundStyle(PLColor.muted)
        }
    }

    // MARK: Lock Screen

    @ViewBuilder
    private var rectangular: some View {
        if let dose = entry.dose {
            VStack(alignment: .leading, spacing: 1) {
                Label { Text(verbatim: dose.compound) } icon: { Image(systemName: "syringe") }
                    .font(.headline)
                    .widgetAccentable()
                Group {
                    if let units = dose.units {
                        Text("\(dose.dose) · \(units) units")
                    } else {
                        Text(verbatim: dose.dose)
                    }
                }
                .font(.caption)
                when(dose).font(.caption.monospacedDigit())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("No dose scheduled").font(.caption)
        }
    }

    @ViewBuilder
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "syringe").font(.caption).widgetAccentable()
                if let dose = entry.dose {
                    if isDue(dose) {
                        Text(verbatim: "!").font(.headline)
                    } else {
                        Text(dose.date, format: .dateTime.hour().minute())
                            .font(.caption2.monospacedDigit())
                            .minimumScaleFactor(0.6)
                    }
                }
            }
            .padding(4)
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let dose = entry.dose {
            Label { Text(verbatim: dose.compound + " · ") + (isDue(dose) ? Text("Due now") : Text(dose.date, style: .relative)) } icon: {
                Image(systemName: "syringe")
            }
        } else {
            Text("No dose scheduled")
        }
    }
}
