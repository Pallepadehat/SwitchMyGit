import Foundation

/// Small, safe file helpers shared by the services.
enum FileSystem {
    /// Writes `contents` atomically (write to a temporary file, then rename),
    /// creating intermediate directories and following symlinks so dotfile
    /// managers that symlink `~/.gitconfig` keep working.
    static func writeAtomically(_ contents: String, to url: URL, permissions: Int? = nil) throws {
        let target = url.resolvingSymlinksInPath()
        let manager = FileManager.default
        try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)

        let existingPermissions = (try? manager.attributesOfItem(atPath: target.path))?[.posixPermissions] as? Int
        try Data(contents.utf8).write(to: target, options: .atomic)

        if let mode = permissions ?? existingPermissions {
            try manager.setAttributes([.posixPermissions: mode], ofItemAtPath: target.path)
        }
    }

    /// Returns the file's contents, or `nil` when it does not exist.
    static func readIfExists(_ url: URL) throws -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func removeIfExists(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
