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
        ]
        for (name, view) in screens {
            let renderer = ImageRenderer(content: view.frame(width: 393, height: 852)
                .fontDesign(.rounded).environment(\.colorScheme, .dark))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent("\(name).png"))
        }
    }
}
