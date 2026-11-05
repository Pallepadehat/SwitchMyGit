import SwiftUI
import SwitchMyGitCore

/// Turning management on and off, the default profile, and app preferences.
struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var isConfirmingActivation = false
    @State private var isConfirmingDeactivation = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: managementBinding) {
                    Text("Manage Git identity")
                    Text("Sets your default identity and applies repository rules through Git’s own configuration, so they work in every terminal and editor — even when SwitchMyGit isn’t running.")
                }
                .disabled(appState.isWorking || appState.status == nil)

                if appState.isActive {
                    Picker("Default profile", selection: defaultProfileBinding) {
                        ForEach(appState.profiles) { profile in
                            Text("\(profile.name) — \(profile.email)").tag(Optional(profile.id))
                        }
                    }
                }
            }

            Section("Git") {
                LabeledContent("Identity outside repositories") {
                    Text(appState.status?.globalIdentity.email ?? "Not set")
                        .textSelection(.enabled)
                }
                if case .defaultOverridden = appState.health {
                    overrideWarning
                }
                LabeledContent("Version", value: appState.status?.gitVersion ?? "—")
                LabeledContent("Executable", value: appState.dependencies.gitExecutable.path(percentEncoded: false))
            }

            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LaunchAtLogin.setEnabled(enabled)
                        } catch {
                            ErrorPresenter.present(error)
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
            }

            Section("Files") {
                fileRow("Global configuration", appState.paths.globalGitConfig)
                fileRow("Generated configuration", appState.paths.managedDirectory)
                fileRow("Backups", appState.paths.backupsDirectory)
            }
        }
        .formStyle(.grouped)
        .alert("Let SwitchMyGit manage your Git identity?", isPresented: $isConfirmingActivation) {
            Button("Cancel", role: .cancel) {}
            Button("Turn On") { Task { await appState.activate() } }
        } message: {
            Text("SwitchMyGit backs up ~/.gitconfig, writes its files to ~/.config/switchmygit and adds one marked include at the end of ~/.gitconfig. Your other settings aren’t changed.")
        }
        .confirmationDialog("Turn off SwitchMyGit?", isPresented: $isConfirmingDeactivation) {
            if let profile = appState.defaultProfile {
                Button("Turn Off and Keep “\(profile.name)”") {
                    Task { await appState.deactivate(keepingDefaultIdentity: true) }
                }
            }
            Button("Turn Off and Remove Identity", role: .destructive) {
                Task { await appState.deactivate(keepingDefaultIdentity: false) }
            }
        } message: {
            Text("Rules stop applying and the generated files are removed. Your profiles and rules are kept. A backup of ~/.gitconfig is made first.")
        }
    }

    // MARK: Rows

    private var overrideWarning: some View {
        LabeledContent {
            if !(appState.status?.unmanagedIdentity.isEmpty ?? true) {
                Button("Remove Override") {
                    Task { await appState.removeUnmanagedIdentity() }
                }
            }
        } label: {
            Label {
                Text("A [user] entry in ~/.gitconfig overrides your default profile")
                Text("This usually happens after running git config --global user.email. A backup is made before removing it.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
        }
    }

    private func fileRow(_ title: LocalizedStringKey, _ url: URL) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                Text(appState.paths.abbreviate(url))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("Show in Finder", systemImage: "arrow.forward.circle.fill") {
                    Panels.revealInFinder(url)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .disabled(!FileManager.default.fileExists(atPath: url.path))
            }
        }
    }

    // MARK: Bindings

    private var managementBinding: Binding<Bool> {
        Binding(
            get: { appState.isActive },
            set: { isOn in
                if isOn {
                    if appState.profiles.isEmpty {
                        ErrorPresenter.present(
                            message: String(localized: "Add a Profile First"),
                            information: String(localized: "SwitchMyGit needs at least one profile to use as your default identity.")
                        )
                        appState.settingsTab = .profiles
                    } else {
                        isConfirmingActivation = true
                    }
                } else {
                    isConfirmingDeactivation = true
                }
            }
        )
    }

    private var defaultProfileBinding: Binding<UUID?> {
        Binding(
            get: { appState.configuration.defaultProfileID },
            set: { id in
                guard let profile = id.flatMap(appState.profile(for:)) else { return }
                Task { await appState.setDefault(profile) }
            }
        )
    }
}
