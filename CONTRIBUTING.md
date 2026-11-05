# Contributing to SwitchMyGit

Thanks for helping! This guide explains how to get a change merged.

## Ground rules

- **Never risk someone's Git configuration.** Any code that writes to disk goes through `ManagedConfigService` (back up, write atomically, verify, roll back), and it needs a test that runs against real Git in a `TemporaryHome`.
- **Use native macOS patterns.** Prefer standard controls (`Form`, `Table`, `Settings`, menus, `NSAlert`) over custom-drawn UI.
- **Keep logic out of views.** Anything testable belongs in `Packages/SwitchMyGitKit`. Views read `AppState` and call its actions.

## Getting started

1. Fork and clone the repository.
2. Run `make test` to check that the core tests pass.
3. Open `MacGitSwitcher.xcodeproj` and run the `MacGitSwitcher` scheme.
4. To avoid touching your real `~/.gitconfig`, pass `-SwitchMyGitHome /tmp/switchmygit-sandbox` as a launch argument. This works in Debug builds only.

## Making a change

- Create a branch from `main`.
- Keep pull requests focused, with one feature or fix each.
- Add or update tests in `Packages/SwitchMyGitKit/Tests`.
- Update `CHANGELOG.md` under **Unreleased**.
- Make sure `make test` and `make build` pass. CI runs both.

## Code style

- Swift 6 with strict concurrency.
- Name types after what they do: `ManagedConfigRenderer`, not `Helper`.
- Write doc comments on types and on any non-obvious function. Explain *why*, not *what*.
- Prefer small files with one type each, grouped by feature.
- Run `swift format` if you have it installed; a `.swift-format` file is included.

## Reporting bugs

Open an issue with the bug report template. Include your macOS and Git versions, and if possible the output of:

```sh
git config --list --show-origin --show-scope | grep -E 'user\.|include'
```

Remove any private values before posting.
