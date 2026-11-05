import Foundation

/// Helpers for writing syntactically valid Git configuration files.
public enum GitConfigSyntax {
    /// Quotes a value so `#`, `;`, whitespace, quotes and backslashes survive.
    public static func quoteValue(_ value: String) -> String {
        "\"" + escape(value) + "\""
    }

    /// Quotes a subsection name, e.g. the condition of an `includeIf`.
    public static func quoteSubsection(_ value: String) -> String {
        "\"" + escape(value) + "\""
    }

    /// Quotes a path for the POSIX shell that runs `core.sshCommand`.
    public static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Characters that can't be represented safely on a single config line.
    public static func containsControlCharacters(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
