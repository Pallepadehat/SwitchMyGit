import Foundation
import Testing
@testable import SwitchMyGitCore

@Suite("Persistence")
struct StorageTests {
    @Test func configurationRoundTrips() throws {
        let home = try TemporaryHome()
        let store = ConfigurationStore(fileURL: home.paths.configurationFile)
        let configuration = Fixtures.configuration(rules: [
            RepositoryRule(pattern: "~/Code/work", profileID: Fixtures.work.id),
        ])

        try store.save(configuration)
        #expect(try store.load() == configuration)
    }

    @Test func missingFileLoadsAnEmptyConfiguration() throws {
        let home = try TemporaryHome()
        let store = ConfigurationStore(fileURL: home.paths.configurationFile)
        #expect(try store.load() == SwitcherConfiguration())
    }

    @Test func removingAProfileRemovesItsRulesAndReassignsTheDefault() {
        var configuration = Fixtures.configuration(
            rules: [RepositoryRule(pattern: "~/Code/p", profileID: Fixtures.personal.id)],
            default: Fixtures.personal
        )
        configuration.removeProfile(withID: Fixtures.personal.id)
        #expect(configuration.rules.isEmpty)
        #expect(configuration.defaultProfileID == Fixtures.work.id)
    }

    @Test func pathsAreAbbreviatedAndExpanded() {
        let formatter = PathFormatter(home: URL(filePath: "/Users/pat"))
        #expect(formatter.abbreviate("/Users/pat/Code") == "~/Code")
        #expect(formatter.abbreviate("/Users/patrick/Code") == "/Users/patrick/Code")
        #expect(formatter.expand("~/Code") == "/Users/pat/Code")
    }
}
