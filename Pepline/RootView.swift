import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DataStore
    @State private var showingSettings = false

    var body: some View {
        // Today first: the daily loop (Shotsy, Peptide Tracker). Schedules
        // are reached from Today; the full dose list from History.
        TabView {
            tab { TodayView() }
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            tab { CalculatorView() }
                .tabItem { Label("Calculator", systemImage: "syringe") }
            tab { HistoryView() }
                .tabItem { Label("History", systemImage: "calendar") }
            tab { ProgressTab() }
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
            tab { NutritionView() }
                .tabItem { Label("Nutrition", systemImage: "fork.knife") }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
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
