PROJECT := MacGitSwitcher.xcodeproj
SCHEME  := MacGitSwitcher
PACKAGE := Packages/SwitchMyGitKit

.PHONY: test build release icons format clean

## Run the core test suite (real Git, isolated temporary HOME).
test:
	swift test --package-path $(PACKAGE)

## Build the app (unsigned).
build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath build CODE_SIGNING_ALLOWED=NO build

## Build a Release archive. Signing uses the team configured in Xcode.
release:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-archivePath build/SwitchMyGit.xcarchive archive

## Regenerate the app icon, logo and social preview image.
icons:
	swift scripts/generate-icons.swift

## Format Swift sources (requires swift-format, bundled with Xcode 16+).
format:
	swift format --in-place --recursive MacGitSwitcher $(PACKAGE)

clean:
	rm -rf build $(PACKAGE)/.build
