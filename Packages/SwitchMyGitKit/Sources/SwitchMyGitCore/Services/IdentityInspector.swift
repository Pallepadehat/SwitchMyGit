import Foundation

/// Answers "which identity will my next commit in this folder use, and why?"
public struct IdentityInspector: Sendable {
    public let paths: SwitcherPaths
    private let git: GitClient

    public init(paths: SwitcherPaths, git: GitClient) {
        self.paths = paths
        self.git = git
    }

    public func inspect(_ directory: URL, configuration: SwitcherConfiguration) async throws -> RepositoryInspection {
        async let root = git.repositoryRoot(of: directory)
        async let email = git.resolve("user.email", in: directory)
        async let name = git.resolve("user.name", in: directory)

        let (resolvedEmail, resolvedName) = try await (email, name)
        return try await RepositoryInspection(
            directory: directory,
            repositoryRoot: root,
            identity: GitIdentity(name: resolvedName?.value, email: resolvedEmail?.value),
            source: source(of: resolvedEmail ?? resolvedName, configuration: configuration),
            emailOrigin: resolvedEmail,
            nameOrigin: resolvedName
        )
    }

    /// Classifies where a value came from.
    func source(of value: ResolvedConfigValue?, configuration: SwitcherConfiguration) -> IdentitySource {
        guard let value else { return .missing }

        if value.scope == "local" || value.scope == "worktree" {
            return .repositoryOverride
        }
        guard let file = value.originFile.map(Self.canonical) else {
            return .unmanaged(scope: value.scope, file: nil)
        }

        if file == Self.canonical(paths.defaultIdentityFile), let id = configuration.defaultProfileID {
            return .defaultProfile(profileID: id)
        }
        if file.deletingLastPathComponent() == Self.canonical(paths.profilesDirectory),
           let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent) {
            return .rule(profileID: id)
        }
        return .unmanaged(scope: value.scope, file: value.originFile)
    }

    private static func canonical(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }
}
