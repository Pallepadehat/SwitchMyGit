import SwiftUI
import SwitchMyGitCore

/// A list of profiles on the left and the selected profile's details on the right.
struct ProfilesSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: GitProfile.ID?
    @State private var isAdding = false
    @State private var pendingDeletion: GitProfile?

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ListWithActionBar(canRemove: selection != nil, remove: confirmDeletion) {
                List(selection: $selection) {
                    ForEach(appState.profiles) { profile in
                        ProfileListRow(profile: profile, isDefault: profile.id == appState.configuration.defaultProfileID)
                            .tag(profile.id)
                    }
                }
                .listStyle(.inset)
            } addButton: {
                AddButton { isAdding = true }
            }
            .frame(width: 210)

            Group {
                if let profile = selection.flatMap(appState.profile(for:)) {
                    ProfileForm(profile: profile)
                        .id(profile.id)
                } else {
                    ContentUnavailableView {
                        Label("No Profile Selected", systemImage: "person.crop.circle")
                    } description: {
                        Text("A profile is the name and e-mail Git uses for your commits — for example Personal and Work.")
                    } actions: {
                        if appState.profiles.isEmpty {
                            Button("Add Profile…") { isAdding = true }
                            if let email = appState.status?.globalIdentity.email {
                                Button("Import \(email)") {
                                    Task { selection = await appState.importCurrentIdentity()?.id }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .onAppear { selection = selection ?? appState.profiles.first?.id }
        .sheet(isPresented: $isAdding) {
            ProfileForm(profile: nil) { added in
                selection = added?.id ?? selection
                isAdding = false
            }
            .frame(width: 440)
        }
        .confirmationDialog(
            "Delete “\(pendingDeletion?.name ?? "")”?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { profile in
            Button("Delete", role: .destructive) {
                Task {
                    await appState.delete(profile)
                    selection = appState.profiles.first?.id
                }
            }
        } message: { profile in
            let count = appState.configuration.rules(for: profile).count
            Text(count == 0 ? "This can’t be undone." : "Its \(count) rule(s) will be deleted too. This can’t be undone.")
        }
    }

    private func confirmDeletion() {
        pendingDeletion = selection.flatMap(appState.profile(for:))
    }
}

private struct ProfileListRow: View {
    let profile: GitProfile
    let isDefault: Bool

    var body: some View {
        HStack(spacing: 8) {
            Monogram(profile: profile, size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(profile.name)
                Text(isDefault ? "Default" : profile.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
