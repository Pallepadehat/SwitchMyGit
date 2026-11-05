import Foundation
import Testing
@testable import SwitchMyGitCore

@Suite("Validation")
struct ValidationTests {
    @Test(arguments: ["me@example.com", "first.last+tag@sub.example.co.uk"])
    func acceptsPlausibleEmails(_ email: String) {
        #expect(Validator.isPlausibleEmail(email))
    }

    @Test(arguments: ["", "me", "me@", "@example.com", "me@example", "me @example.com", "a@b@c.com"])
    func rejectsImplausibleEmails(_ email: String) {
        #expect(!Validator.isPlausibleEmail(email))
    }

    @Test func profileNamesMustBeUnique() {
        let duplicate = GitProfile(name: "work", userName: "Pat", email: "pat@x.dev")
        let issues = Validator.validate(duplicate, among: [Fixtures.work])
        #expect(issues.contains(.duplicateProfileName))
    }

    @Test func newlinesAreRejected() {
        let profile = GitProfile(name: "Bad", userName: "Pat\n[core]", email: "pat@x.dev")
        #expect(Validator.validate(profile, among: []).contains(.unsupportedCharacters))
    }

    @Test func equivalentDirectoryRulesAreDuplicates() {
        let home = URL(filePath: "/Users/pat")
        let existing = RepositoryRule(pattern: "~/Code/Work/", profileID: Fixtures.work.id)
        let candidate = RepositoryRule(pattern: "/Users/pat/Code/work", profileID: Fixtures.personal.id)
        #expect(Validator.validate(candidate, among: [existing], home: home).contains(.duplicateRule))
    }
}
