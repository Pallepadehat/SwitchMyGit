import Foundation

/// The captured result of a finished process.
public struct ProcessOutput: Sendable, Equatable {
    public var exitCode: Int32
    public var standardOutput: String
    public var standardError: String

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    public var succeeded: Bool { exitCode == 0 }
}

/// Runs executables. Abstracted so services can be tested with fakes.
public protocol ProcessRunning: Sendable {
    func run(
        _ executable: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?
    ) async throws -> ProcessOutput
}

/// Runs a process directly via `posix_spawn` — never through a shell — so
/// names, e-mails and paths can't be interpreted as shell syntax.
public struct ProcessRunner: ProcessRunning {
    public init() {}

    public func run(
        _ executable: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?
    ) async throws -> ProcessOutput {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result {
                    try Self.runBlocking(executable, arguments, environment, currentDirectory)
                })
            }
        }
    }

    private static func runBlocking(
        _ executable: URL,
        _ arguments: [String],
        _ environment: [String: String],
        _ currentDirectory: URL?
    ) throws -> ProcessOutput {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = currentDirectory
        process.standardInput = FileHandle.nullDevice

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        // Drain both pipes concurrently so a chatty process can't deadlock on a full buffer.
        let group = DispatchGroup()
        nonisolated(unsafe) var errorData = Data()
        group.enter()
        DispatchQueue.global().async {
            errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()

        return ProcessOutput(
            exitCode: process.terminationStatus,
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self)
        )
    }
}
