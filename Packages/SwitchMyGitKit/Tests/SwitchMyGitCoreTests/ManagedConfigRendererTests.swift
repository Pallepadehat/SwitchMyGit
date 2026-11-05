import Foundation
import Testing
@testable import SwitchMyGitCore

@Suite("Rendering managed Git configuration")
struct ManagedConfigRendererTests {
    let home = URL(filePath: "/Users/pat", directoryHint: .isDirectory)
    var renderer: ManagedConfigRenderer { ManagedConfigRenderer(paths: SwitcherPaths(home: home)) }

    @Test func defaultIdentityIsIncludedBeforeAnyRule() throws {
        let rule = RepositoryRule(pattern: "~/Code/work", profileID: Fixtures.work.id)
        let entry = renderer.render(Fixtures.configuration(rules: [rule])).entry

        let defaultIndex = try #require(entry.range(of: "default.gitconfig")).lowerBound
        let ruleIndex = try #require(entry.range(of: "[includeIf")).lowerBound
        #expect(defaultIndex < ruleIndex)
    }

    @Test func nestedDirectoriesAreOrderedSoTheMostSpecificWins() {
        let deep = RepositoryRule(pattern: "~/Code/work/oss", profileID: Fixtures.personal.id)
        let shallow = RepositoryRule(pattern: "~/Code/work", profileID: Fixtures.work.id)
        let remote = RepositoryRule(kind: .remote, pattern: "github.com/client", profileID: Fixtures.client.id)

        let ordered = ManagedConfigRenderer.orderedByPrecedence([remote, deep, shallow])
        #expect(ordered.map(\.id) == [shallow.id, deep.id, remote.id])
    }

    @Test func disabledRulesAreNotRendered() {
        let rule = RepositoryRule(pattern: "~/Code/work", profileID: Fixtures.work.id, isEnabled: false)
        let entry = renderer.render(Fixtures.configuration(rules: [rule])).entry
        #expect(!entry.contains("includeIf"))
    }

    @Test func directoryRulesUseCaseInsensitiveGitdirWithTrailingSlash() {
        let rule = RepositoryRule(pattern: "/Users/pat/Code/work", profileID: Fixtures.work.id)
        let entry = renderer.render(Fixtures.configuration(rules: [rule])).entry
        #expect(entry.contains(#"[includeIf "gitdir/i:~/Code/work/"]"#))
    }

    @Test func remoteRulesCoverHTTPSAndSSHRemotes() {
        let globs = RulePattern.remoteURLGlobs(for: "github.com/acme/")
        #expect(globs == ["https://github.com/acme/**", "ssh://git@github.com/acme/**", "git@github.com:acme/**"])
        #expect(RulePattern.remoteURLGlobs(for: "git@gitlab.example.com:team/**") == ["git@gitlab.example.com:team/**"])
    }

    @Test func valuesAreQuotedSoSpecialCharactersSurvive() {
        let profile = GitProfile(name: "Odd", userName: #"Pat "the" Dev; #1"#, email: "pat@odd.dev")
        let text = renderer.renderProfile(profile)
        #expect(text.contains(#"name = "Pat \"the\" Dev; #1""#))
    }

    @Test func sshKeyBecomesAQuotedSSHCommand() {
        let profile = GitProfile(name: "Work", userName: "Pat", email: "pat@work.dev", sshKeyPath: "~/.ssh/id work")
        let text = renderer.renderProfile(profile)
        #expect(text.contains(#"sshCommand = "ssh -i '/Users/pat/.ssh/id work' -o IdentitiesOnly=yes""#))
    }
}
