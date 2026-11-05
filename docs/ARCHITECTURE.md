# Architecture

SwitchMyGit is a native, local-first macOS app that **configures Git instead of intercepting it**. All of the behavior lives in Git's own configuration files, so it works in every tool and keeps working when the app isn't running.

## Modules

```text
┌────────────────────────────────────────────────────────────┐
│ MacGitSwitcher (app target)                                │
│   MenuBarMenu · SettingsView (General / Profiles / Rules)  │
│   RepositoryCheck · AppState (@Observable, @MainActor)     │
└───────────────────────────┬────────────────────────────────┘
                            │ async calls
┌───────────────────────────▼────────────────────────────────┐
│ SwitchMyGitCore (Swift package, no UI)                     │
│   Services:  ManagedConfigService · IdentityInspector      │
│              SSHKeyService · BackupService · Validator     │
│   Git:       GitClient · ProcessRunner · RulePattern       │
│              ManagedConfigRenderer · GlobalConfigBlock     │
│   Storage:   ConfigurationStore (JSON)                     │
│   Models:    GitProfile · RepositoryRule · …               │
└───────────────────────────┬────────────────────────────────┘
                            │ Process (no shell)
                        git config
```

- **The app target** contains only presentation code. `AppState` is the single source of truth: views read its properties and call its async actions.
- **`SwitchMyGitCore`** contains everything that can be tested: models, the Git client and the file logic. It has no SwiftUI or AppKit dependencies, so `swift test` runs it on any Mac or CI runner.
- Dependencies are passed through initializers (`AppDependencies.live()`). There's no DI framework and no singletons.

## Data flow for a change

Every edit (switching the default, saving a profile, toggling a rule) follows the same path:

```text
View ─▶ AppState.commit(newConfiguration)
          ├─ ManagedConfigService.apply()   back up · render · write atomically · verify with Git · roll back on failure
          ├─ ConfigurationStore.save()      only after Git accepted the change
          └─ AppState.configuration = new   the UI updates last
```

`AppState.perform` runs one operation at a time (`isWorking`), so two switches can never interleave. Errors appear as standard `NSAlert`s.

## Files on disk

| File | Owner | Purpose |
| --- | --- | --- |
| `~/.gitconfig` | **you** | SwitchMyGit adds one marked `[include]` block at the end and never touches anything else. |
| `~/.config/switchmygit/switchmygit.gitconfig` | SwitchMyGit | Includes the default profile, then `includeIf` rules in precedence order. |
| `~/.config/switchmygit/default.gitconfig` | SwitchMyGit | The default profile's `[user]`. Rewriting this one file switches the default atomically. |
| `~/.config/switchmygit/profiles/<uuid>.gitconfig` | SwitchMyGit | One file per profile, referenced by rules. |
| `~/.config/switchmygit/backups/` | SwitchMyGit | The 10 most recent copies of `~/.gitconfig`. |
| `~/Library/Application Support/SwitchMyGit/configuration.json` | SwitchMyGit | Profiles and rules (no secrets, `0600`). |

Profiles are referenced by UUID, so renaming a profile never breaks a rule.

## Precedence

Git keeps the **last** value it reads. `ManagedConfigRenderer` therefore writes:

1. `[include] default.gitconfig`
2. folder rules, shallowest first (`gitdir/i:~/Code/` before `gitdir/i:~/Code/work/`)
3. remote rules (`hasconfig:remote.*.url:…`)

Repository-local config (`.git/config`) is read after all global config, so it always wins. `IdentityInspector` reports this as "Repository override".

The managed block sits at the **end** of `~/.gitconfig`, so the default profile beats older `[user]` entries above it. If `git config --global user.email …` later appends a new `[user]` section after the block, `ManagedConfigService.status()` detects it, and the app offers to remove it after taking a backup.

## Edge cases covered by tests

- Existing settings, aliases and credential helpers are preserved byte for byte.
- A symlinked `~/.gitconfig` (from a dotfile manager) is edited through the link.
- Nested folder rules: the deepest folder wins.
- Case-insensitive paths (`gitdir/i:`), to match the default macOS file system.
- Linked worktrees: `gitdir` matches the *main* repository's location.
- Remote rules cover HTTPS, `ssh://` and scp-style URLs.
- Disabled rules fall back to the default.
- Turning SwitchMyGit off leaves your other settings intact and can keep a working identity.

All of these run against real Git in an isolated temporary `HOME` (`TemporaryHome` in the tests), so the suite never touches your configuration.
