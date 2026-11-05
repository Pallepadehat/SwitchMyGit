import AppKit

/// Thin wrappers around AppKit's open panel and Finder.
@MainActor
enum Panels {
    static func chooseFolder(prompt: String, message: String, startingAt directory: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = prompt
        panel.message = message
        panel.directoryURL = directory
        NSApp.activate()
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseSSHKey(home: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.prompt = String(localized: "Use Key")
        panel.message = String(localized: "Choose a private SSH key. SwitchMyGit only stores its path.")
        panel.directoryURL = home.appending(path: ".ssh")
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
