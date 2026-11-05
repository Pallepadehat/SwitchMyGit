import Foundation

/// A private key found in `~/.ssh`. Only metadata from the *public* key is read.
public struct SSHKey: Identifiable, Hashable, Sendable {
    public var id: String { path }
    /// `~`-abbreviated path to the private key.
    public var path: String
    public var name: String
    /// e.g. `ssh-ed25519`.
    public var algorithm: String?
    /// The public key comment, usually an e-mail address.
    public var comment: String?
}

public enum SSHKeyIssue: Equatable, Sendable {
    case missing
    case isPublicKey
    case insecurePermissions(mode: Int)

    public var message: String {
        switch self {
        case .missing: "No file exists at this path."
        case .isPublicKey: "This is a public key. Choose the private key (without .pub)."
        case let .insecurePermissions(mode):
            "Permissions are \(String(mode, radix: 8)); SSH requires 600. Run `chmod 600` on the key."
        }
    }
}

/// Discovers and validates SSH keys. Never reads private key contents.
public struct SSHKeyService: Sendable {
    public let paths: SwitcherPaths

    public init(paths: SwitcherPaths) {
        self.paths = paths
    }

    private var sshDirectory: URL { paths.home.appending(path: ".ssh", directoryHint: .isDirectory) }

    /// Private keys that have a matching `.pub` file next to them.
    public func discoverKeys() -> [SSHKey] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: sshDirectory.path)) ?? []
        let formatter = PathFormatter(home: paths.home)

        return names
            .filter { $0.hasSuffix(".pub") }
            .map { String($0.dropLast(".pub".count)) }
            .filter { names.contains($0) }
            .sorted()
            .map { name in
                let fields = (try? String(contentsOf: sshDirectory.appending(path: name + ".pub"), encoding: .utf8))?
                    .split(separator: " ", maxSplits: 2)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
                return SSHKey(
                    path: formatter.abbreviate(sshDirectory.appending(path: name).path(percentEncoded: false)),
                    name: name,
                    algorithm: fields.first,
                    comment: fields.count > 2 ? fields[2] : nil
                )
            }
    }

    public func validate(_ path: String) -> [SSHKeyIssue] {
        let absolute = PathFormatter(home: paths.home).expand(path)
        if absolute.hasSuffix(".pub") { return [.isPublicKey] }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: absolute) else {
            return [.missing]
        }
        if let mode = attributes[.posixPermissions] as? Int, mode & 0o077 != 0 {
            return [.insecurePermissions(mode: mode)]
        }
        return []
    }
}
