import Foundation

/// Copies `~/.gitconfig` aside before SwitchMyGit changes it.
public struct BackupService: Sendable {
    public let paths: SwitcherPaths
    /// How many backups to keep. Older ones are deleted.
    public let retainedBackups: Int

    public init(paths: SwitcherPaths, retainedBackups: Int = 10) {
        self.paths = paths
        self.retainedBackups = retainedBackups
    }

    /// Backs up the global config and returns the backup location,
    /// or `nil` when there is no global config yet.
    @discardableResult
    public func backUpGlobalConfig(now: Date = .now) throws -> URL? {
        let source = paths.globalGitConfig.resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: source.path) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"

        let destination = paths.backupsDirectory.appending(path: "gitconfig-\(formatter.string(from: now))")
        try FileManager.default.createDirectory(at: paths.backupsDirectory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: destination)
        try pruneOldBackups()
        return destination
    }

    /// All backups, newest first.
    public func backups() -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: paths.backupsDirectory, includingPropertiesForKeys: nil
        )) ?? []
        return contents
            .filter { $0.lastPathComponent.hasPrefix("gitconfig-") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private func pruneOldBackups() throws {
        for url in backups().dropFirst(retainedBackups) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
