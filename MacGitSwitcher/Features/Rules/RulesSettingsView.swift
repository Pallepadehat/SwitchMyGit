import SwiftUI
import SwitchMyGitCore

/// A table of rules in the order Git evaluates them.
struct RulesSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selection = Set<RepositoryRule.ID>()
    @State private var remoteDraft: RepositoryRule?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Repositories that match a rule use its profile instead of the default.")
                .foregroundStyle(.secondary)

            ListWithActionBar(canRemove: !selection.isEmpty, remove: removeSelected) {
                table
            } addButton: {
                addMenu
            }

            Text("When several rules match, the more specific one wins: nested folders beat their parents, and remote rules beat folder rules. A repository’s own .git/config always wins.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .sheet(item: $remoteDraft) { rule in
            RemoteRuleSheet(rule: rule)
        }
    }

    private var table: some View {
        Table(appState.orderedRules, selection: $selection) {
            TableColumn("On") { rule in
                Toggle("Enabled", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { isOn in Task { await appState.setEnabled(isOn, for: rule) } }
                ))
                .labelsHidden()
            }
            .width(28)

            TableColumn("Repositories") { rule in
                Label {
                    Text(rule.pattern)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } icon: {
                    Image(systemName: rule.kind == .directory ? "folder" : "network")
                        .foregroundStyle(.secondary)
                }
                .help(rule.kind == .directory ? "Repositories inside this folder" : "Repositories with a remote on \(rule.pattern)")
            }

            TableColumn("Profile") { rule in
                Picker("Profile", selection: profileBinding(for: rule)) {
                    ForEach(appState.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .labelsHidden()
            }
            .width(min: 120, ideal: 150, max: 200)
        }
        .contextMenu(forSelectionType: RepositoryRule.ID.self) { ids in
            if ids.count == 1, let rule = rule(ids.first) {
                Button(rule.kind == .directory ? "Change Folder…" : "Edit…") { edit(rule) }
            }
            Button("Delete", role: .destructive) { remove(ids) }
        } primaryAction: { ids in
            if let rule = rule(ids.first) { edit(rule) }
        }
        .overlay {
            if appState.configuration.rules.isEmpty {
                Text("No Rules")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var addMenu: some View {
        Menu {
            Button("Folder…") { addFolderRule() }
            Button("Remote…") { remoteDraft = newRule(kind: .remote, pattern: "") }
        } label: {
            Image(systemName: "plus")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(appState.profiles.isEmpty)
        .help(appState.profiles.isEmpty ? "Add a profile first" : "Add a rule")
    }

    // MARK: Actions

    private func addFolderRule() {
        guard let pattern = chooseFolder() else { return }
        save(newRule(kind: .directory, pattern: pattern))
    }

    private func edit(_ rule: RepositoryRule) {
        switch rule.kind {
        case .directory:
            guard let pattern = chooseFolder(startingAt: rule.pattern) else { return }
            var updated = rule
            updated.pattern = pattern
            save(updated)
        case .remote:
            remoteDraft = rule
        }
    }

    private func save(_ rule: RepositoryRule) {
        let errors = Validator.validate(rule, among: appState.configuration.rules, home: appState.paths.home)
            .filter { !$0.isWarning }
        if let error = errors.first {
            ErrorPresenter.present(message: String(localized: "Can’t Add Rule"), information: error.message)
            return
        }
        Task { await appState.save(rule) }
    }

    private func removeSelected() {
        remove(selection)
    }

    private func remove(_ ids: Set<RepositoryRule.ID>) {
        let rules = ids.compactMap(rule)
        selection.subtract(ids)
        Task {
            for rule in rules { await appState.delete(rule) }
        }
    }

    // MARK: Helpers

    private func newRule(kind: RepositoryRule.Kind, pattern: String) -> RepositoryRule {
        RepositoryRule(
            kind: kind,
            pattern: pattern,
            profileID: appState.configuration.defaultProfileID ?? appState.profiles.first?.id ?? UUID()
        )
    }

    private func chooseFolder(startingAt pattern: String? = nil) -> String? {
        let home = appState.paths.home
        let start = pattern.map { URL(filePath: PathFormatter(home: home).expand($0)) } ?? home
        guard let url = Panels.chooseFolder(
            prompt: String(localized: "Choose"),
            message: String(localized: "Repositories inside this folder will use the rule’s profile."),
            startingAt: start
        ) else { return nil }
        return RulePattern.normalizedDirectory(url.path(percentEncoded: false), home: home)
    }

    private func rule(_ id: RepositoryRule.ID?) -> RepositoryRule? {
        appState.configuration.rules.first { $0.id == id }
    }

    private func profileBinding(for rule: RepositoryRule) -> Binding<UUID> {
        Binding(
            get: { rule.profileID },
            set: { profileID in
                var updated = rule
                updated.profileID = profileID
                Task { await appState.save(updated) }
            }
        )
    }
}
