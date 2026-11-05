import SwiftUI
import SwitchMyGitCore

/// Adds or edits a rule that matches repositories by their remote.
struct RemoteRuleSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RepositoryRule
    @State private var showsErrors = false

    init(rule: RepositoryRule) {
        _draft = State(initialValue: rule)
    }

    private var isNew: Bool { !appState.configuration.rules.contains { $0.id == draft.id } }
    private var errors: [ValidationIssue] {
        Validator.validate(draft, among: appState.configuration.rules, home: appState.paths.home)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Remote", text: $draft.pattern, prompt: Text("github.com/acme"))
                    Picker("Profile", selection: $draft.profileID) {
                        ForEach(appState.profiles) { Text($0.name).tag($0.id) }
                    }
                } footer: {
                    Text("Matches HTTPS and SSH remotes on this host and organization. Requires Git 2.36 or later.")
                }

                if showsErrors, !errors.isEmpty {
                    Section {
                        ForEach(errors, id: \.message) { Text($0.message).foregroundStyle(.red) }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add Rule" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 420)
    }

    private func save() {
        draft.pattern = draft.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard errors.isEmpty else {
            showsErrors = true
            return
        }
        Task {
            await appState.save(draft)
            dismiss()
        }
    }
}
