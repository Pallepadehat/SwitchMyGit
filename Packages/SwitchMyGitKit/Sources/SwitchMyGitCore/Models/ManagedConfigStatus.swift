import Foundation

/// A snapshot of how the user's global Git configuration relates to SwitchMyGit.
public struct ManagedConfigStatus: Equatable, Sendable {
    /// Whether the managed include block is present in `~/.gitconfig`.
    public var isInstalled: Bool
    /// The identity Git uses outside of any repository.
    public var globalIdentity: GitIdentity
    /// Where the global `user.email` comes from.
    public var globalEmailOrigin: ResolvedConfigValue?
    /// `user.*` values written directly in `~/.gitconfig` (outside the managed
    /// block). When they appear after the block they override the default profile.
    public var unmanagedIdentity: GitIdentity
    /// Conditional includes the user maintains themselves.
    public var foreignConditionalIncludes: [String]
    /// The installed Git version, e.g. "2.47.1".
    public var gitVersion: String?

    public init(
        isInstalled: Bool = false,
        globalIdentity: GitIdentity = GitIdentity(name: nil, email: nil),
        globalEmailOrigin: ResolvedConfigValue? = nil,
        unmanagedIdentity: GitIdentity = GitIdentity(name: nil, email: nil),
        foreignConditionalIncludes: [String] = [],
        gitVersion: String? = nil
    ) {
        self.isInstalled = isInstalled
        self.globalIdentity = globalIdentity
        self.globalEmailOrigin = globalEmailOrigin
        self.unmanagedIdentity = unmanagedIdentity
        self.foreignConditionalIncludes = foreignConditionalIncludes
        self.gitVersion = gitVersion
    }
}
