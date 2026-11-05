import AppKit
import SwitchMyGitCore

/// "Who will I commit as here?" — asks for a folder and answers in a standard alert.
@MainActor
enum RepositoryCheck {
    static func run(appState: AppState) async {
        guard let folder = Panels.chooseFolder(
            prompt: String(localized: "Check"),
            message: String(localized: "Choose a repository to see which identity its commits will use."),
            startingAt: appState.paths.home.appending(path: "Code")
        ) else { return }

        guard let inspection = await appState.inspect(folder) else { return }

        let alert = NSAlert()
        let name = (inspection.repositoryRoot ?? inspection.directory).lastPathComponent
        if let email = inspection.identity.email {
            alert.messageText = "Commits in “\(name)” use \(email)"
            let lines: [String?] = [
                "\(inspection.identity.name ?? "No name") <\(email)>",
                inspection.source.explanation(in: appState),
                inspection.isRepository ? nil : "This folder isn’t a Git repository yet; a new repository here would use this identity.",
            ]
            alert.informativeText = lines.compactMap(\.self).joined(separator: "\n\n")
        } else {
            alert.alertStyle = .critical
            alert.messageText = "Commits in “\(name)” will fail"
            alert.informativeText = inspection.source.explanation(in: appState)
        }
        alert.addButton(withTitle: String(localized: "Done"))
        alert.addButton(withTitle: String(localized: "Check Another…"))

        NSApp.activate()
        if alert.runModal() == .alertSecondButtonReturn {
            await run(appState: appState)
        }
    }
}
