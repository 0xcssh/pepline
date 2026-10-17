import Charts
import SwiftUI

/// Builds the doctor report: a summary page, then the dose log and the
/// side-effect log, laid out in SwiftUI and drawn into PDF pages
/// (`ImageRenderer` into a PDF `CGContext`). Always light, for printing.
enum DoctorReport {
    /// US Letter where the region measures in inches, A4 elsewhere.
    static var pageSize: CGSize {
        Locale.current.measurementSystem == .us ? CGSize(width: 612, height: 792) : CGSize(width: 595, height: 842)
    }

    static let rowsPerPage = 26

    @MainActor
    static func pages(_ data: ReportData, journal: Journal, unit: UnitMass) -> [AnyView] {
        var bodies: [AnyView] = [AnyView(SummaryPage(data: data, journal: journal, unit: unit))]
        for chunk in data.doses.chunked(rowsPerPage) {
            bodies.append(AnyView(DoseLogPage(doses: chunk, journal: journal)))
        }
        for chunk in data.sideEffects.chunked(rowsPerPage) {
            bodies.append(AnyView(SideEffectLogPage(entries: chunk)))
        }
        return bodies.enumerated().map { index, body in
            AnyView(ReportPage(data: data, page: index + 1, of: bodies.count) { body })
        }
    }

    /// Writes the PDF to a temporary file named after the period.
    @MainActor
    static func write(_ data: ReportData, journal: Journal, unit: UnitMass) -> URL? {
        let size = pageSize
        let name = "Pepline-\(data.through.formatted(.iso8601.year().month().day())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        var box = CGRect(origin: .zero, size: size)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        for page in pages(data, journal: journal, unit: unit) {
            let renderer = ImageRenderer(content: page
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .light)
                .fontDesign(.rounded))
            renderer.render { _, draw in
                context.beginPDFPage(nil)
                draw(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        return url
    }
}

private extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

// MARK: - Page frame

/// Header, footer and margins shared by every page.
struct ReportPage<Content: View>: View {
    let data: ReportData
    let page: Int
    let of: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pepline report").font(.title3.bold()).foregroundStyle(PLColor.text)
                Spacer()
                Text(verbatim: "\(data.from.formatted(date: .abbreviated, time: .omitted)) – \(data.through.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(PLColor.muted)
            }
            Rectangle().fill(PLColor.accent).frame(height: 2)
            content()
            Spacer(minLength: 0)
            HStack {
                Text("Logged by the patient in Pepline. Not a medical record; Pepline gives no dosing advice.")
                Spacer()
                Text("Page \(String(page)) of \(String(of))")
            }
            .font(.caption2)
            .foregroundStyle(PLColor.muted)
        }
        .padding(36)
        .background(PLColor.card)
    }
}

private struct SectionTitle: View {
    let text: Text
    var body: some View {
        text.font(.headline).foregroundStyle(PLColor.text).padding(.top, 6)
    }
}

/// A table row: fixed-width columns, hairline below.
private struct ReportRow: View {
    let cells: [(Text, CGFloat?)]
    var header = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(cells.indices, id: \.self) { index in
                    cells[index].0
                        .font(header ? .caption.weight(.semibold) : .caption)
                        .foregroundStyle(header ? PLColor.muted : PLColor.text)
                        .lineLimit(2)
                        .frame(width: cells[index].1, alignment: .leading)
                        .frame(maxWidth: cells[index].1 == nil ? .infinity : nil, alignment: .leading)
                }
            }
            Rectangle().fill(PLColor.line).frame(height: 0.5)
        }
    }
}

// MARK: - Summary

private struct SummaryPage: View {
    let data: ReportData
    let journal: Journal
    let unit: UnitMass

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: Text("Schedules and adherence"))
            if data.regimens.isEmpty {
                Text("No schedule.").font(.caption).foregroundStyle(PLColor.muted)
            } else {
                ReportRow(cells: [(Text("Compound"), 110), (Text("Dose"), 70), (Text("Schedule"), nil),
                                  (Text("Taken"), 44), (Text("Skipped"), 50), (Text("Missed"), 46), (Text("Rate"), 40)],
                          header: true)
                ForEach(data.regimens.indices, id: \.self) { index in
                    let line = data.regimens[index]
                    ReportRow(cells: [
                        (Text(verbatim: line.compoundName), 110),
                        (Text(verbatim: Fmt.dose(line.regimen.dose)), 70),
                        (Text(verbatim: PatternKind.describe(line.regimen.schedule.pattern)), nil),
                        (Text(verbatim: String(line.adherence.taken)), 44),
                        (Text(verbatim: String(line.adherence.skipped)), 50),
                        (Text(verbatim: String(line.adherence.missed)), 46),
                        (Text(verbatim: line.adherence.rate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—"), 40),
                    ])
                }
            }
            Text("Doses logged in the period: \(String(data.doses.count))")
                .font(.caption)
                .foregroundStyle(PLColor.muted)

            SectionTitle(text: Text("Weight"))
            weight

            SectionTitle(text: Text("Side effects"))
            if data.symptoms.isEmpty {
                Text("No side effect logged.").font(.caption).foregroundStyle(PLColor.muted)
            } else {
                ReportRow(cells: [(Text("Symptom"), nil), (Text("Times"), 60), (Text("Average intensity (1–5)"), 140)],
                          header: true)
                ForEach(data.symptoms.indices, id: \.self) { index in
                    let line = data.symptoms[index]
                    ReportRow(cells: [(line.symptom.title, nil), (Text(verbatim: String(line.count)), 60),
                                      (Text(verbatim: Fmt.number(line.averageSeverity, digits: 1)), 140)])
                }
            }
        }
    }

    @ViewBuilder
    private var weight: some View {
        if let first = data.weights.first, let last = data.weights.last {
            HStack(spacing: 24) {
                figure(Text("Start"), Fmt.weight(first.kilograms, in: unit))
                figure(Text("End"), Fmt.weight(last.kilograms, in: unit))
                if let change = data.weightChangeKg {
                    figure(Text("Change"), (change > 0 ? "+" : "") + Fmt.weight(change, in: unit))
                }
            }
            if data.weights.count >= 2 {
                Chart(data.weights) { entry in
                    LineMark(x: .value("Date", entry.date),
                             y: .value("Weight", NSDecimalNumber(decimal: Fmt.weightValue(entry.kilograms, in: unit)).doubleValue))
                        .foregroundStyle(PLColor.accent)
                    PointMark(x: .value("Date", entry.date),
                              y: .value("Weight", NSDecimalNumber(decimal: Fmt.weightValue(entry.kilograms, in: unit)).doubleValue))
                        .foregroundStyle(PLColor.accent)
                        .symbolSize(16)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 150)
            }
        } else {
            Text("No weight logged.").font(.caption).foregroundStyle(PLColor.muted)
        }
    }

    private func figure(_ title: Text, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            title.font(.caption2).foregroundStyle(PLColor.muted)
            Text(verbatim: value).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(PLColor.text)
        }
    }
}

// MARK: - Logs

private struct DoseLogPage: View {
    let doses: [DoseEntry]
    let journal: Journal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: Text("Dose log"))
            ReportRow(cells: [(Text("Date"), 120), (Text("Compound"), 110), (Text("Dose"), 70), (Text("Site"), 90), (Text("Notes"), nil)],
                      header: true)
            ForEach(doses) { dose in
                ReportRow(cells: [
                    (Text(dose.date, format: .dateTime.day().month(.abbreviated).year().hour().minute()), 120),
                    (Text(verbatim: journal.compound(dose.compoundID)?.name ?? "—"), 110),
                    (Text(verbatim: Fmt.dose(dose.amount)), 70),
                    (Text(verbatim: dose.site.map { Fmt.site($0, dose.side) } ?? "—"), 90),
                    (Text(verbatim: dose.notes), nil),
                ])
            }
        }
    }
}

private struct SideEffectLogPage: View {
    let entries: [SideEffectEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: Text("Side-effect log"))
            ReportRow(cells: [(Text("Date"), 120), (Text("Symptom"), 130), (Text("Intensity"), 60), (Text("Notes"), nil)],
                      header: true)
            ForEach(entries) { entry in
                ReportRow(cells: [
                    (Text(entry.date, format: .dateTime.day().month(.abbreviated).year().hour().minute()), 120),
                    (entry.symptom == .other && !entry.customName.isEmpty ? Text(verbatim: entry.customName) : entry.symptom.title, 130),
                    (Text(verbatim: "\(entry.severity)/5"), 60),
                    (Text(verbatim: entry.notes), nil),
                ])
            }
        }
    }
}

// MARK: - Sheet

/// Choose a period, preview the first page, share the PDF.
struct DoctorReportSheet: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightUnitSetting.key) private var unitSetting = WeightUnitSetting.defaultValue
    @State private var days = 90
    @State private var fileURL: URL?

    private var unit: UnitMass { WeightUnitSetting.unit(unitSetting) }

    private var data: ReportData {
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: now)!)
        return ReportData.make(store.journal, from: start, through: now, now: now, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker(selection: $days) {
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("1 year").tag(365)
                    } label: { Text("Period") }
                        .pickerStyle(.segmented)
                    let size = DoctorReport.pageSize
                    let scale = 0.55
                    ReportPage(data: data, page: 1, of: 1) {
                        SummaryPage(data: data, journal: store.journal, unit: unit)
                    }
                    .frame(width: size.width, height: size.height)
                    .environment(\.colorScheme, .light)
                    .scaleEffect(scale)
                    .frame(width: size.width * scale, height: size.height * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                    .allowsHitTesting(false)
                    Text("For your doctor: everything you logged in the period, with no interpretation.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PLColor.muted)
                }
                .padding(20)
            }
            .background(PLBackground())
            .safeAreaInset(edge: .bottom) {
                Group {
                    if let fileURL {
                        ShareLink(item: fileURL) {
                            Label { Text("Share the PDF") } icon: { Image(systemName: "square.and.arrow.up") }
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        ProgressView()
                    }
                }
                .buttonStyle(.primaryPill)
                .padding(20)
            }
            .navigationTitle(Text("Doctor report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task(id: days) {
                fileURL = DoctorReport.write(data, journal: store.journal, unit: unit)
                if fileURL != nil { Analytics.track(.exported, ["kind": "report"]) }
            }
        }
    }
}
