import AppKit

/// Shows errors as standard macOS alerts, from anywhere in the app —
/// including the menu bar menu, which can't host SwiftUI alerts.
@MainActor
enum ErrorPresenter {
    static func present(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "SwitchMyGit Couldn’t Update Git")
        alert.informativeText = error.localizedDescription
        NSApp.activate()
        alert.runModal()
    }

    static func present(message: String, information: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = information
        NSApp.activate()
        alert.runModal()
    }
}
