import SwiftUI
import SwitchMyGitCore

/// The menu shown from the menu bar. Built from standard menu items so it
/// looks and behaves like the system's own status menus.
struct MenuBarMenu: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        statusSection
        Divider()
        profilesSection
        rulesSection
        Divider()
        Button("Check Repository…") {
            Task { await RepositoryCheck.run(appState: appState) }
        }
        .keyboardShortcut("k")
        Divider()
        Button("Settings…") { showSettings(.general) }
            .keyboardShortcut(",")
        Button("Quit SwitchMyGit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    // MARK: Sections

    @ViewBuilder
    private var statusSection: some View {
        switch appState.health {
        case .loading:
            Text("Checking Git Configuration…")
        case .notSetUp:
            Text("SwitchMyGit Is Off")
            Button("Turn On…") { showSettings(appState.profiles.isEmpty ? .profiles : .general) }
        case .noDefaultProfile:
            Text("No Default Profile")
        case let .defaultOverridden(actual):
            Text("~/.gitconfig Overrides Your Default (\(actual.email ?? "no e-mail"))")
            if !(appState.status?.unmanagedIdentity.isEmpty ?? true) {
                Button("Remove Override") {
                    Task { await appState.removeUnmanagedIdentity() }
                }
            }
        case .healthy:
            Text("Committing as \(appState.status?.globalIdentity.email ?? "")")
        }
    }

    @ViewBuilder
    private var profilesSection: some View {
        Section("Default Profile") {
            if appState.profiles.isEmpty {
                Button("Add Profile…") { showSettings(.profiles) }
            }
            ForEach(appState.profiles) { profile in
                Toggle(profile.name, isOn: Binding(
                    get: { profile.id == appState.configuration.defaultProfileID },
                    set: { _ in Task { await appState.setDefault(profile) } }
                ))
                .disabled(appState.isWorking)
            }
        }
    }

    @ViewBuilder
    private var rulesSection: some View {
        let rules = appState.orderedRules.filter(\.isEnabled)
        if !rules.isEmpty {
            Divider()
            Section("Rules") {
                ForEach(rules.reversed()) { rule in
                    Button("\(rule.pattern)  →  \(appState.profile(for: rule.profileID)?.name ?? "?")") {
                        showSettings(.rules)
                    }
                }
            }
        }
    }

    private func showSettings(_ tab: SettingsTab) {
        appState.settingsTab = tab
        NSApp.activate()
        openSettings()
    }
}
