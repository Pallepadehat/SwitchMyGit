# Security Policy

SwitchMyGit edits Git configuration and can reference SSH keys, so security reports are taken seriously.

## Reporting a vulnerability

Please **don't** open a public issue. Use GitHub's [private vulnerability reporting](https://github.com/Pallepadehat/SwitchMyGit/security/advisories/new).

You'll get a reply within a few days. Once a fix is released, you'll be credited unless you'd rather not be.

## Security design

- SwitchMyGit never reads, copies or stores private key contents. Only key *paths* are saved.
- No tokens or passwords are stored. Settings live in plain JSON with `0600` permissions.
- Git runs through `Process` with an argument array, never through a shell. Values written into `core.sshCommand` are shell-quoted.
- The app makes no network requests.
