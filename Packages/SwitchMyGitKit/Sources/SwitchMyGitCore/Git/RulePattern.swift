import Foundation

/// Normalises what users type into patterns Git understands.
public enum RulePattern {
    /// `/Users/me/Code/work` → `~/Code/work/`
    ///
    /// A trailing slash makes Git match every repository *inside* the directory.
    public static func normalizedDirectory(_ pattern: String, home: URL) -> String {
        var path = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = PathFormatter(home: home)
        path = formatter.abbreviate(formatter.expand(path))
        if !path.hasSuffix("/") { path += "/" }
        return path
    }

    /// Turns a remote prefix into URL globs for `hasconfig:remote.*.url:`.
    ///
    /// `github.com/acme` matches HTTPS, SSH and scp-style remotes:
    /// `https://github.com/acme/**`, `ssh://git@github.com/acme/**`, `git@github.com:acme/**`.
    /// Patterns that already contain a scheme or `@` are used as-is.
    public static func remoteURLGlobs(for pattern: String) -> [String] {
        var prefix = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if prefix.contains("://") || prefix.contains("@") {
            return [prefix]
        }
        while prefix.hasSuffix("/") { prefix.removeLast() }

        let parts = prefix.split(separator: "/", maxSplits: 1).map(String.init)
        guard let host = parts.first else { return [] }
        let path = parts.count > 1 ? parts[1] + "/" : ""

        return [
            "https://\(host)/\(path)**",
            "ssh://git@\(host)/\(path)**",
            "git@\(host):\(path)**",
        ]
    }
}
