import SwiftUI

/// The icon in the menu bar.
///
/// The label exists from launch, so it also opens Settings on first run.
struct MenuBarLabel: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings
    @AppStorage("hasCompletedFirstLaunch") private var hasCompletedFirstLaunch = false

    var body: some View {
        Image(nsImage: MenuBarIcon.image(isOn: appState.health == .healthy))
            .task(id: appState.health) {
                guard !hasCompletedFirstLaunch, appState.health == .notSetUp else { return }
                hasCompletedFirstLaunch = true
                appState.settingsTab = appState.profiles.isEmpty ? .profiles : .general
                NSApp.activate()
                openSettings()
            }
    }
}
