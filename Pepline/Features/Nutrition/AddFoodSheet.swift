import PhotosUI
import SwiftUI

/// Every way to log a food: search, barcode, meal photo estimate, manual,
/// favourites and recents. Nothing is saved before the user confirms it in
/// `FoodEditor` (or the photo review).
struct AddFoodSheet: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    /// Day being logged (time of day is "now").
    let day: Date

    @AppStorage("foodScanConsent") private var scanConsent = false
    @State private var query = ""
    @State private var results: [FoodItem] = []
    @State private var searching = false
    @State private var message: Text?
    @State private var editing: FoodEntry?
    @State private var scanningBarcode = false
    @State private var scannedCode: String?
    @State private var askingConsent = false
    @State private var photoAfterConsent = false
    @State private var takingPhoto = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var estimating = false
    @State private var estimate: ScanEstimate?

    private var entryDate: Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return Date() }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        sourceButton(Text("Barcode"), "barcode.viewfinder") { scanningBarcode = true }
                            .disabled(!BarcodeScannerView.isAvailable)
                        sourceButton(Text("Meal photo"), "camera.viewfinder") {
                            if scanConsent { takingPhoto = true } else { askingConsent = true }
                        }
                        sourceButton(Text("Manual"), "square.and.pencil") { edit(FoodItem(name: "")) }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if let message {
                    Section { message.font(.footnote).foregroundStyle(PLColor.warning) }
                }
                if searching {
                    Section { ProgressView().frame(maxWidth: .infinity) }
                } else if !results.isEmpty {
                    Section { ForEach(results, id: \.self, content: row) } header: { Text("Results") }
                }
                if !store.journal.favoriteFoods.isEmpty {
                    Section { ForEach(store.journal.favoriteFoods, id: \.self, content: row) } header: { Text("Favorites") }
                }
                let recents = store.journal.recentFoods()
                if !recents.isEmpty {
                    Section { ForEach(recents, id: \.self, content: row) } header: { Text("Recent") }
                }
                Section {
                    Text("Food data © Open Food Facts contributors, ODbL.")
                        .font(.caption2)
                        .foregroundStyle(PLColor.muted)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PLBackground())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search foods"))
            .onSubmit(of: .search) { Task { await search() } }
            .navigationTitle(Text("Add food"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .overlay {
                if estimating {
                    VStack(spacing: 14) {
                        PulseRings(symbol: "sparkles", size: 110)
                        Text("Estimating your meal…").font(.headline).foregroundStyle(PLColor.text)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .sheet(item: $editing) { entry in FoodEditor(entry: entry, isNew: true) }
        .sheet(item: $estimate) { estimate in ScanReviewView(items: estimate.items, date: entryDate) }
        .sheet(isPresented: $askingConsent, onDismiss: {
            // The camera opens once the consent sheet is gone.
            if photoAfterConsent { photoAfterConsent = false; takingPhoto = true }
        }) {
            ScanConsentView {
                scanConsent = true
                photoAfterConsent = true
                askingConsent = false
            }
            .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $scanningBarcode, onDismiss: {
            // Looked up once the scanner is gone, so the editor sheet that
            // follows can present.
            guard let code = scannedCode else { return }
            scannedCode = nil
            Task { await lookup(code) }
        }) {
            NavigationStack {
                BarcodeScannerView { code in
                    scannedCode = code
                    scanningBarcode = false
                }
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { scanningBarcode = false } }
                }
            }
        }
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraPicker { image in Task { await scan(image) } }.ignoresSafeArea()
        }
    }

    private func sourceButton(_ title: Text, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title2).foregroundStyle(PLColor.accent)
                title.font(.footnote.weight(.semibold)).foregroundStyle(PLColor.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .plCard()
        }
        .buttonStyle(.plain)
    }

    private func row(_ item: FoodItem) -> some View {
        Button { edit(item) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: item.name).foregroundStyle(PLColor.text).lineLimit(2)
                    Text("\(Fmt.number(item.protein, digits: 1)) g protein")
                        .font(.caption)
                        .foregroundStyle(PLColor.muted)
                }
                Spacer()
                Text(verbatim: "\(Fmt.number(item.kcal, digits: 0)) kcal")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(PLColor.muted)
            }
        }
    }

    private func edit(_ item: FoodItem) {
        editing = FoodEntry(date: entryDate, item: item)
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }
        searching = true
        message = nil
        defer { searching = false }
        do {
            results = try await FoodService.search(trimmed)
            if results.isEmpty { message = Text("No food found. Try other words or add it manually.") }
        } catch {
            message = Text("Search is unavailable right now. Check your connection.")
        }
    }

    private func lookup(_ code: String) async {
        message = nil
        do {
            edit(try await FoodService.lookup(barcode: code))
        } catch FoodService.Failure.notFound {
            message = Text("This barcode is not in Open Food Facts yet. Add the food manually.")
            edit(FoodItem(name: "", source: .barcode, barcode: code))
        } catch {
            message = Text("Search is unavailable right now. Check your connection.")
        }
    }

    private func scan(_ image: UIImage) async {
        estimating = true
        message = nil
        defer { estimating = false }
        do {
            let items = try await FoodService.scan(image, appUserID: SubscriptionManager.shared.appUserID)
            Analytics.track(.foodScanned, ["items": String(items.count)])
            if items.isEmpty {
                message = Text("No food recognised in this photo.")
            } else {
                estimate = ScanEstimate(items: items)
            }
        } catch FoodService.Failure.notPro {
            message = Text("Meal photo estimates are part of Pepline Pro.")
        } catch FoodService.Failure.rateLimited {
            message = Text("Too many photos in the last hour. Try again later.")
        } catch {
            message = Text("The estimate is unavailable right now. Try again or add the food manually.")
        }
    }
}

struct ScanEstimate: Identifiable {
    let id = UUID()
    var items: [FoodItem]
}

/// The foods estimated from a photo, each editable and optional, saved
/// together only when the user confirms.
struct ScanReviewView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [FoodEntry]
    @State private var included: Set<FoodEntry.ID>
    @State private var editing: FoodEntry?

    init(items: [FoodItem], date: Date) {
        let entries = items.map { FoodEntry(date: date, item: $0) }
        _entries = State(initialValue: entries)
        _included = State(initialValue: Set(entries.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(entries) { entry in
                        HStack(spacing: 12) {
                            Button {
                                if included.contains(entry.id) { included.remove(entry.id) } else { included.insert(entry.id) }
                            } label: {
                                Image(systemName: included.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(included.contains(entry.id) ? PLColor.accent : PLColor.muted)
                            }
                            .buttonStyle(.plain)
                            Button { editing = entry } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(verbatim: entry.item.name).foregroundStyle(PLColor.text)
                                        Text("\(Fmt.number(entry.item.protein, digits: 1)) g protein")
                                            .font(.caption).foregroundStyle(PLColor.muted)
                                    }
                                    Spacer()
                                    Text(verbatim: "\(Fmt.number(entry.item.kcal * entry.servings, digits: 0)) kcal")
                                        .font(.subheadline.monospacedDigit()).foregroundStyle(PLColor.muted)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(PLColor.muted)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } footer: {
                    Text("AI estimate: check the values before saving.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(PLBackground())
            .navigationTitle(Text("Meal estimate"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(included.isEmpty)
                }
            }
            .sheet(item: $editing) { entry in
                FoodEditor(entry: entry, isNew: true) { edited in
                    if let index = entries.firstIndex(where: { $0.id == edited.id }) { entries[index] = edited }
                }
            }
        }
    }

    private func save() {
        let chosen = entries.filter { included.contains($0.id) }
        store.update { journal in chosen.forEach { journal.save($0) } }
        Analytics.track(.foodLogged, ["source": FoodSource.photo.rawValue, "count": String(chosen.count)])
        dismiss()
    }
}

/// Asked once before the first meal photo (App Review 5.1.2(i): disclose
/// what is shared with a third-party AI and get permission first).
struct ScanConsentView: View {
    @Environment(\.dismiss) private var dismiss
    let onAllow: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PulseRings(symbol: "camera.viewfinder", size: 120)
                        .frame(maxWidth: .infinity)
                    Text("Meal photo estimate")
                        .font(.title2.bold())
                        .foregroundStyle(PLColor.text)
                    FeatureLine(symbol: "paperplane", text: Text("Your photo is sent to OpenAI, a third-party AI service, through Pepline's server, only to estimate the foods and their macros."))
                    FeatureLine(symbol: "trash", text: Text("Pepline does not keep the photo. Nothing else from your journal is sent."))
                    FeatureLine(symbol: "pencil", text: Text("Estimates can be wrong. You check and edit them before anything is saved."))
                    FeatureLine(symbol: "hand.raised", text: Text("You can turn this off at any time in Settings."))
                }
                .padding(24)
            }
            .background(PLBackground())
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button { onAllow() } label: { Text("Allow and take a photo").frame(maxWidth: .infinity) }
                        .buttonStyle(.primaryPill)
                    Button { dismiss() } label: { Text("Not now") }
                        .foregroundStyle(PLColor.muted)
                }
                .padding(20)
            }
        }
    }
}
