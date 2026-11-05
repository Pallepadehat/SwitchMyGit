# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Menu bar app for switching the default Git identity.
- Profiles with name, e-mail and an optional SSH key.
- Folder rules (`gitdir/i:`) and remote rules (`hasconfig:remote.*.url:`).
- Check Repository: see which identity a folder uses, and why.
- Safe installation into `~/.gitconfig`, with backups, verification and rollback.
- Detection of `[user]` entries that override the default profile, with a one-click fix.
- Open at login.
