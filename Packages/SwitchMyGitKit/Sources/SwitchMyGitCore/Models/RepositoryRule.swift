import Foundation

/// Assigns a profile to every repository that matches a condition.
///
/// Rules are compiled into Git `includeIf` sections, so they keep working
/// even when SwitchMyGit is not running.
public struct RepositoryRule: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// Matches repositories located inside a directory, e.g. `~/Code/work/`.
        case directory
        /// Matches repositories with a remote on a host/organisation,
        /// e.g. `github.com/acme`.
        case remote
    }

    public var id: UUID
    public var kind: Kind
    /// A directory path (`~/Code/work/`) or a remote prefix (`github.com/acme`).
    public var pattern: String
    public var profileID: UUID
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        kind: Kind = .directory,
        pattern: String,
        profileID: UUID,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.pattern = pattern
        self.profileID = profileID
        self.isEnabled = isEnabled
    }
}
