import Foundation

/// Everything the user has configured. Persisted as JSON and compiled into
/// Git configuration files by ``ManagedConfigRenderer``.
public struct SwitcherConfiguration: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var profiles: [GitProfile]
    public var rules: [RepositoryRule]
    /// The profile used for repositories that no rule matches.
    public var defaultProfileID: UUID?

    public init(
        profiles: [GitProfile] = [],
        rules: [RepositoryRule] = [],
        defaultProfileID: UUID? = nil
    ) {
        self.version = Self.currentVersion
        self.profiles = profiles
        self.rules = rules
        self.defaultProfileID = defaultProfileID
    }

    public var defaultProfile: GitProfile? {
        defaultProfileID.flatMap(profile(withID:))
    }

    public func profile(withID id: UUID) -> GitProfile? {
        profiles.first { $0.id == id }
    }

    public func rules(for profile: GitProfile) -> [RepositoryRule] {
        rules.filter { $0.profileID == profile.id }
    }

    /// Enabled rules whose profile still exists.
    public var activeRules: [RepositoryRule] {
        rules.filter { $0.isEnabled && profile(withID: $0.profileID) != nil }
    }

    /// Removes a profile together with the rules that reference it.
    public mutating func removeProfile(withID id: UUID) {
        profiles.removeAll { $0.id == id }
        rules.removeAll { $0.profileID == id }
        if defaultProfileID == id {
            defaultProfileID = profiles.first?.id
        }
    }

    /// Inserts or replaces a profile, keeping its position when it exists.
    public mutating func upsert(_ profile: GitProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        if defaultProfileID == nil {
            defaultProfileID = profile.id
        }
    }

    /// Inserts or replaces a rule, keeping its position when it exists.
    public mutating func upsert(_ rule: RepositoryRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
    }
}
