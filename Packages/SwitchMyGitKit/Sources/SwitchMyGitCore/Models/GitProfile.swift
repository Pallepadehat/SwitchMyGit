import Foundation

/// A named Git identity, such as "Personal" or "Work".
///
/// Profiles are referenced by their stable `id`, so renaming a profile never
/// breaks the repository rules that point at it.
public struct GitProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// Display name shown in the app, e.g. "Work".
    public var name: String
    /// Value written to `user.name`.
    public var userName: String
    /// Value written to `user.email`.
    public var email: String
    /// Optional path to an existing private SSH key. SwitchMyGit never reads
    /// the key's contents; the path is only used to build `core.sshCommand`.
    public var sshKeyPath: String?

    public init(
        id: UUID = UUID(),
        name: String,
        userName: String,
        email: String,
        sshKeyPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.userName = userName
        self.email = email
        self.sshKeyPath = sshKeyPath
    }

    /// The SSH key path, or `nil` when the field is unset or blank.
    public var normalizedSSHKeyPath: String? {
        guard let path = sshKeyPath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return nil
        }
        return path
    }

    /// Initials used for avatars, e.g. "Work" → "W", "Open Source" → "OS".
    public var initials: String {
        let words = name.split(whereSeparator: { $0.isWhitespace }).prefix(2)
        let letters = words.compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }
}
