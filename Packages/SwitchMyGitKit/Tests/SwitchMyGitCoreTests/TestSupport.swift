import Foundation
@testable import SwitchMyGitCore

/// An isolated home directory so tests never touch the real `~/.gitconfig`.
final class TemporaryHome {
    let url: URL
    let paths: SwitcherPaths
    let git: GitClient

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appending(path: "SwitchMyGitTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // Resolve /var → /private/var so paths match what Git reports.
        url = URL(filePath: base.path.withCString { String(cString: realpath($0, nil)) }, directoryHint: .isDirectory)
        paths = SwitcherPaths(home: url)
        guard let executable = GitClient.locateGit() else { throw GitError.gitNotFound }
        git = GitClient(executable: executable, home: url, isolated: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    var service: ManagedConfigService { ManagedConfigService(paths: paths, git: git) }
    var inspector: IdentityInspector { IdentityInspector(paths: paths, git: git) }

    func write(_ text: String, to relativePath: String) throws {
        let file = url.appending(path: relativePath)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }

    func read(_ relativePath: String) throws -> String {
        try String(contentsOf: url.appending(path: relativePath), encoding: .utf8)
    }

    /// Creates a repository at `relativePath` and returns its URL.
    @discardableResult
    func makeRepository(_ relativePath: String) async throws -> URL {
        let repository = url.appending(path: relativePath, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        try await git.checkedRun(["init", "--quiet"], in: repository)
        return repository
    }

    /// The e-mail Git would use for a commit in `directory`.
    func effectiveEmail(in directory: URL) async throws -> String? {
        try await git.resolve("user.email", in: directory)?.value
    }

    /// Makes a real commit and returns its author e-mail.
    func commitAuthorEmail(in repository: URL) async throws -> String {
        try await git.checkedRun(["commit", "--allow-empty", "--quiet", "--no-gpg-sign", "-m", "test"], in: repository)
        return try await git.checkedRun(["log", "-1", "--format=%ae"], in: repository)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum Fixtures {
    static let personal = GitProfile(name: "Personal", userName: "Pat Personal", email: "me@personal.dev")
    static let work = GitProfile(name: "Work", userName: "Pat Work", email: "pat@company.com")
    static let client = GitProfile(name: "Client", userName: "Pat Consultant", email: "pat@client.io")

    static func configuration(rules: [RepositoryRule] = [], default profile: GitProfile = personal) -> SwitcherConfiguration {
        SwitcherConfiguration(profiles: [personal, work, client], rules: rules, defaultProfileID: profile.id)
    }
}
