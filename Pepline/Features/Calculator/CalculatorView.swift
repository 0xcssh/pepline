import SwiftUI

/// The calculator, V2: four numbered steps (vial, water, dose, syringe) as
/// cards with big numerals, the live "draw to" value floating above the
/// keyboard while typing, then the full result with the syringe drawn to
/// scale. Saved vials sit on top, one tap to reload.
struct CalculatorView: View {
    @EnvironmentObject private var store: DataStore
    @StateObject private var model = CalculatorModel()
    @State private var savingVial = false
    @FocusState private var focus: Field?

    private enum Field: Hashable { case vial, water, dose, factor }

    var body: some View {
        scroller
            .navigationTitle(Text("Calculator"))
            .toolbar { toolbar }
            .sheet(isPresented: $savingVial) {
                SaveVialSheet(model: model)
            }
            .onAppear {
                if model.loadedVialID == nil, model.vialText.isEmpty, let preferred = store.journal.preferredSyringe {
                    model.syringe = preferred
                }
            }
            .onChange(of: model.draw != nil) { _, hasResult in
                guard hasResult, let draw = model.draw else { return }
                Analytics.track(.calculatorResult, [
                    "syringe": "\(model.syringe.capacityMl)ml-\(model.syringe.tickUnits)u",
                    "doseUnit": model.doseUnit.rawValue,
                    "warnings": String(draw.warnings.count),
                ])
            }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if model.loadedVialID != nil || !model.vialText.isEmpty {
                Button("Clear") { model.clear() }
            }
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { focus = nil }
        }
    }

    private var scroller: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SavedVialsStrip(model: model)
                    vialStep
                    waterStep
                    doseStep
                    syringeStep
                    result.id("result")
                    DisclaimerText()
                        .padding(.horizontal, 4)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PLBackground())
            .safeAreaInset(edge: .bottom) {
                // While typing, the answer stays in sight above the keyboard;
                // a tap closes the keyboard and scrolls to the full result.
                if let draw = model.draw, focus != nil {
                    LiveDrawPill(units: draw.units) {
                        focus = nil
                        withAnimation(.spring(duration: 0.5)) { proxy.scrollTo("result", anchor: .top) }
                    }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4), value: model.draw?.units)
        }
    }

    // MARK: Steps

    private var vialStep: some View {
        StepCard(number: 1, title: Text("Powder in the vial"), done: decimalValue(model.vialText).map { $0 > 0 } ?? false) {
            NumberEntry(title: Text("Powder in the vial"), text: $model.vialText)
                .focused($focus, equals: .vial)
            ChipPicker(selection: $model.vialUnit, options: [(DoseUnit.mg, "mg"), (DoseUnit.iu, Fmt.symbol(.iu))])
        }
    }

    private var waterStep: some View {
        StepCard(number: 2, title: Text("Bacteriostatic water"), done: decimalValue(model.waterText).map { $0 > 0 } ?? false) {
            NumberEntry(title: Text("Bacteriostatic water"), text: $model.waterText, unit: "ml")
                .focused($focus, equals: .water)
            HStack(spacing: 8) {
                ForEach([1, 2, 3], id: \.self) { ml in
                    Button { model.waterText = String(ml) } label: { Text(verbatim: Fmt.ml(Decimal(ml))) }
                        .buttonStyle(ChipStyle(selected: decimalValue(model.waterText) == Decimal(ml)))
                }
            }
        }
    }

    private var doseStep: some View {
        StepCard(number: 3, title: Text("Dose"), done: model.dose != nil) {
            NumberEntry(title: Text("Dose"), text: $model.doseText)
                .focused($focus, equals: .dose)
            ChipPicker(selection: $model.doseUnit, options: DoseUnit.allCases.map { ($0, Fmt.symbol($0)) })
            if model.needsIUFactor {
                VStack(alignment: .leading, spacing: 6) {
                    Text("IU per mg (from the label)").font(.subheadline).foregroundStyle(PLColor.muted)
                    NumberEntry(title: Text("IU per mg (from the label)"), text: $model.iuPerMgText, size: 28)
                        .focused($focus, equals: .factor)
                }
                .padding(.top, 4)
            }
        }
    }

    private var syringeStep: some View {
        StepCard(number: 4, title: Text("Syringe"), done: true) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SyringeModel.presets, id: \.self) { syringe in
                        SyringeChoice(syringe: syringe, selected: model.syringe == syringe) {
                            model.syringe = syringe
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Result

    @ViewBuilder
    private var result: some View {
        if let draw = model.draw, let reconstitution = model.reconstitution, let dose = model.dose {
            VStack(spacing: 16) {
                ResultCard(draw: draw, syringe: model.syringe, reconstitution: reconstitution, dose: dose)
                if model.loadedVialID == nil {
                    Button { savingVial = true } label: {
                        Label { Text("Save this vial") } icon: { Image(systemName: "tray.and.arrow.down.fill") }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryPill)
                }
            }
            .plCard()
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        } else {
            VStack(spacing: 14) {
                SyringeView(syringe: model.syringe, units: 0)
                    .frame(height: 70)
                    .opacity(0.5)
                Text("Fill in the vial, the water and the dose to see the units to draw.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PLColor.muted)
            }
            .frame(maxWidth: .infinity)
            .plCard()
        }
    }
}

/// A big rounded number field. Accepts "0,25" and "0.25" alike and, when
/// the text has two readings ("1,250"), asks which one instead of guessing.
private struct NumberEntry: View {
    let title: Text
    @Binding var text: String
    var unit: String?
    var size: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField(text: $text, prompt: Text(verbatim: "0")) { title }
                    .keyboardType(.decimalPad)
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(PLColor.text)
                if let unit {
                    Text(verbatim: unit).font(.title3.weight(.semibold)).foregroundStyle(PLColor.muted)
                }
            }
            if let parsed = DecimalInput.parse(text), let alternative = parsed.alternative {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill").foregroundStyle(PLColor.warning)
                    Text("Did you mean").font(.footnote).foregroundStyle(PLColor.text)
                    choice(parsed.value)
                    choice(alternative)
                }
            }
        }
    }

    private func choice(_ value: Decimal) -> some View {
        Button {
            text = Fmt.plain(value)
            Analytics.track(.ambiguousInputResolved)
        } label: {
            Text(verbatim: Fmt.plain(value))
        }
        .buttonStyle(ChipStyle(selected: false))
    }
}

/// One numbered step: badge (a check once filled), title, content.
private struct StepCard<Content: View>: View {
    let number: Int
    let title: Text
    let done: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(done ? PLColor.accent : PLColor.accent.opacity(0.12))
                    if done {
                        Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(PLColor.onAccent)
                    } else {
                        Text(verbatim: String(number)).font(.caption.weight(.heavy)).foregroundStyle(PLColor.accent)
                    }
                }
                .frame(width: 26, height: 26)
                .animation(.spring(duration: 0.35), value: done)
                title.font(.headline).foregroundStyle(PLColor.text)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard()
    }
}

/// Unit choice as capsules.
private struct ChipPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options.indices, id: \.self) { index in
                Button { selection = options[index].0 } label: { Text(verbatim: options[index].1) }
                    .buttonStyle(ChipStyle(selected: selection == options[index].0))
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct ChipStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? PLColor.onAccent : PLColor.text)
            .background(selected ? PLColor.accent : PLColor.accent.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? PLColor.accent : PLColor.line))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.25), value: selected)
    }
}

/// A syringe preset as a small card: barrel size big, marks below.
private struct SyringeChoice: View {
    let syringe: SyringeModel
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "syringe.fill")
                    .foregroundStyle(selected ? PLColor.accent : PLColor.muted)
                Text(verbatim: Fmt.ml(syringe.capacityMl))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(PLColor.text)
                Text("Marks: \(Fmt.number(syringe.tickUnits, digits: 1)) U")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(PLColor.muted)
            }
            .padding(12)
            .frame(width: 100, alignment: .leading)
            .background(selected ? PLColor.accent.opacity(0.12) : PLColor.card,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(selected ? PLColor.accent : PLColor.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityLabel(Text(verbatim: syringe.label))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The live answer while typing, floating above the keyboard.
private struct LiveDrawPill: View {
    let units: Decimal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("Draw to").font(.subheadline).foregroundStyle(PLColor.muted)
                Text(verbatim: Fmt.number(units))
                    .plNumeral(size: 28)
                    .foregroundStyle(PLColor.accent)
                    .plGlow()
                    .contentTransition(.numericText())
                Text("units").font(.subheadline.weight(.semibold)).foregroundStyle(PLColor.text)
                Image(systemName: "chevron.down.circle.fill").foregroundStyle(PLColor.accent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(PLColor.accent.opacity(0.4)))
            .shadow(color: PLColor.accent.opacity(0.25), radius: 16)
        }
        .buttonStyle(.plain)
    }
}

/// Shown under the calculator, the schedules and in Settings (App Review
/// 1.4.1 / 1.4.2 — see docs/SOURCES.md).
struct DisclaimerText: View {
    var body: some View {
        Text("Unit conversion only. Pepline does not recommend doses. Follow your prescriber and check with your doctor.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

/// Saved vials as cards in a row: tap to reload, hold to archive.
private struct SavedVialsStrip: View {
    @EnvironmentObject private var store: DataStore
    @ObservedObject var model: CalculatorModel

    private var vials: [Vial] {
        store.journal.vials.filter { !$0.isArchived }.sorted { $0.mixedAt > $1.mixedAt }
    }

    var body: some View {
        if !vials.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Saved vials").font(.headline).foregroundStyle(PLColor.text)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vials) { vial in
                            Button { load(vial) } label: { card(vial) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        store.update { journal in
                                            var archived = vial
                                            archived.isArchived = true
                                            journal.save(archived)
                                        }
                                    } label: {
                                        Label { Text("Archive") } icon: { Image(systemName: "archivebox") }
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func regimen(for vial: Vial) -> Regimen? {
        store.journal.regimens.first { $0.compoundID == vial.compoundID }
    }

    private func load(_ vial: Vial) {
        model.load(vial, compound: store.journal.compound(vial.compoundID), regimenDose: regimen(for: vial)?.dose)
    }

    private func card(_ vial: Vial) -> some View {
        let journal = store.journal
        let compound = journal.compound(vial.compoundID)
        let remaining = journal.remaining(in: vial)
        let selected = model.loadedVialID == vial.id
        let share = vial.reconstitution.vial.mcg > 0
            ? min(max(NSDecimalNumber(decimal: remaining.mcg / vial.reconstitution.vial.mcg).doubleValue, 0), 1) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "flask.fill").foregroundStyle(PLColor.accent)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(PLColor.accent)
                }
            }
            Text(verbatim: compound?.name ?? "—")
                .font(.headline)
                .foregroundStyle(PLColor.text)
                .lineLimit(1)
            Text(verbatim: "\(Fmt.mass(vial.reconstitution.vial)) + \(Fmt.ml(vial.reconstitution.waterMl))")
                .font(.caption)
                .foregroundStyle(PLColor.muted)
            ProgressView(value: share).tint(PLColor.accent)
            Text("\(Fmt.mass(remaining)) left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PLColor.text)
            if let regimen = regimen(for: vial),
               let dose = regimen.dose.mass(compound?.iuConversion),
               let runOut = VialForecast.runOutDate(remaining: remaining, dose: dose, schedule: regimen.schedule,
                                                    after: Date(), calendar: .current) {
                Text("Runs out on \(runOut.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(PLColor.muted)
            }
        }
        .padding(14)
        .frame(width: 170, alignment: .leading)
        .background(selected ? PLColor.accent.opacity(0.12) : PLColor.card,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(selected ? PLColor.accent : PLColor.line, lineWidth: selected ? 1.5 : 1))
    }
}

private struct SaveVialSheet: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: CalculatorModel
    @State private var choice = CompoundChoice()
    @State private var mixedAt = Date()

    var body: some View {
        NavigationStack {
            Form {
                CompoundField(choice: $choice)
                DatePicker("Mixed on", selection: $mixedAt, displayedComponents: .date)
            }
            .plScreen()
            .navigationTitle("Save vial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!choice.isValid || model.reconstitution == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let reconstitution = model.reconstitution else { return }
        let factor = model.iuConversion
        store.update { journal in
            let compoundID = choice.resolve(in: &journal)
            if let factor, var compound = journal.compound(compoundID), compound.iuConversion == nil {
                compound.iuConversion = factor
                journal.save(compound)
            }
            let vial = Vial(compoundID: compoundID, reconstitution: reconstitution,
                            syringe: model.syringe, mixedAt: mixedAt)
            journal.save(vial)
            model.load(vial, compound: journal.compound(compoundID), regimenDose: nil)
        }
        Analytics.track(.vialSaved)
        dismiss()
    }
}
