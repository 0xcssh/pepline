import SwiftUI
import XCTest
@testable import Pepline

/// Renders the calculator's result card to PNGs so drawings can be looked at
/// before shipping (no Mac: CI uploads them as an artifact). Runs only when
/// SNAPSHOT_DIR is set (TEST_RUNNER_SNAPSHOT_DIR in the workflow).
@MainActor
final class SnapshotTests: XCTestCase {
    func testRenderResultCards() throws {
        guard let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else {
            throw XCTSkip("SNAPSHOT_DIR not set")
        }
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let cases: [(String, Reconstitution, Mass, SyringeModel)] = [
            ("classic-10u-1ml", try Reconstitution(vial: .mg(5), waterMl: 2), .mcg(250), .ml10),
            ("fda-5u-1ml", try Reconstitution(vial: .mg(5), waterMl: 2), .mcg(125), .ml10),
            ("half-unit-03ml", try Reconstitution(vial: .mg(10), waterMl: 1), .mcg(230), .ml03HalfUnit),
            ("two-draws-03ml", try Reconstitution(vial: .mg(10), waterMl: 2), .mg(d("2.5")), .ml03),
            ("two-unit-1ml", try Reconstitution(vial: .mg(10), waterMl: d("2.5")), .mg(d("1.2")), .ml10TwoUnit),
        ]
        for (name, reconstitution, dose, syringe) in cases {
            let draw = try reconstitution.draw(dose, with: syringe)
            for scheme in [ColorScheme.dark, .light] {
                let card = ResultCard(draw: draw, syringe: syringe, reconstitution: reconstitution, dose: dose)
                    .padding(20)
                    .frame(width: 390)
                    .background(PLBackground())
                    .fontDesign(.rounded)
                    .environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: card)
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage)
                let suffix = scheme == .dark ? "dark" : "light"
                try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent("\(name)-\(suffix).png"))
            }
        }
    }

    /// Full screens at iPhone size. Prices are absent in the simulator (no
    /// StoreKit configuration), which is also how the paywall looks offline.
    func testRenderScreens() throws {
        guard let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else {
            throw XCTSkip("SNAPSHOT_DIR not set")
        }
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let screens: [(String, AnyView)] = [
            ("screen-paywall", AnyView(PaywallView())),
            ("screen-exit-offer", AnyView(ExitOfferView())),
            ("screen-onboarding-welcome", AnyView(OnboardingView().environmentObject(DataStore.shared))),
            ("screen-dose-logged", AnyView(DoseLoggedView(starCount: 18, summary: "Semaglutide · 0.25 mg", dosesLeft: 15,
                                                         next: Date(timeIntervalSince1970: 1_800_000_000)) {})),
            ("body-map", AnyView(BodyMapView(
                selection: .constant(SiteZone(site: .thigh, side: .left)),
                lastUse: [SiteZone(site: .abdomen, side: .left): Date(),
                          SiteZone(site: .abdomen, side: .right): Date().addingTimeInterval(-6 * 86_400),
                          SiteZone(site: .glute, side: .right): Date().addingTimeInterval(-9 * 86_400)])
                .padding(30)
                .background(PLBackground()))),
        ]
        for (name, view) in screens {
            let renderer = ImageRenderer(content: view.frame(width: 393, height: 852)
                .fontDesign(.rounded).environment(\.colorScheme, .dark))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent("\(name).png"))
        }
    }

    /// The doctor report's pages from a sample journal, as PNGs and as the PDF.
    func testRenderDoctorReport() throws {
        guard let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else {
            throw XCTSkip("SNAPSHOT_DIR not set")
        }
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var journal = Journal()
        let sema = Compound(name: "Semaglutide", halfLifeHours: 168)
        journal.save(sema)
        let start = Date().addingTimeInterval(-60 * 86_400)
        journal.save(Regimen(compoundID: sema.id, dose: DoseAmount(value: d("0.5"), unit: .mg),
                             schedule: DoseSchedule(pattern: .everyNDays(7), start: start, end: nil,
                                                    times: [TimeOfDay(hour: 9, minute: 0)])))
        for week in 0..<8 {
            let day = start.addingTimeInterval(Double(week) * 7 * 86_400 + 3600)
            journal.save(DoseEntry(date: day, compoundID: sema.id, amount: DoseAmount(value: d("0.5"), unit: .mg),
                                   site: week % 2 == 0 ? .abdomen : .thigh, side: week % 4 < 2 ? .left : .right,
                                   notes: week == 2 ? "Slight nausea the next day" : ""))
            journal.save(WeightEntry(date: day, kilograms: Decimal(104 - week)))
        }
        journal.save(SideEffectEntry(date: start.addingTimeInterval(15 * 86_400), symptom: .nausea, severity: 2))
        journal.save(SideEffectEntry(date: start.addingTimeInterval(30 * 86_400), symptom: .fatigue, severity: 1))
        let data = ReportData.make(journal, from: start, through: Date(), now: Date(), calendar: .current)
        let size = DoctorReport.pageSize
        for (index, page) in DoctorReport.pages(data, journal: journal, unit: .kilograms).enumerated() {
            let renderer = ImageRenderer(content: page.frame(width: size.width, height: size.height)
                .fontDesign(.rounded).environment(\.colorScheme, .light))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent("report-page-\(index + 1).png"))
        }
        let pdf = try XCTUnwrap(DoctorReport.write(data, journal: journal, unit: .kilograms))
        try FileManager.default.copyItem(at: pdf, to: folder.appendingPathComponent("report.pdf"))
    }
}
