import Foundation

/// A `user.name` / `user.email` pair as Git resolves it.
public struct GitIdentity: Equatable, Hashable, Sendable {
    public var name: String?
    public var email: String?

    public init(name: String?, email: String?) {
        self.name = name
        self.email = email
    }

    public var isEmpty: Bool { name == nil && email == nil }

    public func matches(_ profile: GitProfile) -> Bool {
        name == profile.userName && email == profile.email
    }
}

/// A single configuration value together with where Git found it.
public struct ResolvedConfigValue: Equatable, Sendable {
    /// Git's scope label: `system`, `global`, `local`, `worktree` or `command`.
    public var scope: String
    /// The file the value came from, when it came from a file.
    public var originFile: URL?
    public var value: String

    public init(scope: String, originFile: URL?, value: String) {
        self.scope = scope
        self.originFile = originFile
        self.value = value
    }
}

/// Explains *why* a repository ends up with a given identity.
public enum IdentitySource: Equatable, Sendable {
    /// The repository's own `.git/config` sets the identity.
    case repositoryOverride
    /// A SwitchMyGit rule assigned this profile.
    case rule(profileID: UUID)
    /// No rule matched; the SwitchMyGit default profile applies.
    case defaultProfile(profileID: UUID)
    /// The identity comes from Git configuration SwitchMyGit does not manage.
    case unmanaged(scope: String, file: URL?)
    /// Git has no identity for this repository; commits will fail.
    case missing
}

/// The result of inspecting a directory with ``IdentityInspector``.
public struct RepositoryInspection: Equatable, Sendable {
    public var directory: URL
    /// The working tree root, or `nil` when the directory is not inside a repository.
    public var repositoryRoot: URL?
    public var identity: GitIdentity
    /// Explains where the e-mail (the value that matters most for attribution) came from.
    public var source: IdentitySource
    public var emailOrigin: ResolvedConfigValue?
    public var nameOrigin: ResolvedConfigValue?

    public var isRepository: Bool { repositoryRoot != nil }

    public init(
        directory: URL,
        repositoryRoot: URL?,
        identity: GitIdentity,
        source: IdentitySource,
        emailOrigin: ResolvedConfigValue? = nil,
        nameOrigin: ResolvedConfigValue? = nil
    ) {
        self.directory = directory
        self.repositoryRoot = repositoryRoot
        self.identity = identity
        self.source = source
        self.emailOrigin = emailOrigin
        self.nameOrigin = nameOrigin
    }
}
