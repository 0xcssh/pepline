import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DataStore
    @State private var showingSettings = false

    var body: some View {
        TabView {
            tab { CalculatorView() }
                .tabItem { Label("Calculator", systemImage: "syringe") }
            tab { JournalView() }
                .tabItem { Label("Journal", systemImage: "list.bullet.rectangle") }
            tab { SchedulesView() }
                .tabItem { Label("Schedules", systemImage: "calendar") }
            tab { WeightView() }
                .tabItem { Label("Weight", systemImage: "chart.xyaxis.line") }
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
