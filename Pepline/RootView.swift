import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DataStore
    @State private var showingSettings = false
    @ObservedObject private var subs = SubscriptionManager.shared
    @AppStorage("cancelSurveyAsked") private var surveyAsked = false

    /// Auto-renew found off (cancelled in Apple's settings): ask why, once.
    private var askWhyCancelled: Binding<Bool> {
        Binding(get: { subs.entitlementChecked && subs.isPro && !subs.willAutoRenew && !surveyAsked },
                set: { if !$0 { surveyAsked = true } })
    }

    var body: some View {
        // Three tabs (decision 2026-10-17): Today is the daily loop (next
        // dose, one-tap log, nutrition, the week); Journal is the past
        // (calendar, progress, report); Tools holds the calculator and vials.
        TabView {
            tab { TodayView() }
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            tab { JournalTab() }
                .tabItem { Label("Journal", systemImage: "calendar") }
            tab { CalculatorView() }
                .tabItem { Label("Tools", systemImage: "syringe") }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: askWhyCancelled) { CancelSurveyView() }
        .safeAreaInset(edge: .top) {
            if store.loadError != nil {
                Text("Your saved data could not be read. Nothing was deleted. Please contact support from Settings.")
                    .font(.footnote)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(.orange.opacity(0.2))
            }
        }
    }

    /// Each tab: its own navigation stack with the Settings button.
    private func tab<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel(Text("Settings"))
                    }
                }
        }
    }
}

/// History (calendar, doses, side effects) and Progress (weight, photos,
/// levels, report) under one tab, switched at the top.
private struct JournalTab: View {
    private enum Section: String { case history, progress }
    @AppStorage("journalSection") private var section = Section.history

    var body: some View {
        Group {
            switch section {
            case .history: HistoryView()
            case .progress: ProgressTab()
            }
        }
        .safeAreaInset(edge: .top) {
            Picker(selection: $section) {
                Text("History").tag(Section.history)
                Text("Progress").tag(Section.progress)
            } label: { Text("Journal") }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
        }
    }
}
