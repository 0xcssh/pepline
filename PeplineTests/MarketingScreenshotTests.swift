import SwiftUI
import XCTest
@testable import Pepline

/// App Store screenshots (iPhone 6.7", 1290 × 2796), one folder per App Store
/// locale under SNAPSHOT_DIR/appstore, uploaded by scripts/asc_screenshots.py.
/// Each frame: a localized caption over a real app component with sample
/// data. Captions are marketing copy for the store, not app strings.
@MainActor
final class MarketingScreenshotTests: XCTestCase {
    /// App language → App Store locale; en-GB/AU/CA reuse en-US at upload.
    private let locales: [(app: String, store: String)] = [
        ("en", "en-US"), ("fr", "fr-FR"), ("es", "es-ES"), ("de", "de-DE"), ("it", "it"),
        ("pt-BR", "pt-BR"), ("ja", "ja"), ("ko", "ko"), ("zh-Hans", "zh-Hans"),
    ]

    private let captions: [String: [(String, String)]] = [
        "en": [("Exact units on your syringe", "Vial, water, dose. Drawn to scale."),
               ("Rotate your sites", "The most rested spot, at a glance."),
               ("Every dose, one star", "Log in one tap. Watch your streak grow."),
               ("A report for your doctor", "Doses, adherence, weight, side effects.")],
        "fr": [("Les unités exactes sur votre seringue", "Flacon, eau, dose. Dessinée à l'échelle."),
               ("Variez vos sites d'injection", "Le site le plus reposé, d'un coup d'œil."),
               ("Chaque dose, une étoile", "Notée d'un geste. Votre série grandit."),
               ("Un rapport pour votre médecin", "Doses, observance, poids, effets secondaires.")],
        "es": [("Unidades exactas en tu jeringa", "Vial, agua, dosis. Dibujada a escala."),
               ("Rota tus zonas", "La zona más descansada, de un vistazo."),
               ("Cada dosis, una estrella", "Regístrala con un toque. Tu racha crece."),
               ("Un informe para tu médico", "Dosis, adherencia, peso, efectos secundarios.")],
        "de": [("Genaue Einheiten auf deiner Spritze", "Fläschchen, Wasser, Dosis. Maßstabsgetreu."),
               ("Wechsle deine Stellen", "Die am längsten geschonte Stelle auf einen Blick."),
               ("Jede Dosis ein Stern", "Mit einem Tipp erfasst. Deine Serie wächst."),
               ("Ein Bericht für deine Ärztin", "Dosen, Therapietreue, Gewicht, Nebenwirkungen.")],
        "it": [("Unità esatte sulla tua siringa", "Flaconcino, acqua, dose. Disegnata in scala."),
               ("Alterna i siti", "Il sito più riposato, a colpo d'occhio."),
               ("Ogni dose, una stella", "Registrala con un tocco. La tua serie cresce."),
               ("Un report per il medico", "Dosi, aderenza, peso, effetti collaterali.")],
        "pt-BR": [("Unidades exatas na sua seringa", "Frasco, água, dose. Desenhada em escala."),
                  ("Faça o rodízio dos locais", "O local mais descansado, num relance."),
                  ("Cada dose, uma estrela", "Registre com um toque. Sua sequência cresce."),
                  ("Um relatório para o médico", "Doses, adesão, peso, efeitos colaterais.")],
        "ja": [("シリンジに正確な単位数", "バイアル・水・用量。縮尺どおりに表示。"),
               ("注射部位をローテーション", "最も休ませた部位がひと目でわかる。"),
               ("投与ごとに星がひとつ", "ワンタップで記録。連続記録が伸びる。"),
               ("医師向けレポート", "投与、実施率、体重、副作用。")],
        "ko": [("주사기에 정확한 단위", "바이알, 물, 용량. 실제 비율 그대로."),
               ("주사 부위를 순환하세요", "가장 오래 쉰 부위를 한눈에."),
               ("투여마다 별 하나", "한 번에 기록. 연속 기록이 늘어나요."),
               ("의사용 보고서", "투여, 이행률, 체중, 부작용.")],
        "zh-Hans": [("注射器上的精确单位", "药瓶、加水量、剂量。按比例绘制。"),
                    ("轮换注射部位", "休息最久的部位，一目了然。"),
                    ("每一剂，一颗星", "一键记录，连续天数不断增长。"),
                    ("给医生的报告", "剂量、依从性、体重、副作用。")],
    ]

    func testRenderAppStoreScreenshots() throws {
        guard let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else {
            throw XCTSkip("SNAPSHOT_DIR not set")
        }
        let root = URL(fileURLWithPath: directory).appendingPathComponent("appstore")
        let components = try sampleComponents()
        for (app, store) in locales {
            let folder = root.appendingPathComponent(store)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for (index, caption) in (captions[app] ?? []).enumerated() {
                let frame = MarketingFrame(title: caption.0, subtitle: caption.1) { components[index] }
                    .environment(\.locale, Locale(identifier: app))
                    .environment(\.colorScheme, .dark)
                    .fontDesign(.rounded)
                    .frame(width: 430, height: 932)
                let renderer = ImageRenderer(content: frame)
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage)
                // App Store screenshots must not have an alpha channel.
                let opaque = UIGraphicsImageRenderer(size: image.size, format: {
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    format.opaque = true
                    return format
                }()).image { _ in image.draw(at: .zero) }
                try XCTUnwrap(opaque.pngData()).write(to: folder.appendingPathComponent("\(index + 1).png"))
            }
        }
    }

    /// The four app components, with realistic sample data.
    private func sampleComponents() throws -> [AnyView] {
        let reconstitution = try Reconstitution(vial: .mg(5), waterMl: 2)
        let dose = Mass.mcg(250)
        let draw = try reconstitution.draw(dose, with: .ml05)
        let result = AnyView(ResultCard(draw: draw, syringe: .ml05, reconstitution: reconstitution, dose: dose)
            .padding(20).plCard())

        let now = Date()
        let bodyMap = AnyView(BodyMapView(
            selection: .constant(SiteZone(site: .thigh, side: .left)),
            lastUse: [SiteZone(site: .abdomen, side: .left): now,
                      SiteZone(site: .abdomen, side: .right): now.addingTimeInterval(-6 * 86_400),
                      SiteZone(site: .glute, side: .right): now.addingTimeInterval(-9 * 86_400)])
            .padding(20).plCard())

        let logged = AnyView(DoseLoggedView(starCount: 24, summary: "Semaglutide · 0.5 mg", dosesLeft: 6,
                                            next: now.addingTimeInterval(7 * 86_400)) {}
            .frame(height: 640)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous)))

        var journal = Journal()
        let sema = Compound(name: "Semaglutide", halfLifeHours: 168)
        journal.save(sema)
        let start = now.addingTimeInterval(-60 * 86_400)
        journal.save(Regimen(compoundID: sema.id, dose: DoseAmount(value: d("0.5"), unit: .mg),
                             schedule: DoseSchedule(pattern: .everyNDays(7), start: start, end: nil,
                                                    times: [TimeOfDay(hour: 9, minute: 0)])))
        for week in 0..<8 {
            let day = start.addingTimeInterval(Double(week) * 7 * 86_400 + 3600)
            journal.save(DoseEntry(date: day, compoundID: sema.id, amount: DoseAmount(value: d("0.5"), unit: .mg)))
            journal.save(WeightEntry(date: day, kilograms: Decimal(104) - Decimal(week) * d("0.9")))
        }
        journal.save(SideEffectEntry(date: start.addingTimeInterval(15 * 86_400), symptom: .nausea, severity: 2))
        let data = ReportData.make(journal, from: start, through: now, now: now, calendar: .current)
        let size = DoctorReport.pageSize
        let report = AnyView(DoctorReport.pages(data, journal: journal, unit: .kilograms)[0]
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .light)
            .scaleEffect(0.62)
            .frame(width: size.width * 0.62, height: size.height * 0.62)
            .clipShape(RoundedRectangle(cornerRadius: 12)))
        return [result, bodyMap, logged, report]
    }
}

/// Caption on top, the app component below, on the app's background.
private struct MarketingFrame<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 14) {
            Text(verbatim: title)
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(PLColor.text)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .padding(.top, 70)
            Text(verbatim: subtitle)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(PLColor.accent)
                .multilineTextAlignment(.center)
            Spacer(minLength: 20)
            content()
            Spacer(minLength: 30)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PLBackground())
    }
}
