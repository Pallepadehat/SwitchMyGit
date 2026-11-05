import Testing
@testable import SwitchMyGitCore

@Suite("Managed block in ~/.gitconfig")
struct GlobalConfigBlockTests {
    let userConfig = """
    [alias]
    \tst = status
    [credential]
    \thelper = osxkeychain
    """

    @Test func installingAppendsTheBlockAtTheEnd() {
        let result = GlobalConfigBlock.installing(includePath: "~/x.gitconfig", in: userConfig)
        #expect(result.hasPrefix(userConfig))
        #expect(result.hasSuffix(GlobalConfigBlock.endMarker + "\n"))
    }

    @Test func installingTwiceKeepsASingleBlock() {
        let once = GlobalConfigBlock.installing(includePath: "~/x.gitconfig", in: userConfig)
        let twice = GlobalConfigBlock.installing(includePath: "~/x.gitconfig", in: once)
        #expect(once == twice)
    }

    @Test func removingRestoresTheOriginalText() {
        let installed = GlobalConfigBlock.installing(includePath: "~/x.gitconfig", in: userConfig + "\n")
        #expect(GlobalConfigBlock.removing(from: installed) == userConfig + "\n")
    }

    @Test func blockMovesToTheEndWhenUserAddedSettingsAfterIt() {
        let installed = GlobalConfigBlock.installing(includePath: "~/x.gitconfig", in: userConfig)
        let edited = installed + "[user]\n\temail = later@example.com\n"
        let reinstalled = GlobalConfigBlock.installing(includePath: "~/x.gitconfig", in: edited)
        #expect(reinstalled.hasSuffix(GlobalConfigBlock.endMarker + "\n"))
        #expect(reinstalled.contains("later@example.com"))
    }

    @Test func emptyFileGetsJustTheBlock() {
        let result = GlobalConfigBlock.installing(includePath: "~/x.gitconfig", in: "")
        #expect(result == GlobalConfigBlock.block(includePath: "~/x.gitconfig") + "\n")
    }
}
