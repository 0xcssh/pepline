import SwiftUI

/// Nutrition: protein, water and calories of one day against the goals the
/// user set (GLP-1 users eat less, so protein and water are what MeAgain and
/// Shotsy track first), quick adds and the day's foods. Pepline suggests no
/// target.
struct NutritionView: View {
    @EnvironmentObject private var store: DataStore
    @State private var day = Calendar.current.startOfDay(for: Date())
    @State private var adding = false
    @State private var editingGoals = false
    @State private var editing: FoodEntry?

    private var calendar: Calendar { .current }
    private var journal: Journal { store.journal }
    private var totals: NutritionTotals { journal.nutrition(on: day, calendar: calendar) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                dayPicker
                ringsCard
                quickAddCard
                foodsCard
            }
            .padding(20)
        }
        .background(PLBackground())
        .navigationTitle(Text("Nutrition"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { editingGoals = true } label: { Image(systemName: "target") }
                    .accessibilityLabel(Text("Goals"))
                Button { adding = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text("Add food"))
            }
        }
        .sheet(isPresented: $adding) { AddFoodSheet(day: day) }
        .sheet(isPresented: $editingGoals) { NutritionGoalsSheet(goals: journal.nutritionGoals) }
        .sheet(item: $editing) { entry in FoodEditor(entry: entry, isNew: false) }
    }

    // MARK: Day

    private var dayPicker: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel(Text("Previous day"))
            Spacer()
            Group {
                if calendar.isDateInToday(day) {
                    Text("Today")
                } else {
                    Text(day, format: .dateTime.weekday(.wide).day().month())
                }
            }
            .font(.headline)
            .foregroundStyle(PLColor.text)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .disabled(calendar.isDateInToday(day))
                .accessibilityLabel(Text("Next day"))
        }
        .tint(PLColor.accent)
    }

    private func shift(_ days: Int) {
        if let next = calendar.date(byAdding: .day, value: days, to: day) { day = next }
    }

    // MARK: Rings

    private var ringsCard: some View {
        let goals = journal.nutritionGoals
        return VStack(spacing: 16) {
            HStack(alignment: .top) {
                NutritionRing(title: Text("Protein"), value: totals.protein, goal: goals.protein,
                              valueText: "\(Fmt.number(totals.protein, digits: 0)) g", color: PLColor.accent)
                NutritionRing(title: Text("Water"), value: totals.waterMl, goal: goals.waterMl,
                              valueText: Fmt.water(totals.waterMl), color: PLColor.water)
                NutritionRing(title: Text("Calories"), value: totals.kcal, goal: goals.kcal,
                              valueText: Fmt.number(totals.kcal, digits: 0), color: PLColor.warning)
            }
            HStack {
                macro(Text("Carbs"), totals.carbs)
                macro(Text("Fat"), totals.fat)
                macro(Text("Fiber"), totals.fiber)
            }
            if goals == NutritionGoals() {
                Button { editingGoals = true } label: { Text("Set your daily goals") }
                    .font(.subheadline.weight(.semibold))
                    .tint(PLColor.accent)
            }
        }
        .plCard()
    }

    private func macro(_ title: Text, _ grams: Decimal) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(Fmt.number(grams, digits: 0)) g").font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(PLColor.text)
            title.font(.caption).foregroundStyle(PLColor.muted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Quick add

    private var quickAddCard: some View {
        HStack(spacing: 10) {
            quick(Text(verbatim: "+250 ml"), "drop.fill", PLColor.water) { addWater(250) }
            quick(Text(verbatim: "+500 ml"), "waterbottle.fill", PLColor.water) { addWater(500) }
            quick(Text("+10 g protein"), "bolt.fill", PLColor.accent) { addProtein(10) }
        }
    }

    private func quick(_ title: Text, _ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).foregroundStyle(color)
                title.font(.footnote.weight(.semibold)).foregroundStyle(PLColor.text)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .plCard()
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.increase, trigger: totals)
    }

    private var entryDate: Date {
        calendar.isDateInToday(day) ? Date() : calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    private func addWater(_ ml: Decimal) {
        store.update { $0.save(WaterEntry(date: entryDate, milliliters: ml)) }
        Analytics.track(.waterLogged)
    }

    private func addProtein(_ grams: Decimal) {
        let item = FoodItem(name: String(localized: "Protein"), protein: grams)
        store.update { $0.save(FoodEntry(date: entryDate, item: item)) }
        Analytics.track(.foodLogged, ["source": FoodSource.manual.rawValue])
    }

    // MARK: Foods

    @ViewBuilder
    private var foodsCard: some View {
        let foods = journal.foods(on: day, calendar: calendar)
        let water = journal.water.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
        if foods.isEmpty && water.isEmpty {
            VStack(spacing: 12) {
                PulseRings(symbol: "fork.knife", size: 110)
                Text("Log a meal by search, barcode or photo.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PLColor.muted)
                Button { adding = true } label: { Text("Add food") }.buttonStyle(.primaryPill)
            }
            .frame(maxWidth: .infinity)
            .plCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(foods) { entry in
                    Button { editing = entry } label: { foodRow(entry) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.update { $0.deleteFood(entry.id) }
                            } label: { Label { Text("Delete") } icon: { Image(systemName: "trash") } }
                        }
                }
                ForEach(water) { entry in
                    HStack {
                        Image(systemName: "drop.fill").foregroundStyle(PLColor.water).frame(width: 28)
                        Text(verbatim: Fmt.water(entry.milliliters)).foregroundStyle(PLColor.text)
                        Spacer()
                        Text(entry.date, style: .time).font(.caption).foregroundStyle(PLColor.muted)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            store.update { $0.deleteWater(entry.id) }
                        } label: { Label { Text("Delete") } icon: { Image(systemName: "trash") } }
                    }
                }
                // Always there: logging the next meal is the main action.
                Button { adding = true } label: {
                    Label { Text("Add food") } icon: { Image(systemName: "plus") }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryPill)
                .padding(.top, 4)
            }
            .plCard()
        }
    }

    private func foodRow(_ entry: FoodEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.item.source.symbol)
                .foregroundStyle(PLColor.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: entry.item.name).foregroundStyle(PLColor.text).lineLimit(2)
                HStack(spacing: 6) {
                    if entry.servings != 1 {
                        Text(verbatim: "× \(Fmt.number(entry.servings, digits: 2))")
                    }
                    Text("\(Fmt.number(entry.item.protein * entry.servings, digits: 1)) g protein")
                }
                .font(.caption)
                .foregroundStyle(PLColor.muted)
            }
            Spacer()
            Text(verbatim: "\(Fmt.number(entry.item.kcal * entry.servings, digits: 0)) kcal")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(PLColor.muted)
        }
        .contentShape(Rectangle())
    }
}

extension FoodSource {
    var symbol: String {
        switch self {
        case .manual: return "square.and.pencil"
        case .search: return "magnifyingglass"
        case .barcode: return "barcode"
        case .photo: return "sparkles"
        }
    }
}

/// A progress ring: full at the goal, value in the middle. Without a goal it
/// shows the value on a faint track.
private struct NutritionRing: View {
    let title: Text
    let value: Decimal
    let goal: Decimal?
    let valueText: String
    let color: Color

    private var progress: Double {
        guard let goal, goal > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: value / goal).doubleValue, 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.5), radius: progress >= 1 ? 6 : 0)
                    .animation(.spring(duration: 0.6), value: progress)
                VStack(spacing: 0) {
                    Text(verbatim: valueText)
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(PLColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let goal, goal > 0 {
                        Text(verbatim: "/ \(Fmt.number(goal, digits: 0))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(PLColor.muted)
                    }
                }
                .padding(12)
            }
            .frame(width: 92, height: 92)
            title.font(.caption.weight(.semibold)).foregroundStyle(PLColor.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Daily goals, all optional, chosen by the user.
struct NutritionGoalsSheet: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var protein: String
    @State private var water: String
    @State private var kcal: String
    @State private var fiber: String

    init(goals: NutritionGoals) {
        _protein = State(initialValue: goals.protein.map(Fmt.plain) ?? "")
        _water = State(initialValue: goals.waterMl.map(Fmt.plain) ?? "")
        _kcal = State(initialValue: goals.kcal.map(Fmt.plain) ?? "")
        _fiber = State(initialValue: goals.fiber.map(Fmt.plain) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DecimalField(title: "Protein", text: $protein, unit: "g")
                    DecimalField(title: "Water", text: $water, unit: "ml")
                    DecimalField(title: "Calories", text: $kcal, unit: "kcal")
                    DecimalField(title: "Fiber", text: $fiber, unit: "g")
                } footer: {
                    Text("Set the targets agreed with your doctor or dietitian. Leave a field empty for no goal.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(PLBackground())
            .navigationTitle(Text("Daily goals"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    private func save() {
        func goal(_ text: String) -> Decimal? { decimalValue(text).flatMap { $0 > 0 ? $0 : nil } }
        let goals = NutritionGoals(kcal: goal(kcal), protein: goal(protein), fiber: goal(fiber), waterMl: goal(water))
        store.update { $0.nutritionGoals = goals }
        dismiss()
    }
}
