import SwiftUI

/// The standard Settings window with toolbar tabs.
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.settingsTab) {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            ProfilesSettingsView()
                .tabItem { Label("Profiles", systemImage: "person.2") }
                .tag(SettingsTab.profiles)
            RulesSettingsView()
                .tabItem { Label("Rules", systemImage: "arrow.triangle.branch") }
                .tag(SettingsTab.rules)
        }
        .frame(width: 680, height: 480)
        .task { await appState.refresh() }
    }
}
