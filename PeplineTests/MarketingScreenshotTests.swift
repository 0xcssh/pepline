import SwiftUI
import XCTest
@testable import Pepline

/// Six App Store screenshots (iPhone 6.7", 1290 × 2796), one folder per App Store
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

    /// Order = the sales story: the daily gesture first, then exactness,
    /// rotation, nutrition, motivation, the doctor. Each frame: a benefit
    /// headline + one selling argument. No medical outcome is promised and no
    /// brand drug name is used (5.2.1).
    private let captions: [String: [(String, String)]] = [
        "en": [("Log your shot in one tap", "The units to draw and a rested site, ready when you are."),
               ("Exact units, zero guesswork", "Vial, water, dose: drawn to scale on your own syringe."),
               ("Never reuse the same spot", "The most rested injection site lights up for you."),
               ("Protein & water on track", "Search, scan a barcode or snap your meal."),
               ("Watch your consistency grow", "Every dose lights a star. Reminders keep the streak."),
               ("Your doctor sees it all", "One PDF: doses, adherence, weight, side effects.")],
        "fr": [("Notez votre injection d'un geste", "Les unités à prélever et un site reposé, prêts pour vous."),
               ("Des unités exactes, sans calcul", "Flacon, eau, dose : dessinée à l'échelle sur votre seringue."),
               ("Ne piquez plus au même endroit", "Le site le plus reposé s'allume pour vous."),
               ("Protéines et eau sous contrôle", "Recherche, code-barres ou photo de votre repas."),
               ("Voyez votre régularité grandir", "Chaque dose allume une étoile. Les rappels tiennent la série."),
               ("Votre médecin voit tout", "Un PDF : doses, observance, poids, effets secondaires.")],
        "es": [("Registra tu inyección con un toque", "Las unidades a cargar y una zona descansada, listas."),
               ("Unidades exactas, sin cálculos", "Vial, agua, dosis: dibujada a escala en tu jeringa."),
               ("No repitas la misma zona", "La zona más descansada se ilumina para ti."),
               ("Proteína y agua bajo control", "Busca, escanea un código o fotografía tu comida."),
               ("Mira crecer tu constancia", "Cada dosis enciende una estrella. Los recordatorios mantienen la racha."),
               ("Tu médico lo ve todo", "Un PDF: dosis, adherencia, peso, efectos secundarios.")],
        "de": [("Injektion mit einem Tipp erfasst", "Die Einheiten zum Aufziehen und eine geschonte Stelle, sofort bereit."),
               ("Exakte Einheiten, kein Rechnen", "Fläschchen, Wasser, Dosis: maßstabsgetreu auf deiner Spritze."),
               ("Nie wieder dieselbe Stelle", "Die am längsten geschonte Stelle leuchtet für dich auf."),
               ("Protein und Wasser im Blick", "Suchen, Barcode scannen oder die Mahlzeit fotografieren."),
               ("Sieh deine Regelmäßigkeit wachsen", "Jede Dosis entzündet einen Stern. Erinnerungen halten die Serie."),
               ("Deine Ärztin sieht alles", "Ein PDF: Dosen, Therapietreue, Gewicht, Nebenwirkungen.")],
        "it": [("Registra l'iniezione con un tocco", "Le unità da aspirare e un sito riposato, già pronti."),
               ("Unità esatte, zero calcoli", "Flaconcino, acqua, dose: disegnata in scala sulla tua siringa."),
               ("Mai più lo stesso punto", "Il sito più riposato si illumina per te."),
               ("Proteine e acqua sotto controllo", "Cerca, scansiona un codice o fotografa il pasto."),
               ("Guarda crescere la tua costanza", "Ogni dose accende una stella. I promemoria tengono la serie."),
               ("Il tuo medico vede tutto", "Un PDF: dosi, aderenza, peso, effetti collaterali.")],
        "pt-BR": [("Registre a aplicação com um toque", "As unidades a aspirar e um local descansado, prontos."),
                  ("Unidades exatas, sem cálculo", "Frasco, água, dose: desenhada em escala na sua seringa."),
                  ("Nunca repita o mesmo local", "O local mais descansado acende para você."),
                  ("Proteína e água em dia", "Busque, leia um código de barras ou fotografe a refeição."),
                  ("Veja sua constância crescer", "Cada dose acende uma estrela. Os lembretes mantêm a sequência."),
                  ("Seu médico vê tudo", "Um PDF: doses, adesão, peso, efeitos colaterais.")],
        "ja": [("注射の記録はワンタップ", "吸う単位数と休ませた部位がすぐわかる。"),
               ("正確な単位数、計算不要", "バイアル・水・用量を、あなたのシリンジに縮尺どおり表示。"),
               ("同じ部位に打たない", "最も休ませた部位が光ってお知らせ。"),
               ("タンパク質と水分を管理", "検索、バーコード、食事の写真で記録。"),
               ("続ける力が見える", "投与ごとに星が灯る。リマインダーで連続記録を維持。"),
               ("医師にすべて見せられる", "1つのPDFに投与・実施率・体重・副作用。")],
        "ko": [("한 번의 탭으로 투여 기록", "채울 단위와 쉬었던 부위를 바로 보여 드려요."),
               ("정확한 단위, 계산 없이", "바이알, 물, 용량을 내 주사기에 실제 비율로."),
               ("같은 부위는 이제 그만", "가장 오래 쉰 부위가 빛나요."),
               ("단백질과 수분 관리", "검색, 바코드 스캔, 식사 사진으로 기록."),
               ("꾸준함이 쌓이는 게 보여요", "투여마다 별 하나. 알림으로 연속 기록 유지."),
               ("의사에게 한눈에", "하나의 PDF: 투여, 이행률, 체중, 부작용.")],
        "zh-Hans": [("一键记录每次注射", "要抽取的单位数和休息过的部位，随时就绪。"),
                    ("精确单位，无需计算", "药瓶、加水量、剂量，按比例画在你的注射器上。"),
                    ("不再重复同一部位", "休息最久的部位为你点亮。"),
                    ("蛋白质和饮水不掉队", "搜索、扫条形码或拍下你的餐食。"),
                    ("看见坚持的力量", "每一剂点亮一颗星，提醒帮你保持连续。"),
                    ("医生一目了然", "一份 PDF：剂量、依从性、体重、副作用。")],
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
                    format.scale = image.scale  // keep 1290 x 2796 pixels, not 430 x 932 points
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
        let now = Date()
        let today = AnyView(NextDoseCard(title: "Semaglutide · 0.5 mg", date: now.addingTimeInterval(-600), now: now,
                                         units: d("20"), syringe: .ml05, zone: SiteZone(site: .thigh, side: .left)))

        let result = AnyView(ResultCard(draw: draw, syringe: .ml05, reconstitution: reconstitution, dose: dose)
            .padding(20).plCard())

        let bodyMap = AnyView(BodyMapView(
            selection: .constant(SiteZone(site: .thigh, side: .left)),
            lastUse: [SiteZone(site: .abdomen, side: .left): now,
                      SiteZone(site: .abdomen, side: .right): now.addingTimeInterval(-6 * 86_400),
                      SiteZone(site: .glute, side: .right): now.addingTimeInterval(-9 * 86_400)])
            .padding(20).plCard())

        let logged = AnyView(DoseLoggedView(starCount: 24, summary: "Semaglutide · 0.5 mg", dosesLeft: 6,
                                            next: nil) {}
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
        let nutrition = AnyView(VStack(alignment: .leading, spacing: 14) {
            NutritionRingsRow(totals: NutritionTotals(kcal: 1240, protein: 86, carbs: 110, fat: 38, fiber: 18, waterMl: 1750),
                              goals: NutritionGoals(kcal: 1600, protein: 110, fiber: 25, waterMl: 2500))
            ForEach(Array(["Greek yogurt (170 g)", "Grilled chicken, ~150 g", "Protein shake"].enumerated()), id: \.offset) { index, name in
                HStack {
                    Image(systemName: ["barcode", "sparkles", "magnifyingglass"][index]).foregroundStyle(PLColor.accent).frame(width: 28)
                    Text(verbatim: name).foregroundStyle(PLColor.text)
                    Spacer()
                    Text(verbatim: ["16 g", "46 g", "24 g"][index]).font(.subheadline.monospacedDigit()).foregroundStyle(PLColor.muted)
                }
            }
        }
        .plCard())
        return [today, result, bodyMap, nutrition, logged, report]
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
