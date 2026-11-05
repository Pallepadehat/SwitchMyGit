import Foundation
import SwitchMyGitCore

/// The services the app talks to, created in one place.
///
/// Swap in a different `home` to point the whole app at another directory,
/// which is handy for previews and manual testing.
struct AppDependencies {
    let paths: SwitcherPaths
    let store: ConfigurationStore
    let configService: ManagedConfigService
    let inspector: IdentityInspector
    let sshKeys: SSHKeyService
    let backups: BackupService
    let gitExecutable: URL

    static func live(home: URL = defaultHome) -> AppDependencies {
        let paths = SwitcherPaths(home: home)
        // `/usr/bin/git` always exists on macOS; it offers to install the
        // Command Line Tools when they're missing.
        let executable = GitClient.locateGit() ?? URL(filePath: "/usr/bin/git")
        let git = GitClient(executable: executable, home: home)

        return AppDependencies(
            paths: paths,
            store: ConfigurationStore(fileURL: paths.configurationFile),
            configService: ManagedConfigService(paths: paths, git: git),
            inspector: IdentityInspector(paths: paths, git: git),
            sshKeys: SSHKeyService(paths: paths),
            backups: BackupService(paths: paths),
            gitExecutable: executable
        )
    }

    /// The real home directory — or, in debug builds, the directory passed
    /// with `-SwitchMyGitHome /some/folder`, so you can try the app without
    /// touching your own `~/.gitconfig`.
    static var defaultHome: URL {
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "SwitchMyGitHome") {
            return URL(filePath: override, directoryHint: .isDirectory)
        }
        #endif
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
