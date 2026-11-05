import Foundation

/// Adds and removes the one block SwitchMyGit owns inside `~/.gitconfig`.
///
/// Everything else in the file is left byte-for-byte untouched. The block is
/// always placed at the end of the file: Git applies the last value it reads,
/// so the managed identity wins over older `[user]` entries above it.
public enum GlobalConfigBlock {
    static let beginMarker = "# >>> switchmygit (managed block — edit in the SwitchMyGit app) >>>"
    static let endMarker = "# <<< switchmygit <<<"

    /// The block text for a given include path.
    public static func block(includePath: String) -> String {
        """
        \(beginMarker)
        [include]
        \tpath = \(GitConfigSyntax.quoteValue(includePath))
        \(endMarker)
        """
    }

    public static func isInstalled(in text: String) -> Bool {
        range(in: text) != nil
    }

    /// Returns `text` with exactly one managed block, appended at the end.
    public static func installing(includePath: String, in text: String) -> String {
        var result = removing(from: text)
        if !result.isEmpty {
            if !result.hasSuffix("\n") { result += "\n" }
            if !result.hasSuffix("\n\n") { result += "\n" }
        }
        return result + block(includePath: includePath) + "\n"
    }

    /// Returns `text` without the managed block (and the blank line before it).
    public static func removing(from text: String) -> String {
        var result = text
        while let range = range(in: result) {
            result.removeSubrange(range)
        }
        // Tidy the gap we leave behind, but never touch the user's own content.
        while result.hasSuffix("\n\n") { result.removeLast() }
        return result
    }

    /// The range of the block including its trailing newline.
    private static func range(in text: String) -> Range<String.Index>? {
        guard let begin = text.range(of: beginMarker),
              let end = text.range(of: endMarker, range: begin.upperBound..<text.endIndex)
        else { return nil }

        var upper = end.upperBound
        if upper < text.endIndex, text[upper] == "\n" {
            upper = text.index(after: upper)
        }
        return begin.lowerBound..<upper
    }
}
