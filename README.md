<p align="center">
  <img src="docs/assets/logo.png" width="128" alt="SwitchMyGit icon">
</p>

<h1 align="center">SwitchMyGit</h1>

<p align="center">
  The right Git identity in every repository.<br>
  A small, native macOS menu bar app for people who commit as more than one person.
</p>

<p align="center">
  <a href="https://github.com/Pallepadehat/MacGitSwitcher/actions/workflows/ci.yml"><img src="https://github.com/Pallepadehat/MacGitSwitcher/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-27%2B-lightgrey" alt="macOS 27+">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT License">
</p>

---

Have you ever pushed a work commit with your personal e-mail, or the reverse? SwitchMyGit fixes that:

- **Switch your default identity** from the menu bar in one click.
- **Assign profiles to folders** (`~/Code/work/` → Work) **or remotes** (`github.com/acme` → Work). Git then picks the right identity automatically.
- **Check any repository** to see which identity your next commit will use, and why.
- **Optionally pick an SSH key per profile**, so pushes authenticate with the right account.

<p align="center">
  <img src="docs/assets/screenshot-rules.png" width="600" alt="Rules settings">
</p>

## How it works

SwitchMyGit **configures Git** instead of watching it. Your rules are compiled into Git's own [conditional includes](https://git-scm.com/docs/git-config#_conditional_includes), so they:

- work in every terminal, editor and GUI client (VS Code, Xcode, JetBrains, Tower and others),
- keep working when the app isn't running,
- use no background CPU.

SwitchMyGit adds one clearly marked block at the end of `~/.gitconfig` and keeps everything else in its own folder:

```gitconfig
# >>> switchmygit (managed block — edit in the SwitchMyGit app) >>>
[include]
	path = "~/.config/switchmygit/switchmygit.gitconfig"
# <<< switchmygit <<<
```

```text
~/.config/switchmygit/
├── switchmygit.gitconfig   # includes the files below, in precedence order
├── default.gitconfig       # the default profile
├── profiles/<id>.gitconfig # one file per profile
└── backups/                # copies of ~/.gitconfig, taken before every change
```

Precedence, from weakest to strongest:

1. The **default profile** (switchable from the menu bar)
2. **Folder rules**, where nested folders beat their parents
3. **Remote rules**
4. A repository's own **`.git/config`**, which SwitchMyGit always respects

Before every change SwitchMyGit backs up `~/.gitconfig`, writes the new files atomically, asks Git to read them back, and restores the previous state if anything fails. Turning SwitchMyGit off removes only the block and the folder above, and can keep your current identity in `~/.gitconfig`.

## Installation

Signed releases will be published on the [Releases](https://github.com/Pallepadehat/MacGitSwitcher/releases) page. Until then, build it yourself:

```sh
git clone https://github.com/Pallepadehat/MacGitSwitcher.git
cd MacGitSwitcher
open MacGitSwitcher.xcodeproj   # then press ⌘R
```

Requirements: macOS 27 or later, Git 2.36 or later (for remote rules), and Xcode 27 to build.

## Project layout

```text
MacGitSwitcher/               SwiftUI app (menu bar menu, Settings window)
├── App/                      Entry point, AppState, dependency wiring
├── Features/                 One folder per feature: MenuBar, Settings, Profiles, Rules, RepositoryCheck
├── Components/               Small reusable views
└── Support/                  AppKit helpers (panels, alerts, login item)
Packages/SwitchMyGitKit/      Swift package with all logic. No UI code; fully unit-tested.
├── Sources/SwitchMyGitCore/  Models, Git client, config renderer, services
└── Tests/                    Unit tests and end-to-end tests against real Git
scripts/                      Icon generator and other tooling
docs/                         Architecture notes and images
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the design.

## Development

```sh
make test     # run the core test suite (uses real Git in a throwaway HOME)
make build    # build the app
make icons    # regenerate the app icon from scripts/generate-icons.swift
```

Debug builds accept `-SwitchMyGitHome /some/folder` as a launch argument, so you can try the app against a sandbox home without touching your real `~/.gitconfig`. In Xcode, add it under *Product › Scheme › Edit Scheme › Arguments*.

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © 2026 Patrick Jakobsen
