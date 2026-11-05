import Foundation

/// Every file location SwitchMyGit reads or writes, derived from a home
/// directory. Tests pass a temporary home so the real `~/.gitconfig` is never touched.
public struct SwitcherPaths: Sendable, Equatable {
    public let home: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home.standardizedFileURL
    }

    /// The user's global Git configuration file.
    public var globalGitConfig: URL {
        home.appending(path: ".gitconfig")
    }

    /// Directory holding the Git configuration files that SwitchMyGit owns.
    public var managedDirectory: URL {
        home.appending(path: ".config/switchmygit", directoryHint: .isDirectory)
    }

    /// The single file `~/.gitconfig` includes. It includes everything else.
    public var managedEntryFile: URL {
        managedDirectory.appending(path: "switchmygit.gitconfig")
    }

    /// Identity used when no rule matches.
    public var defaultIdentityFile: URL {
        managedDirectory.appending(path: "default.gitconfig")
    }

    public var profilesDirectory: URL {
        managedDirectory.appending(path: "profiles", directoryHint: .isDirectory)
    }

    public func profileFile(for profileID: UUID) -> URL {
        profilesDirectory.appending(path: "\(profileID.uuidString.lowercased()).gitconfig")
    }

    public var backupsDirectory: URL {
        managedDirectory.appending(path: "backups", directoryHint: .isDirectory)
    }

    /// The app's own settings (profiles and rules).
    public var configurationFile: URL {
        home.appending(path: "Library/Application Support/SwitchMyGit/configuration.json")
    }

    /// Formats a path for display and for Git, using `~` for the home directory.
    public func abbreviate(_ url: URL) -> String {
        PathFormatter(home: home).abbreviate(url.path(percentEncoded: false))
    }
}

/// Converts between absolute paths and `~`-relative paths.
public struct PathFormatter: Sendable {
    public let home: URL

    public init(home: URL) {
        self.home = home.standardizedFileURL
    }

    private var homePath: String {
        let path = home.path(percentEncoded: false)
        return path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    /// `/Users/me/Code` → `~/Code`
    public func abbreviate(_ path: String) -> String {
        if path == homePath { return "~" }
        if path.hasPrefix(homePath + "/") {
            return "~" + path.dropFirst(homePath.count)
        }
        return path
    }

    /// `~/Code` → `/Users/me/Code`
    public func expand(_ path: String) -> String {
        if path == "~" { return homePath }
        if path.hasPrefix("~/") {
            return homePath + path.dropFirst()
        }
        return path
    }
}
