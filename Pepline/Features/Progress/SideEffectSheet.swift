import SwiftUI

/// Quick side-effect log: pick what you feel, how strong, when.
struct SideEffectSheet: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var symptom: SideEffectEntry.Symptom?
    @State private var customName = ""
    @State private var severity = 2.0
    @State private var date = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("What do you feel?")
                        .font(.title2.bold())
                        .foregroundStyle(PLColor.text)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(SideEffectEntry.Symptom.allCases, id: \.self) { item in
                            ChoiceTile(symbol: item.symbol, title: item.title, selected: symptom == item) {
                                symptom = item
                            }
                        }
                    }
                    if symptom == .other {
                        TextField("Describe it", text: $customName)
                            .padding(14)
                            .plCard()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Intensity").font(.headline).foregroundStyle(PLColor.text)
                            Spacer()
                            severityLabel.font(.subheadline.weight(.semibold)).foregroundStyle(PLColor.accent)
                        }
                        Slider(value: $severity, in: 1...5, step: 1)
                            .tint(PLColor.accent)
                            .sensoryFeedback(.selection, trigger: severity)
                    }
                    .plCard()
                    DatePicker("When", selection: $date)
                        .padding(14)
                        .plCard()
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(14)
                        .plCard()
                }
                .padding(20)
            }
            .background(PLBackground())
            .navigationTitle(Text("Side effect"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(symptom == nil)
                }
            }
        }
    }

    private var severityLabel: Text {
        switch Int(severity) {
        case 1: return Text("Very mild")
        case 2: return Text("Mild")
        case 3: return Text("Moderate")
        case 4: return Text("Strong")
        default: return Text("Severe")
        }
    }

    private func save() {
        guard let symptom else { return }
        let entry = SideEffectEntry(date: date, symptom: symptom,
                                    customName: customName.trimmingCharacters(in: .whitespaces),
                                    severity: Int(severity), notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
        store.update { $0.save(entry) }
        Analytics.track(.sideEffectLogged, ["symptom": symptom.rawValue, "severity": String(Int(severity))])
        dismiss()
    }
}

extension SideEffectEntry.Symptom {
    var title: Text {
        switch self {
        case .nausea: return Text("Nausea")
        case .constipation: return Text("Constipation")
        case .diarrhea: return Text("Diarrhea")
        case .reflux: return Text("Reflux")
        case .fatigue: return Text("Fatigue")
        case .headache: return Text("Headache")
        case .lowAppetite: return Text("Low appetite")
        case .injectionSite: return Text("Injection-site reaction")
        case .other: return Text("Other")
        }
    }

    var symbol: String {
        switch self {
        case .nausea: return "face.dashed"
        case .constipation: return "arrow.down.to.line"
        case .diarrhea: return "drop.triangle"
        case .reflux: return "flame"
        case .fatigue: return "battery.25percent"
        case .headache: return "brain.head.profile"
        case .lowAppetite: return "fork.knife"
        case .injectionSite: return "bandage"
        case .other: return "ellipsis.circle"
        }
    }
}
