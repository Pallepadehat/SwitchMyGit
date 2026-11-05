import Foundation

/// Loads and saves the user's profiles and rules as human-readable JSON.
///
/// The file never contains secrets: SSH keys are referenced by path only.
public struct ConfigurationStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Returns the saved configuration, or an empty one on first launch.
    public func load() throws -> SwitcherConfiguration {
        guard let data = try? Data(contentsOf: fileURL) else {
            return SwitcherConfiguration()
        }
        do {
            return try JSONDecoder().decode(SwitcherConfiguration.self, from: data)
        } catch {
            throw StoreError.unreadable(fileURL, underlying: error.localizedDescription)
        }
    }

    public func save(_ configuration: SwitcherConfiguration) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(configuration)
        try FileSystem.writeAtomically(String(decoding: data, as: UTF8.self) + "\n", to: fileURL, permissions: 0o600)
    }

    public enum StoreError: LocalizedError {
        case unreadable(URL, underlying: String)

        public var errorDescription: String? {
            switch self {
            case let .unreadable(url, underlying):
                "Your SwitchMyGit settings at \(url.path) could not be read (\(underlying)). Fix or remove the file and relaunch."
            }
        }
    }
}
