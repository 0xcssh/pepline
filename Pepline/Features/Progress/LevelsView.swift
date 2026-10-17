import Charts
import SwiftUI

/// Estimated amount on board over time for one compound, with the method and
/// its source spelled out (App Review 1.4.1: disclose the methodology).
struct LevelsView: View {
    @EnvironmentObject private var store: DataStore
    let compoundID: Compound.ID
    @State private var range = 28

    private var compound: Compound? { store.journal.compound(compoundID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let compound, let halfLife = compound.halfLifeHours {
                    let hours = NSDecimalNumber(decimal: halfLife).doubleValue
                    let doses = store.journal.levelDoses(of: compoundID)
                    let now = Date()
                    let from = Calendar.current.date(byAdding: .day, value: -range, to: now)!
                    let through = Calendar.current.date(byAdding: .day, value: 7, to: now)!
                    let series = MedicationLevel.series(doses: doses, halfLifeHours: hours, from: from, through: through, points: 200)

                    Picker("Period", selection: $range) {
                        Text("4 weeks").tag(28)
                        Text("3 months").tag(90)
                        Text("1 year").tag(365)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Now").font(.subheadline).foregroundStyle(PLColor.muted)
                        Text(verbatim: Fmt.number(Decimal(MedicationLevel.amount(at: now, doses: doses, halfLifeHours: hours)), digits: 2) + " mg")
                            .plNumeral(size: 44)
                            .foregroundStyle(PLColor.accent)
                            .plGlow()
                        Chart {
                            ForEach(series, id: \.date) { point in
                                AreaMark(x: .value("Date", point.date), y: .value("mg", point.mg))
                                    .foregroundStyle(LinearGradient(colors: [PLColor.accent.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                                LineMark(x: .value("Date", point.date), y: .value("mg", point.mg))
                                    .foregroundStyle(PLColor.accent)
                            }
                            ForEach(doses.filter { $0.date >= from }, id: \.date) { dose in
                                PointMark(x: .value("Date", dose.date), y: .value("mg", 0))
                                    .symbol(.triangle)
                                    .foregroundStyle(PLColor.text)
                            }
                            RuleMark(x: .value("Date", now)).foregroundStyle(PLColor.muted)
                        }
                        .frame(height: 240)
                    }
                    .plCard()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it's estimated").font(.headline).foregroundStyle(PLColor.text)
                        Text("Each logged dose is counted in full when you log it, then halves every \(Fmt.number(halfLife, digits: 1)) hours (the half-life on the product label). Real levels depend on your body; this is an estimate, not a measurement.")
                            .font(.subheadline)
                            .foregroundStyle(PLColor.muted)
                    }
                    .plCard()
                } else {
                    Text("Add the half-life from your product label to the compound (Settings, Compounds) to see an estimate.")
                        .foregroundStyle(PLColor.muted)
                        .plCard()
                }
            }
            .padding(20)
        }
        .background(PLBackground())
        .navigationTitle(Text(verbatim: compound?.name ?? ""))
    }
}
