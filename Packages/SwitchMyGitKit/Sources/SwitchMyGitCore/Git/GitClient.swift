import Foundation

public enum GitError: LocalizedError, Equatable {
    case gitNotFound
    case commandFailed(command: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .gitNotFound:
            "Git could not be found. Install the Xcode Command Line Tools with `xcode-select --install`."
        case let .commandFailed(command, message):
            "`git \(command)` failed: \(message)"
        }
    }
}

/// A thin, typed wrapper around the `git` executable.
public struct GitClient: Sendable {
    public let executable: URL
    public let home: URL
    private let runner: ProcessRunning
    private let environment: [String: String]

    /// - Parameters:
    ///   - executable: The `git` binary. Use ``GitClient/locateGit()`` to find it.
    ///   - home: Used as `HOME`, so `~/.gitconfig` resolves inside it.
    ///   - isolated: Ignores system-wide Git configuration. Used by tests.
    public init(
        executable: URL,
        home: URL,
        runner: ProcessRunning = ProcessRunner(),
        isolated: Bool = false
    ) {
        self.executable = executable
        self.home = home
        self.runner = runner

        var environment = ProcessInfo.processInfo.environment
        // Variables that would redirect Git away from the configuration we manage.
        for key in ["GIT_DIR", "GIT_WORK_TREE", "GIT_CONFIG", "GIT_CONFIG_GLOBAL", "GIT_CONFIG_SYSTEM",
                    "GIT_CONFIG_COUNT", "GIT_CONFIG_PARAMETERS", "XDG_CONFIG_HOME"] {
            environment[key] = nil
        }
        var homePath = home.path(percentEncoded: false)
        if homePath.count > 1, homePath.hasSuffix("/") { homePath.removeLast() }
        environment["HOME"] = homePath
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["LC_ALL"] = "C"
        if isolated {
            environment["GIT_CONFIG_NOSYSTEM"] = "1"
        }
        self.environment = environment
    }

    /// Finds the first usable Git, preferring Homebrew installs over the system shim.
    public static func locateGit(fileManager: FileManager = .default) -> URL? {
        let candidates = ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git"]
        return candidates
            .first { fileManager.isExecutableFile(atPath: $0) }
            .map { URL(filePath: $0) }
    }

    /// Runs `git` with the given arguments and returns the raw output.
    @discardableResult
    public func run(_ arguments: [String], in directory: URL? = nil) async throws -> ProcessOutput {
        try await runner.run(
            executable,
            arguments: arguments,
            environment: environment,
            currentDirectory: directory ?? FileManager.default.temporaryDirectory
        )
    }

    /// Runs `git` and throws when it exits with a non-zero status.
    @discardableResult
    public func checkedRun(_ arguments: [String], in directory: URL? = nil) async throws -> String {
        let output = try await run(arguments, in: directory)
        guard output.succeeded else {
            throw GitError.commandFailed(
                command: arguments.joined(separator: " "),
                message: output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return output.standardOutput
    }

    // MARK: - Queries

    public func version() async throws -> String {
        let output = try await checkedRun(["--version"])
        // "git version 2.47.1 (Apple Git-154)" → "2.47.1"
        let words = output.split(separator: " ")
        return words.count >= 3 ? String(words[2]) : output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolves a key the way Git would for commits made in `directory`
    /// (or outside any repository when `directory` is `nil`).
    ///
    /// - Parameter globalOnly: Only consult the global configuration (and the files it includes).
    public func resolve(_ key: String, in directory: URL? = nil, globalOnly: Bool = false) async throws -> ResolvedConfigValue? {
        var arguments = ["config", "--includes", "--show-scope", "--show-origin", "-z"]
        if globalOnly { arguments.append("--global") }
        arguments += ["--get", key]

        let output = try await run(arguments, in: directory)
        // Exit code 1 means "key not set".
        guard output.succeeded else { return nil }
        return Self.parseResolvedValue(output.standardOutput)
    }

    /// Reads a key from a single file, ignoring includes.
    public func value(of key: String, inFile file: URL) async throws -> String? {
        let output = try await run(["config", "--file", file.path(percentEncoded: false), "--no-includes", "--get", key])
        guard output.succeeded else { return nil }
        return output.standardOutput.trimmingCharacters(in: .newlines)
    }

    /// Lists `includeIf.<condition>.path` entries in a single file.
    public func conditionalIncludes(inFile file: URL) async throws -> [String] {
        let output = try await run([
            "config", "--file", file.path(percentEncoded: false), "--no-includes",
            "--name-only", "--get-regexp", "^includeif\\.",
        ])
        guard output.succeeded else { return [] }
        return output.standardOutput
            .split(separator: "\n")
            .map { name in
                // "includeif.gitdir:~/code/.path" → "gitdir:~/code/"
                var condition = name.dropFirst("includeif.".count)
                if condition.hasSuffix(".path") { condition = condition.dropLast(".path".count) }
                return String(condition)
            }
    }

    /// Removes every value of `key` from a single file.
    public func unsetAll(_ key: String, inFile file: URL) async throws {
        let output = try await run(["config", "--file", file.path(percentEncoded: false), "--unset-all", key])
        // Exit code 5 means "nothing to unset", which is fine.
        guard output.succeeded || output.exitCode == 5 else {
            throw GitError.commandFailed(command: "config --unset-all \(key)", message: output.standardError)
        }
    }

    /// Returns the working tree root of the repository containing `directory`.
    public func repositoryRoot(of directory: URL) async throws -> URL? {
        let output = try await run(["rev-parse", "--show-toplevel"], in: directory)
        guard output.succeeded else { return nil }
        let path = output.standardOutput.trimmingCharacters(in: .newlines)
        return path.isEmpty ? nil : URL(filePath: path, directoryHint: .isDirectory)
    }

    /// Parses `scope NUL file:origin NUL value NUL`, as printed by `git config -z --show-scope --show-origin`.
    static func parseResolvedValue(_ output: String) -> ResolvedConfigValue? {
        let fields = output.split(separator: "\0", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 3 else { return nil }
        let origin = fields[1]
        let file = origin.hasPrefix("file:") ? URL(filePath: String(origin.dropFirst("file:".count))) : nil
        return ResolvedConfigValue(scope: fields[0], originFile: file, value: fields[2])
    }
}
