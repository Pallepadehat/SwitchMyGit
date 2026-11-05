import Foundation

/// Applies a ``SwitcherConfiguration`` to the user's Git configuration — safely.
///
/// SwitchMyGit owns a handful of files in `~/.config/switchmygit/` and a
/// single, clearly marked include block at the end of `~/.gitconfig`.
/// Every mutation follows the same recipe:
///
/// 1. back up what will change,
/// 2. write files atomically,
/// 3. ask Git itself to read the result back,
/// 4. restore the previous state if anything went wrong.
public struct ManagedConfigService: Sendable {
    public let paths: SwitcherPaths
    private let git: GitClient
    private let renderer: ManagedConfigRenderer
    private let backups: BackupService

    public init(paths: SwitcherPaths, git: GitClient) {
        self.paths = paths
        self.git = git
        self.renderer = ManagedConfigRenderer(paths: paths)
        self.backups = BackupService(paths: paths)
    }

    public enum ServiceError: LocalizedError, Equatable {
        case invalidGeneratedConfig(String)
        case verificationFailed(expected: String, actual: String?)

        public var errorDescription: String? {
            switch self {
            case let .invalidGeneratedConfig(message):
                "Git rejected the generated configuration, so your previous settings were restored. \(message)"
            case let .verificationFailed(expected, actual):
                "Git reports \(actual.map { "“\($0)”" } ?? "no e-mail") instead of “\(expected)”. Your previous settings were restored."
            }
        }
    }

    // MARK: - Status

    public func status() async throws -> ManagedConfigStatus {
        let globalText = try FileSystem.readIfExists(paths.globalGitConfig) ?? ""
        let hasGlobalFile = FileManager.default.fileExists(atPath: paths.globalGitConfig.path)

        async let email = git.resolve("user.email", globalOnly: true)
        async let name = git.resolve("user.name", globalOnly: true)
        async let unmanagedName = hasGlobalFile ? git.value(of: "user.name", inFile: paths.globalGitConfig) : nil
        async let unmanagedEmail = hasGlobalFile ? git.value(of: "user.email", inFile: paths.globalGitConfig) : nil
        async let includes = hasGlobalFile ? git.conditionalIncludes(inFile: paths.globalGitConfig) : []
        async let version = try? git.version()

        let resolvedEmail = try await email
        return try await ManagedConfigStatus(
            isInstalled: GlobalConfigBlock.isInstalled(in: globalText),
            globalIdentity: GitIdentity(name: name?.value, email: resolvedEmail?.value),
            globalEmailOrigin: resolvedEmail,
            unmanagedIdentity: GitIdentity(name: unmanagedName, email: unmanagedEmail),
            foreignConditionalIncludes: includes,
            gitVersion: version
        )
    }

    // MARK: - Mutations

    /// Writes the managed files, adds the include block to `~/.gitconfig`
    /// and verifies the result. Safe to call repeatedly.
    public func install(_ configuration: SwitcherConfiguration) async throws {
        try backups.backUpGlobalConfig()
        let previousGlobalText = try FileSystem.readIfExists(paths.globalGitConfig)

        try await apply(configuration)

        let includePath = paths.abbreviate(paths.managedEntryFile)
        let updated = GlobalConfigBlock.installing(includePath: includePath, in: previousGlobalText ?? "")
        try FileSystem.writeAtomically(updated, to: paths.globalGitConfig)

        do {
            try await verify(configuration)
        } catch {
            try restoreGlobalConfig(previousGlobalText)
            throw error
        }
    }

    /// Regenerates the managed files. Use after editing profiles or rules,
    /// or to switch the default profile. Rolls back if Git can't read the result.
    public func apply(_ configuration: SwitcherConfiguration) async throws {
        let snapshot = try ManagedFilesSnapshot.capture(paths: paths)
        do {
            try write(renderer.render(configuration))
            try await verify(configuration)
        } catch {
            try snapshot.restore()
            throw error
        }
    }

    /// Removes the include block and the managed files. When `keeping` is
    /// given, that identity is written into `~/.gitconfig` so Git keeps working.
    public func uninstall(keeping profile: GitProfile?) async throws {
        try backups.backUpGlobalConfig()

        if let text = try FileSystem.readIfExists(paths.globalGitConfig) {
            try FileSystem.writeAtomically(GlobalConfigBlock.removing(from: text), to: paths.globalGitConfig)
        }
        if let profile {
            let file = paths.globalGitConfig.path(percentEncoded: false)
            try await git.checkedRun(["config", "--file", file, "user.name", profile.userName])
            try await git.checkedRun(["config", "--file", file, "user.email", profile.email])
        }

        try FileSystem.removeIfExists(paths.managedEntryFile)
        try FileSystem.removeIfExists(paths.defaultIdentityFile)
        try FileSystem.removeIfExists(paths.profilesDirectory)
    }

    /// Removes `user.name` and `user.email` written directly in `~/.gitconfig`,
    /// so they stop overriding the default profile. A backup is made first.
    public func removeUnmanagedIdentity() async throws {
        try backups.backUpGlobalConfig()
        try await git.unsetAll("user.name", inFile: paths.globalGitConfig)
        try await git.unsetAll("user.email", inFile: paths.globalGitConfig)
    }

    // MARK: - Helpers

    private func write(_ files: ManagedConfigFiles) throws {
        try FileSystem.writeAtomically(files.defaultIdentity, to: paths.defaultIdentityFile)
        for (profileID, contents) in files.profiles {
            try FileSystem.writeAtomically(contents, to: paths.profileFile(for: profileID))
        }
        try removeStaleProfileFiles(keeping: Set(files.profiles.keys))
        // The entry file goes last: it is the only one Git reads directly,
        // so it never references a profile file that doesn't exist yet.
        try FileSystem.writeAtomically(files.entry, to: paths.managedEntryFile)
    }

    private func removeStaleProfileFiles(keeping profileIDs: Set<UUID>) throws {
        let expected = Set(profileIDs.map { paths.profileFile(for: $0).lastPathComponent })
        let existing = (try? FileManager.default.contentsOfDirectory(atPath: paths.profilesDirectory.path)) ?? []
        for name in existing where name.hasSuffix(".gitconfig") && !expected.contains(name) {
            try FileManager.default.removeItem(at: paths.profilesDirectory.appending(path: name))
        }
    }

    /// Asks Git to parse the configuration and checks the default identity.
    private func verify(_ configuration: SwitcherConfiguration) async throws {
        // Parsing the entry file with includes catches syntax errors in every managed file.
        let entry = paths.managedEntryFile.path(percentEncoded: false)
        let parse = try await git.run(["config", "--file", entry, "--includes", "--list"])
        guard parse.succeeded || parse.exitCode == 1 else {
            throw ServiceError.invalidGeneratedConfig(parse.standardError.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        guard let profile = configuration.defaultProfile else { return }
        let written = try await git.value(of: "user.email", inFile: paths.defaultIdentityFile)
        guard written == profile.email else {
            throw ServiceError.verificationFailed(expected: profile.email, actual: written)
        }
    }

    private func restoreGlobalConfig(_ text: String?) throws {
        if let text {
            try FileSystem.writeAtomically(text, to: paths.globalGitConfig)
        } else {
            try FileSystem.removeIfExists(paths.globalGitConfig)
        }
    }
}

/// The contents of the managed files at a point in time, for rollbacks.
private struct ManagedFilesSnapshot {
    let paths: SwitcherPaths
    let files: [URL: String]

    static func capture(paths: SwitcherPaths) throws -> ManagedFilesSnapshot {
        var files: [URL: String] = [:]
        for url in managedFiles(paths: paths) {
            files[url] = try FileSystem.readIfExists(url)
        }
        return ManagedFilesSnapshot(paths: paths, files: files)
    }

    func restore() throws {
        for url in Self.managedFiles(paths: paths) where files[url] == nil {
            try FileSystem.removeIfExists(url)
        }
        for (url, contents) in files {
            try FileSystem.writeAtomically(contents, to: url)
        }
    }

    private static func managedFiles(paths: SwitcherPaths) -> [URL] {
        let profiles = (try? FileManager.default.contentsOfDirectory(
            at: paths.profilesDirectory, includingPropertiesForKeys: nil
        )) ?? []
        return [paths.managedEntryFile, paths.defaultIdentityFile] + profiles
    }
}
