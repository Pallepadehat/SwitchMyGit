import Foundation

/// A problem that prevents saving a profile or rule.
public enum ValidationIssue: Equatable, Sendable {
    case emptyProfileName
    case duplicateProfileName
    case emptyUserName
    case invalidEmail
    case unsupportedCharacters
    case emptyPattern
    case duplicateRule
    case directoryMissing

    public var message: String {
        switch self {
        case .emptyProfileName: "Give the profile a name."
        case .duplicateProfileName: "Another profile already uses this name."
        case .emptyUserName: "Enter the name Git should use for commits."
        case .invalidEmail: "Enter a valid e-mail address."
        case .unsupportedCharacters: "Line breaks, tabs and quotes aren't supported here."
        case .emptyPattern: "Choose a folder or enter a remote."
        case .duplicateRule: "A rule for this location already exists."
        case .directoryMissing: "This folder doesn't exist yet. The rule will apply once it does."
        }
    }

    /// Warnings don't block saving.
    public var isWarning: Bool { self == .directoryMissing }
}

public enum Validator {
    public static func validate(_ profile: GitProfile, among profiles: [GitProfile]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let name = profile.name.trimmingCharacters(in: .whitespaces)

        if name.isEmpty { issues.append(.emptyProfileName) }
        if profiles.contains(where: { $0.id != profile.id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            issues.append(.duplicateProfileName)
        }
        if profile.userName.trimmingCharacters(in: .whitespaces).isEmpty { issues.append(.emptyUserName) }
        if !isPlausibleEmail(profile.email) { issues.append(.invalidEmail) }
        if [profile.name, profile.userName, profile.email, profile.sshKeyPath ?? ""]
            .contains(where: GitConfigSyntax.containsControlCharacters) {
            issues.append(.unsupportedCharacters)
        }
        return issues
    }

    public static func validate(_ rule: RepositoryRule, among rules: [RepositoryRule], home: URL) -> [ValidationIssue] {
        let pattern = rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { return [.emptyPattern] }

        var issues: [ValidationIssue] = []
        if GitConfigSyntax.containsControlCharacters(pattern) || pattern.contains("\"") {
            issues.append(.unsupportedCharacters)
        }

        let key = normalizedKey(rule, home: home)
        if rules.contains(where: { $0.id != rule.id && $0.kind == rule.kind && normalizedKey($0, home: home) == key }) {
            issues.append(.duplicateRule)
        }

        if rule.kind == .directory {
            let path = PathFormatter(home: home).expand(pattern)
            if !FileManager.default.fileExists(atPath: path) { issues.append(.directoryMissing) }
        }
        return issues
    }

    private static func normalizedKey(_ rule: RepositoryRule, home: URL) -> String {
        switch rule.kind {
        case .directory: RulePattern.normalizedDirectory(rule.pattern, home: home).lowercased()
        case .remote: RulePattern.remoteURLGlobs(for: rule.pattern).joined().lowercased()
        }
    }

    /// Deliberately permissive: `something@something.tld`, no spaces.
    static func isPlausibleEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !email.contains(where: \.isWhitespace) else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }
}
