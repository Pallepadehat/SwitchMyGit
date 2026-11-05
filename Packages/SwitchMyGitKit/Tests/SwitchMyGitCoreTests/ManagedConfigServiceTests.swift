import Foundation
import Testing
@testable import SwitchMyGitCore

/// End-to-end tests against real Git in a temporary home directory.
@Suite("Applying configuration with real Git", .serialized)
struct ManagedConfigServiceTests {
    let home: TemporaryHome

    init() throws {
        home = try TemporaryHome()
    }

    @Test func installPreservesExistingSettings() async throws {
        try home.write("[alias]\n\tco = checkout\n", to: ".gitconfig")
        try await home.service.install(Fixtures.configuration())

        #expect(try home.read(".gitconfig").hasPrefix("[alias]\n\tco = checkout\n"))
        #expect(try await home.git.resolve("alias.co", globalOnly: true)?.value == "checkout")
        #expect(try await home.git.resolve("user.email", globalOnly: true)?.value == Fixtures.personal.email)
    }

    @Test func installCreatesABackup() async throws {
        try home.write("[alias]\n\tco = checkout\n", to: ".gitconfig")
        try await home.service.install(Fixtures.configuration())
        #expect(BackupService(paths: home.paths).backups().count == 1)
    }

    @Test func switchingTheDefaultChangesTheGlobalIdentity() async throws {
        try await home.service.install(Fixtures.configuration(default: Fixtures.personal))
        try await home.service.apply(Fixtures.configuration(default: Fixtures.work))

        let status = try await home.service.status()
        #expect(status.globalIdentity.matches(Fixtures.work))
    }

    @Test func directoryRulesBeatTheDefaultForRealCommits() async throws {
        let rules = [RepositoryRule(pattern: "~/Code/work", profileID: Fixtures.work.id)]
        try await home.service.install(Fixtures.configuration(rules: rules, default: Fixtures.personal))

        let workRepo = try await home.makeRepository("Code/work/api")
        let otherRepo = try await home.makeRepository("Code/side-project")

        #expect(try await home.commitAuthorEmail(in: workRepo) == Fixtures.work.email)
        #expect(try await home.commitAuthorEmail(in: otherRepo) == Fixtures.personal.email)
    }

    @Test func directoryMatchingIsCaseInsensitive() async throws {
        let rules = [RepositoryRule(pattern: "~/code/WORK", profileID: Fixtures.work.id)]
        try await home.service.install(Fixtures.configuration(rules: rules))
        let repo = try await home.makeRepository("Code/work/api")
        #expect(try await home.effectiveEmail(in: repo) == Fixtures.work.email)
    }

    @Test func theMostSpecificNestedRuleWins() async throws {
        let rules = [
            RepositoryRule(pattern: "~/Code/work/open-source", profileID: Fixtures.client.id),
            RepositoryRule(pattern: "~/Code/work", profileID: Fixtures.work.id),
        ]
        try await home.service.install(Fixtures.configuration(rules: rules))

        let nested = try await home.makeRepository("Code/work/open-source/lib")
        let parent = try await home.makeRepository("Code/work/api")
        #expect(try await home.effectiveEmail(in: nested) == Fixtures.client.email)
        #expect(try await home.effectiveEmail(in: parent) == Fixtures.work.email)
    }

    @Test func remoteRulesMatchByOrganisation() async throws {
        let rules = [RepositoryRule(kind: .remote, pattern: "github.com/acme", profileID: Fixtures.work.id)]
        try await home.service.install(Fixtures.configuration(rules: rules))

        let acme = try await home.makeRepository("Code/acme-app")
        try await home.git.checkedRun(["remote", "add", "origin", "git@github.com:acme/app.git"], in: acme)
        let other = try await home.makeRepository("Code/other")
        try await home.git.checkedRun(["remote", "add", "origin", "https://github.com/someone/else.git"], in: other)

        #expect(try await home.effectiveEmail(in: acme) == Fixtures.work.email)
        #expect(try await home.effectiveEmail(in: other) == Fixtures.personal.email)
    }

    @Test func disabledRulesFallBackToTheDefault() async throws {
        let rules = [RepositoryRule(pattern: "~/Code/work", profileID: Fixtures.work.id, isEnabled: false)]
        try await home.service.install(Fixtures.configuration(rules: rules))
        let repo = try await home.makeRepository("Code/work/api")
        #expect(try await home.effectiveEmail(in: repo) == Fixtures.personal.email)
    }

    @Test func repositoryLocalIdentityIsKeptAndReported() async throws {
        let rules = [RepositoryRule(pattern: "~/Code/work", profileID: Fixtures.work.id)]
        let configuration = Fixtures.configuration(rules: rules)
        try await home.service.install(configuration)

        let repo = try await home.makeRepository("Code/work/special")
        try await home.git.checkedRun(["config", "user.email", "special@company.com"], in: repo)

        let inspection = try await home.inspector.inspect(repo, configuration: configuration)
        #expect(inspection.identity.email == "special@company.com")
        #expect(inspection.source == .repositoryOverride)
    }

    @Test func inspectorExplainsRuleAndDefaultSources() async throws {
        let rules = [RepositoryRule(pattern: "~/Code/work", profileID: Fixtures.work.id)]
        let configuration = Fixtures.configuration(rules: rules)
        try await home.service.install(configuration)

        let workRepo = try await home.makeRepository("Code/work/api")
        let otherDir = home.url.appending(path: "Desktop", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: otherDir, withIntermediateDirectories: true)

        let work = try await home.inspector.inspect(workRepo, configuration: configuration)
        #expect(work.source == .rule(profileID: Fixtures.work.id))
        #expect(work.isRepository)

        let other = try await home.inspector.inspect(otherDir, configuration: configuration)
        #expect(other.source == .defaultProfile(profileID: Fixtures.personal.id))
        #expect(!other.isRepository)
    }

    @Test func linkedWorktreesFollowTheMainRepositoryLocation() async throws {
        let rules = [RepositoryRule(pattern: "~/Code/work", profileID: Fixtures.work.id)]
        try await home.service.install(Fixtures.configuration(rules: rules))

        let repo = try await home.makeRepository("Code/work/api")
        _ = try await home.commitAuthorEmail(in: repo)
        let worktree = home.url.appending(path: "Elsewhere/api-feature").path(percentEncoded: false)
        try await home.git.checkedRun(["worktree", "add", "--quiet", worktree], in: repo)

        // `gitdir:` matches the *Git directory*, which for a linked worktree
        // lives inside the main repository — so the Work rule still applies.
        #expect(try await home.effectiveEmail(in: URL(filePath: worktree)) == Fixtures.work.email)
    }

    @Test func unmanagedIdentityWrittenAfterTheBlockIsDetectedAndRemovable() async throws {
        try await home.service.install(Fixtures.configuration())
        // Simulates a user running `git config --global user.email ...` later.
        try await home.git.checkedRun(["config", "--global", "user.email", "stray@example.com"])

        var status = try await home.service.status()
        #expect(status.unmanagedIdentity.email == "stray@example.com")
        #expect(status.globalIdentity.email == "stray@example.com")

        try await home.service.removeUnmanagedIdentity()
        status = try await home.service.status()
        #expect(status.unmanagedIdentity.isEmpty)
        #expect(status.globalIdentity.matches(Fixtures.personal))
    }

    @Test func existingConditionalIncludesAreReported() async throws {
        try home.write("[includeIf \"gitdir:~/legacy/\"]\n\tpath = ~/.legacy.gitconfig\n", to: ".gitconfig")
        let status = try await home.service.status()
        #expect(status.foreignConditionalIncludes == ["gitdir:~/legacy/"])
    }

    @Test func uninstallLeavesUnrelatedSettingsAndAWorkingIdentity() async throws {
        try home.write("[alias]\n\tco = checkout\n", to: ".gitconfig")
        try await home.service.install(Fixtures.configuration())
        try await home.service.uninstall(keeping: Fixtures.work)

        let text = try home.read(".gitconfig")
        #expect(!GlobalConfigBlock.isInstalled(in: text))
        #expect(text.contains("co = checkout"))
        #expect(try await home.git.resolve("user.email", globalOnly: true)?.value == Fixtures.work.email)
        #expect(!FileManager.default.fileExists(atPath: home.paths.managedEntryFile.path))
    }

    @Test func deletedProfilesLoseTheirGeneratedFiles() async throws {
        var configuration = Fixtures.configuration()
        try await home.service.install(configuration)
        #expect(FileManager.default.fileExists(atPath: home.paths.profileFile(for: Fixtures.client.id).path))

        configuration.removeProfile(withID: Fixtures.client.id)
        try await home.service.apply(configuration)
        #expect(!FileManager.default.fileExists(atPath: home.paths.profileFile(for: Fixtures.client.id).path))
    }

    @Test func symlinkedGitconfigIsUpdatedInPlace() async throws {
        try home.write("[alias]\n\tco = checkout\n", to: "dotfiles/gitconfig")
        try FileManager.default.createSymbolicLink(
            at: home.paths.globalGitConfig,
            withDestinationURL: home.url.appending(path: "dotfiles/gitconfig")
        )
        try await home.service.install(Fixtures.configuration())

        let attributes = try FileManager.default.attributesOfItem(atPath: home.paths.globalGitConfig.path)
        #expect(attributes[.type] as? FileAttributeType == .typeSymbolicLink)
        #expect(GlobalConfigBlock.isInstalled(in: try home.read("dotfiles/gitconfig")))
    }
}
