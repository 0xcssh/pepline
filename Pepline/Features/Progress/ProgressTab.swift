import Charts
import PhotosUI
import SwiftUI

/// Progress: weight results (Shotsy's header), the curve coloured by the dose
/// in force, side-effect days, progress photos, estimated levels, Apple Health.
struct ProgressTab: View {
    @EnvironmentObject private var store: DataStore
    @ObservedObject private var health = HealthService.shared
    @AppStorage(WeightUnitSetting.key) private var unitSetting = WeightUnitSetting.defaultValue
    @State private var addingWeight = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var takingPhoto = false
    @State private var comparing = false

    private var unit: UnitMass { WeightUnitSetting.unit(unitSetting) }
    private var journal: Journal { store.journal }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statsCard
                chartCard
                photosCard
                levelsCard
                healthCard
            }
            .padding(20)
        }
        .background(PLBackground())
        .navigationTitle(Text("Progress"))
        .toolbar {
            Button { addingWeight = true } label: { Image(systemName: "plus") }
                .accessibilityLabel(Text("Log weight"))
        }
        .sheet(isPresented: $addingWeight) { WeightEditor(draft: WeightEditor.Draft(), unit: unit) }
        .sheet(isPresented: $comparing) { PhotoCompareView() }
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraPicker { image in savePhoto(image) }.ignoresSafeArea()
        }
        .onChange(of: pickerItem) {
            guard let item = pickerItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    savePhoto(image)
                }
                pickerItem = nil
            }
        }
        .task { await health.importWeights(into: store) }
    }

    // MARK: Stats

    @ViewBuilder
    private var statsCard: some View {
        if let stats = WeightStats.compute(journal.weights, goalKg: journal.goalWeightKg) {
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 12) {
                stat(Text("Change"), signed(stats.changeKg))
                stat(Text("Percent"), "\(Fmt.number(stats.changePercent, digits: 1)) %")
                stat(Text("Now"), Fmt.weight(stats.latestKg, in: unit))
                stat(Text("Start"), Fmt.weight(stats.startKg, in: unit))
                stat(Text("Per week"), stats.weeklyChangeKg.map(signed) ?? "—")
                stat(Text("To goal"), stats.toGoalKg.map { Fmt.weight(max($0, 0), in: unit) } ?? "—")
            }
            .plCard()
        } else {
            VStack(spacing: 12) {
                PulseRings(symbol: "scalemass.fill", size: 110)
                Text("Log your weight to see your progress here.").foregroundStyle(PLColor.muted)
                Button { addingWeight = true } label: { Text("Log weight") }.buttonStyle(.primaryPill)
            }
            .frame(maxWidth: .infinity)
            .plCard()
        }
    }

    private func signed(_ kg: Decimal) -> String {
        (kg > 0 ? "+" : "") + Fmt.weight(kg, in: unit)
    }

    private func stat(_ title: Text, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title.font(.caption).foregroundStyle(PLColor.muted)
            Text(verbatim: value).font(.headline.monospacedDigit()).foregroundStyle(PLColor.text)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Chart

    /// The compound whose dose colours the curve: the one with a schedule.
    private var mainCompoundID: Compound.ID? { journal.regimens.first?.compoundID ?? journal.compounds.first?.id }

    @ViewBuilder
    private var chartCard: some View {
        let series = journal.weightSeries
        if series.count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Weight").font(.headline).foregroundStyle(PLColor.text)
                    Spacer()
                    NavigationLink { WeightView() } label: { Text("All weigh-ins").font(.subheadline) }
                }
                Chart {
                    ForEach(series) { entry in
                        let value = NSDecimalNumber(decimal: Fmt.weightValue(entry.kilograms, in: unit)).doubleValue
                        let dose = mainCompoundID.flatMap { WeightStats.activeDose(at: entry.date, compoundID: $0, in: journal) }
                        LineMark(x: .value("Date", entry.date), y: .value("Weight", value))
                            .foregroundStyle(by: .value("Dose", dose.map(Fmt.dose) ?? "—"))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", entry.date), y: .value("Weight", value))
                            .foregroundStyle(by: .value("Dose", dose.map(Fmt.dose) ?? "—"))
                            .symbolSize(24)
                    }
                    if let goal = journal.goalWeightKg {
                        RuleMark(y: .value("Goal", NSDecimalNumber(decimal: Fmt.weightValue(goal, in: unit)).doubleValue))
                            .foregroundStyle(PLColor.accent.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
                    ForEach(sideEffectDays, id: \.self) { day in
                        RuleMark(x: .value("Date", day))
                            .foregroundStyle(PLColor.warning.opacity(0.25))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartLegend(position: .bottom)
                .frame(height: 240)
                if !sideEffectDays.isEmpty {
                    Label { Text("Side effect logged") } icon: {
                        Rectangle().fill(PLColor.warning.opacity(0.5)).frame(width: 3, height: 12)
                    }
                    .font(.caption)
                    .foregroundStyle(PLColor.muted)
                }
            }
            .plCard()
        }
    }

    private var sideEffectDays: [Date] {
        Array(Set(journal.sideEffects.map { Calendar.current.startOfDay(for: $0.date) })).sorted()
    }

    // MARK: Photos

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress photos").font(.headline).foregroundStyle(PLColor.text)
                Spacer()
                if journal.photos.count >= 2 {
                    Button { comparing = true } label: { Text("Compare") }.font(.subheadline.weight(.semibold))
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Menu {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button { takingPhoto = true } label: { Label("Take a photo", systemImage: "camera") }
                        }
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label("Choose from library", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.title2.weight(.semibold))
                            Text("Add").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(PLColor.accent)
                        .frame(width: 90, height: 120)
                        .background(PLColor.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    ForEach(journal.photoSeries.reversed()) { photo in
                        PhotoThumb(photo: photo)
                            .contextMenu {
                                Button("Delete", role: .destructive) { deletePhoto(photo) }
                            }
                    }
                }
            }
            Text("Photos stay on this iPhone.").font(.caption).foregroundStyle(PLColor.muted)
        }
        .plCard()
    }

    private func savePhoto(_ image: UIImage) {
        guard let name = PhotoStore.save(image) else { return }
        store.update { $0.save(ProgressPhoto(date: Date(), fileName: name)) }
        Analytics.track(.photoAdded)
    }

    private func deletePhoto(_ photo: ProgressPhoto) {
        PhotoStore.delete(named: photo.fileName)
        store.update { $0.deletePhoto(photo.id) }
    }

    // MARK: Levels

    @ViewBuilder
    private var levelsCard: some View {
        let compounds = journal.compounds.filter { !journal.levelDoses(of: $0.id).isEmpty }
        if !compounds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Estimated levels").font(.headline).foregroundStyle(PLColor.text)
                ForEach(compounds) { compound in
                    NavigationLink { LevelsView(compoundID: compound.id) } label: {
                        HStack {
                            Image(systemName: "waveform.path").foregroundStyle(PLColor.accent)
                            Text(verbatim: compound.name).foregroundStyle(PLColor.text)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(PLColor.muted)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .plCard()
        }
    }

    // MARK: Apple Health

    @ViewBuilder
    private var healthCard: some View {
        if health.isAvailable {
            HStack(spacing: 14) {
                Image(systemName: "heart.fill").font(.title2).foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health").font(.headline).foregroundStyle(PLColor.text)
                    Text("Read and save your weight in Health.").font(.footnote).foregroundStyle(PLColor.muted)
                }
                Spacer()
                Toggle("Apple Health", isOn: Binding(
                    get: { health.isOn },
                    set: { on in
                        if on { Task { await health.enable(into: store) } } else { health.isOn = false }
                    }
                ))
                .labelsHidden()
            }
            .plCard()
        }
    }
}

private struct PhotoThumb: View {
    let photo: ProgressPhoto

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let image = PhotoStore.image(named: photo.fileName) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    PLColor.card
                }
            }
            .frame(width: 90, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(verbatim: photo.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(PLColor.muted)
        }
    }
}

/// Two photos side by side with a draggable divider.
struct PhotoCompareView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var before: ProgressPhoto.ID?
    @State private var after: ProgressPhoto.ID?
    @State private var split: CGFloat = 0.5

    private var photos: [ProgressPhoto] { store.journal.photoSeries }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        image(after ?? photos.last?.id)
                        image(before ?? photos.first?.id)
                            .mask(alignment: .leading) { Rectangle().frame(width: proxy.size.width * split) }
                        Rectangle().fill(PLColor.accent).frame(width: 3)
                            .offset(x: proxy.size.width * split - 1.5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        split = min(max(value.location.x / proxy.size.width, 0), 1)
                    })
                }
                HStack {
                    picker(Text("Before"), selection: $before, fallback: photos.first?.id)
                    picker(Text("After"), selection: $after, fallback: photos.last?.id)
                }
            }
            .padding(20)
            .background(PLBackground())
            .navigationTitle(Text("Compare"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func image(_ id: ProgressPhoto.ID?) -> some View {
        let photo = photos.first { $0.id == id }
        return Group {
            if let photo, let image = PhotoStore.image(named: photo.fileName) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                PLColor.card
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func picker(_ title: Text, selection: Binding<ProgressPhoto.ID?>, fallback: ProgressPhoto.ID?) -> some View {
        Menu {
            ForEach(photos) { photo in
                Button(photo.date.formatted(date: .abbreviated, time: .omitted)) { selection.wrappedValue = photo.id }
            }
        } label: {
            VStack(spacing: 2) {
                title.font(.caption).foregroundStyle(PLColor.muted)
                Text(verbatim: photos.first { $0.id == (selection.wrappedValue ?? fallback) }?
                    .date.formatted(date: .abbreviated, time: .omitted) ?? "—")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .plCard()
        }
    }
}

/// UIKit camera for progress photos.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
