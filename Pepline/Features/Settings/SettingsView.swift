import AuthenticationServices
import StoreKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightUnitSetting.key) private var unitSetting = WeightUnitSetting.defaultValue
    @State private var deleting: Compound?
    /// Hidden developer menu (tap the version 7 times): lets the owner see
    /// the paywall and the onboarding again on a subscribed device. Its
    /// labels are not localized on purpose: no user ever sees them.
    @AppStorage("developerMenu") private var developerMenu = false
    @AppStorage("onboardingDone") private var onboardingDone = true
    @State private var versionTaps = 0
    @AppStorage("foodScanConsent") private var scanConsent = false
    @State private var previewingPaywall = false
    @State private var showingReport = false
    @State private var previewingExitOffer = false
    @ObservedObject private var account = AppleAccount.shared
    @State private var confirmingAccountDeletion = false
    @State private var accountDeletionFailed = false
    @State private var eraseJournalWithAccount = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight unit") {
                    Picker("Weight unit", selection: $unitSetting) {
                        Text(verbatim: UnitMass.kilograms.symbol).tag("kg")
                        Text(verbatim: UnitMass.pounds.symbol).tag("lb")
                    }
                    .pickerStyle(.segmented)
                }

                if !store.journal.compounds.isEmpty {
                    Section {
                        ForEach(store.journal.compounds.sorted { $0.name < $1.name }) { compound in
                            NavigationLink {
                                CompoundEditor(compound: compound)
                            } label: {
                                Text(verbatim: compound.name)
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) { deleting = compound }
                            }
                        }
                    } header: {
                        Text("Compounds")
                    }
                }

                Section {
                    Button { showingReport = true } label: {
                        Label("Doctor report (PDF)", systemImage: "doc.richtext")
                    }
                    ShareLink(item: exportFile("pepline-doses.csv", CSVExport.doses(store.journal, timeZone: .current))) {
                        Label("Export doses (CSV)", systemImage: "square.and.arrow.up")
                    }
                    .simultaneousGesture(TapGesture().onEnded { Analytics.track(.exported, ["kind": "doses"]) })
                    ShareLink(item: exportFile("pepline-weight.csv", CSVExport.weights(store.journal, timeZone: .current))) {
                        Label("Export weight (CSV)", systemImage: "square.and.arrow.up")
                    }
                    .simultaneousGesture(TapGesture().onEnded { Analytics.track(.exported, ["kind": "weight"]) })
                } header: {
                    Text("Export")
                }

                Section {
                    if account.isSignedIn {
                        Label("Signed in with Apple", systemImage: "checkmark.circle.fill")
                        Toggle("Also erase my journal", isOn: $eraseJournalWithAccount)
                        Button("Delete my account", role: .destructive) { confirmingAccountDeletion = true }
                    } else {
                        SignInWithAppleButton(.signIn) { $0.requestedScopes = [.fullName] } onCompletion: { result in
                            Task { await account.handle(result) }
                        }
                        .frame(height: 44)
                    }
                    Button("Manage subscription") {
                        Task {
                            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                            try? await AppStore.showManageSubscriptions(in: scene)
                        }
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Signing in only ties Pepline Pro to your Apple ID. Deleting the account revokes Pepline's access at Apple.")
                }

                Section {
                    Toggle("Meal photo estimates", isOn: $scanConsent)
                    Link(destination: URL(string: "https://world.openfoodfacts.org")!) {
                        Text("Food data © Open Food Facts contributors, ODbL.")
                            .font(.footnote)
                    }
                } header: {
                    Text("Nutrition")
                } footer: {
                    Text("Meal photos are sent to Anthropic's Claude for the estimate only, and are not kept.")
                }

                Section {
                    Link(destination: URL(string: "mailto:awdianthony@gmail.com?subject=Pepline")!) {
                        Label("Contact support", systemImage: "envelope")
                    }
                } footer: {
                    Text("Your data stays on this iPhone. No account, no cloud.")
                }

                Section {
                    DisclaimerText()
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text(verbatim: "Pepline \(version)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .onTapGesture {
                                versionTaps += 1
                                if versionTaps >= 7 { developerMenu = true }
                            }
                    }
                }

                if developerMenu {
                    Section {
                        Button { previewingPaywall = true } label: { Text(verbatim: "Show paywall") }
                        Button { previewingExitOffer = true } label: { Text(verbatim: "Show exit offer") }
                        Button {
                            UserDefaults.standard.set(false, forKey: "exitOfferShown")
                            onboardingDone = false
                            dismiss()
                        } label: { Text(verbatim: "Replay onboarding") }
                        Button(role: .destructive) { developerMenu = false } label: { Text(verbatim: "Hide developer menu") }
                    } header: {
                        Text(verbatim: "Developer")
                    }
                }
            }
            .plScreen()
            .sheet(isPresented: $previewingPaywall) { PaywallView(preview: true) }
            .sheet(isPresented: $showingReport) { DoctorReportSheet() }
            .sheet(isPresented: $previewingExitOffer) { ExitOfferView() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog(Text("Delete your account?"), isPresented: $confirmingAccountDeletion,
                                titleVisibility: .visible) {
                Button("Delete my account", role: .destructive) { deleteAccount() }
            } message: {
                Text("Your subscription stays active until you cancel it in your App Store settings.")
            }
            .alert("The account could not be deleted", isPresented: $accountDeletionFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check your connection and try again, or contact support.")
            }
            .confirmationDialog(
                Text("Delete \(deletingName)?"),
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete it with its doses, vials and schedules", role: .destructive) {
                    if let id = deleting?.id { store.update { $0.deleteCompound(id) } }
                    deleting = nil
                }
            }
        }
    }

    private var deletingName: String { deleting?.name ?? "" }

    private func deleteAccount() {
        let erase = eraseJournalWithAccount
        Task {
            do {
                try await account.deleteAccount()
                if erase { store.update { $0 = Journal() } }
                Analytics.track(.accountDeleted, ["result": "success", "erasedJournal": String(erase)])
            } catch {
                accountDeletionFailed = true
                Analytics.track(.accountDeleted, ["result": "failed"])
            }
        }
    }

    /// The CSV written to a temporary file so the share sheet sends a real
    /// .csv attachment (Mail, Files, Numbers).
    private func exportFile(_ name: String, _ contents: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

private struct CompoundEditor: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var compound: Compound
    @State private var iuText: String
    @State private var halfLifeText: String

    init(compound: Compound) {
        _compound = State(initialValue: compound)
        _iuText = State(initialValue: compound.iuConversion.map { Fmt.plain($0.iuPerMg) } ?? "")
        _halfLifeText = State(initialValue: compound.halfLifeHours.map { Fmt.plain($0) } ?? "")
    }

    var body: some View {
        Form {
            TextField("Compound name", text: $compound.name)
            Section {
                DecimalField(title: "IU per mg (from the label)", text: $iuText)
            } footer: {
                Text("Only for compounds dosed in IU. Leave empty otherwise.")
            }
            Section {
                DecimalField(title: "Half-life (hours, from the label)", text: $halfLifeText, unit: "h")
            } footer: {
                Text("Used only to draw the estimated level. Leave empty if your label does not state it.")
            }
        }
        .plScreen()
        .navigationTitle(Text(verbatim: compound.name))
        .toolbar {
            Button("Save") {
                var edited = compound
                edited.name = edited.name.trimmingCharacters(in: .whitespaces)
                edited.iuConversion = decimalValue(iuText).map(IUConversion.init(iuPerMg:)).flatMap { $0.isValid ? $0 : nil }
                edited.halfLifeHours = decimalValue(halfLifeText).flatMap { $0 > 0 ? $0 : nil }
                store.update { $0.save(edited) }
                dismiss()
            }
            .disabled(compound.name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
