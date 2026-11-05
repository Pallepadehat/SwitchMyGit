PROJECT := MacGitSwitcher.xcodeproj
SCHEME  := MacGitSwitcher
PACKAGE := Packages/SwitchMyGitKit

.PHONY: test build dmg release icons format clean

## Run the core test suite (real Git, isolated temporary HOME).
test:
	swift test --package-path $(PACKAGE)

## Build build/SwitchMyGit.app.
build:
	./scripts/build.sh

## Build build/SwitchMyGit.dmg.
dmg:
	./scripts/make-dmg.sh

## Publish a GitHub release (see CONTRIBUTING.md).
release:
	./scripts/release.sh

## Regenerate the app icon, logo and social preview image.
icons:
	swift scripts/generate-icons.swift

## Format Swift sources (requires swift-format, bundled with Xcode 16+).
format:
	swift format --in-place --recursive MacGitSwitcher $(PACKAGE)

clean:
	rm -rf build $(PACKAGE)/.build
