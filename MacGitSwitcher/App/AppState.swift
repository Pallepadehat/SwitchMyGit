import AppKit
import Observation
import SwitchMyGitCore

/// The single source of truth for the UI.
///
/// Views read state from here and call its async actions. Every action that
/// changes Git goes through ``commit(_:)``, which applies the change, verifies
/// it with Git and only then updates the UI.
@MainActor
@Observable
final class AppState {
    // MARK: State

    private(set) var configuration = SwitcherConfiguration()
    private(set) var status: ManagedConfigStatus?
    /// `true` while Git configuration is being changed. Prevents overlapping switches.
    private(set) var isWorking = false
    /// The profile currently being switched to, for inline progress.
    private(set) var switchingToProfileID: UUID?
    /// The tab shown in the Settings window.
    var settingsTab: SettingsTab = .general

    let dependencies: AppDependencies
    var paths: SwitcherPaths { dependencies.paths }

    init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
        do {
            configuration = try dependencies.store.load()
        } catch {
            ErrorPresenter.present(error)
        }
        startMonitoring()
    }

    /// Keeps the status fresh, so changes made outside the app (for example
    /// `git config --global user.email …`) show up in the menu.
    private func startMonitoring() {
        Task { [weak self] in
            while let self {
                await self.refresh()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    // MARK: Derived state

    var profiles: [GitProfile] { configuration.profiles }
    var defaultProfile: GitProfile? { configuration.defaultProfile }
    var isActive: Bool { status?.isInstalled ?? false }

    var health: Health {
        guard let status else { return .loading }
        guard status.isInstalled else { return .notSetUp }
        guard let defaultProfile else { return .noDefaultProfile }
        if !status.globalIdentity.matches(defaultProfile) {
            return .defaultOverridden(actual: status.globalIdentity)
        }
        return .healthy
    }

    /// Rules in the order Git evaluates them (the last match wins).
    var orderedRules: [RepositoryRule] {
        ManagedConfigRenderer.orderedByPrecedence(configuration.rules)
    }

    func profile(for id: UUID) -> GitProfile? {
        configuration.profile(withID: id)
    }

    // MARK: Status

    func refresh() async {
        do {
            status = try await dependencies.configService.status()
        } catch {
            status = nil
        }
    }

    // MARK: Setup

    /// Adds the managed include to `~/.gitconfig` (after taking a backup).
    func activate() async {
        await perform {
            try await self.dependencies.configService.install(self.configuration)
        }
    }

    /// Removes everything SwitchMyGit added, optionally keeping the default
    /// identity in `~/.gitconfig` so Git keeps working.
    func deactivate(keepingDefaultIdentity: Bool) async {
        await perform {
            let profile = keepingDefaultIdentity ? self.defaultProfile : nil
            try await self.dependencies.configService.uninstall(keeping: profile)
        }
    }

    /// Creates a profile from the identity Git currently uses.
    @discardableResult
    func importCurrentIdentity() async -> GitProfile? {
        guard let identity = status?.globalIdentity, let email = identity.email else { return nil }
        let isFirst = configuration.profiles.isEmpty
        let profile = GitProfile(
            name: isFirst ? "Personal" : "Imported",
            userName: identity.name ?? "",
            email: email
        )
        var updated = configuration
        updated.upsert(profile)
        await commit(updated)
        return profile
    }

    /// Removes `user.*` written directly in `~/.gitconfig`, which would otherwise
    /// override the default profile.
    func removeUnmanagedIdentity() async {
        await perform {
            try await self.dependencies.configService.removeUnmanagedIdentity()
        }
    }

    // MARK: Profiles

    func setDefault(_ profile: GitProfile) async {
        guard profile.id != configuration.defaultProfileID || health != .healthy else { return }
        switchingToProfileID = profile.id
        defer { switchingToProfileID = nil }

        var updated = configuration
        updated.defaultProfileID = profile.id
        await commit(updated)
    }

    func save(_ profile: GitProfile) async {
        var updated = configuration
        updated.upsert(profile)
        await commit(updated)
    }

    func delete(_ profile: GitProfile) async {
        var updated = configuration
        updated.removeProfile(withID: profile.id)
        await commit(updated)
    }

    // MARK: Rules

    func save(_ rule: RepositoryRule) async {
        var updated = configuration
        updated.upsert(rule)
        await commit(updated)
    }

    func delete(_ rule: RepositoryRule) async {
        var updated = configuration
        updated.rules.removeAll { $0.id == rule.id }
        await commit(updated)
    }

    func setEnabled(_ isEnabled: Bool, for rule: RepositoryRule) async {
        var rule = rule
        rule.isEnabled = isEnabled
        await save(rule)
    }

    // MARK: Inspection

    func inspect(_ directory: URL) async -> RepositoryInspection? {
        do {
            return try await dependencies.inspector.inspect(directory, configuration: configuration)
        } catch {
            ErrorPresenter.present(error)
            return nil
        }
    }

    // MARK: Plumbing

    /// Applies a new configuration to Git (when active) and persists it.
    /// The UI only changes once Git has accepted the new configuration.
    private func commit(_ updated: SwitcherConfiguration) async {
        await perform {
            if self.isActive {
                try await self.dependencies.configService.apply(updated)
            }
            try self.dependencies.store.save(updated)
            self.configuration = updated
        }
    }

    /// Runs one Git-changing operation at a time, reports errors and refreshes status.
    private func perform(_ operation: @escaping () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await operation()
        } catch {
            ErrorPresenter.present(error)
        }
        await refresh()
    }
}

extension AppState {
    enum Health: Equatable {
        case loading
        case notSetUp
        case noDefaultProfile
        /// Something outside SwitchMyGit sets a different global identity.
        case defaultOverridden(actual: GitIdentity)
        case healthy

        var needsAttention: Bool {
            switch self {
            case .healthy, .loading: false
            default: true
            }
        }
    }
}
