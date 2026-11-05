import SwitchMyGitCore

extension IdentitySource {
    /// A one-sentence explanation of why Git picked this identity.
    @MainActor
    func explanation(in appState: AppState) -> String {
        switch self {
        case let .rule(profileID):
            let name = appState.profile(for: profileID)?.name ?? "a profile"
            return "A rule assigns this location to the “\(name)” profile."
        case let .defaultProfile(profileID):
            let name = appState.profile(for: profileID)?.name ?? "default"
            return "No rule matches, so the default profile “\(name)” is used."
        case .repositoryOverride:
            return "The repository’s own .git/config sets this identity. It takes precedence over SwitchMyGit’s rules."
        case let .unmanaged(scope, file):
            let location = file.map { appState.paths.abbreviate($0) } ?? "the \(scope) configuration"
            return "This identity comes from \(location), which SwitchMyGit doesn’t manage."
        case .missing:
            return "Git has no user.email here, so commits will fail."
        }
    }
}
