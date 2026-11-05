import SwiftUI
import SwitchMyGitCore

/// Edits a profile. Used inline for existing profiles and in a sheet for new ones.
struct ProfileForm: View {
    @Environment(AppState.self) private var appState

    private let original: GitProfile?
    /// Set when shown in a sheet; called with the new profile, or `nil` on cancel.
    private let onFinish: ((GitProfile?) -> Void)?
    @State private var draft: GitProfile
    @State private var showsErrors = false

    init(profile: GitProfile?, onFinish: ((GitProfile?) -> Void)? = nil) {
        original = profile
        self.onFinish = onFinish
        _draft = State(initialValue: profile ?? GitProfile(name: "", userName: "", email: ""))
    }

    private var isNew: Bool { original == nil }
    private var hasChanges: Bool { draft != original }
    private var isDefault: Bool { draft.id == appState.configuration.defaultProfileID }
    private var errors: [ValidationIssue] { Validator.validate(cleaned, among: appState.profiles) }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Profile name", text: $draft.name, prompt: Text("Work"))
                } footer: {
                    if isNew {
                        Text("Add the identity you use for one kind of work.")
                    }
                }

                Section("Commits") {
                    TextField("Name", text: $draft.userName, prompt: Text("Required"))
                    TextField("E-mail", text: $draft.email, prompt: Text("Required"))
                        .textContentType(.emailAddress)
                }

                Section {
                    SSHKeyPicker(path: $draft.sshKeyPath)
                } header: {
                    Text("SSH")
                } footer: {
                    Text("Pushes from repositories that use this profile authenticate with this key. Only the path is stored. HTTPS remotes aren’t affected.")
                }

                if showsErrors, !errors.isEmpty {
                    Section {
                        ForEach(errors, id: \.message) { issue in
                            Text(issue.message).foregroundStyle(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            buttons
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    private var buttons: some View {
        HStack {
            if !isNew {
                Button("Make Default") {
                    Task { await appState.setDefault(draft) }
                }
                .disabled(isDefault || hasChanges || appState.isWorking)
            }
            Spacer()
            if isNew {
                Button("Cancel") { onFinish?(nil) }
                    .keyboardShortcut(.cancelAction)
                Button("Add Profile") { save() }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Revert") { draft = original ?? draft }
                    .disabled(!hasChanges)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!hasChanges || appState.isWorking)
            }
        }
    }

    /// The draft with surrounding whitespace removed.
    private var cleaned: GitProfile {
        var profile = draft
        profile.name = profile.name.trimmingCharacters(in: .whitespaces)
        profile.userName = profile.userName.trimmingCharacters(in: .whitespaces)
        profile.email = profile.email.trimmingCharacters(in: .whitespaces)
        profile.sshKeyPath = profile.normalizedSSHKeyPath
        return profile
    }

    private func save() {
        guard errors.isEmpty else {
            showsErrors = true
            return
        }
        let profile = cleaned
        Task {
            await appState.save(profile)
            draft = appState.profile(for: profile.id) ?? profile
            onFinish?(profile)
        }
    }
}

/// Picks one of the keys in ~/.ssh, or any other key file.
private struct SSHKeyPicker: View {
    @Environment(AppState.self) private var appState
    @Binding var path: String?
    @State private var keys: [SSHKey] = []

    private static let chooseTag = "\u{0}choose"

    var body: some View {
        let service = appState.dependencies.sshKeys

        Picker("Key", selection: selection) {
            Text("None").tag(String?.none)
            Divider()
            ForEach(keys) { key in
                Text(key.name).tag(Optional(key.path))
            }
            if let path, !keys.contains(where: { $0.path == path }) {
                Text(URL(filePath: path).lastPathComponent).tag(Optional(path))
            }
            Divider()
            Text("Other…").tag(Optional(Self.chooseTag))
        }
        .task { keys = service.discoverKeys() }

        if let path {
            ForEach(service.validate(path), id: \.message) { issue in
                Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.multicolor)
            }
        }
    }

    /// Intercepts "Other…" to show an open panel instead of selecting it.
    private var selection: Binding<String?> {
        Binding(
            get: { path },
            set: { newValue in
                if newValue == Self.chooseTag {
                    if let url = Panels.chooseSSHKey(home: appState.paths.home) {
                        path = appState.paths.abbreviate(url)
                    }
                } else {
                    path = newValue
                }
            }
        )
    }
}
