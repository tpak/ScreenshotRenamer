//
//  UpdateManager.swift
//  ScreenshotRenamer
//
//  Sparkle auto-update integration
//

import Foundation
import Sparkle
import os.log

/// Handles Sparkle updater delegate callbacks
private class UpdateDelegate: NSObject, SPUUpdaterDelegate {
    private func log(_ message: String, type: OSLogType = .info) {
        os_log("%{public}@", log: .default, type: type, message)
        DebugLogger.shared.log(message, category: "Update")
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        log("Sparkle loaded appcast with \(appcast.items.count) item(s)")
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        log("Sparkle found update: \(item.displayVersionString)")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        log("Sparkle did not find an installable update")
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        log("Sparkle aborted update: \(error.localizedDescription)", type: .error)
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        log("Sparkle willInstallUpdate: \(item.displayVersionString)")
        SettingsSnapshot.save()
    }
}

/// Manages app updates via Sparkle framework
class UpdateManager {
    let updaterController: SPUStandardUpdaterController
    private let delegate = UpdateDelegate()

    init(defaults: UserDefaults = .standard) {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        applyAutoCheckMigration(defaults: defaults)
        let autoChecks = updaterController.updater.automaticallyChecksForUpdates
        let autoDownloads = updaterController.updater.automaticallyDownloadsUpdates
        DebugLogger.shared.log(
            "Sparkle updater initialized (autoChecks=\(autoChecks), autoDownloads=\(autoDownloads))",
            category: "Update"
        )
    }

    /// Issue #42: ensure automatic update checks are enabled for existing users.
    ///
    /// Builds ≤1.14.2 shipped without `SUEnableAutomaticChecks`, so Sparkle relied on
    /// a first-launch permission prompt to start background checks. On this menu-bar
    /// (`LSUIElement`) app that prompt path is unreliable, so many users never had
    /// checks enabled and silently stopped receiving updates. The Info.plist default
    /// added in 1.15.1 only covers fresh installs — it can't reach a client that
    /// isn't checking — so this one-time migration force-enables checks for existing
    /// users on their next launch of a build that contains it.
    private func applyAutoCheckMigration(defaults: UserDefaults) {
        let applied = defaults.bool(forKey: AutoUpdateMigration.defaultsKey)
        let updater = updaterController.updater
        if AutoUpdateMigration.shouldEnableChecks(
            migrationApplied: applied,
            currentlyEnabled: updater.automaticallyChecksForUpdates
        ) {
            updater.automaticallyChecksForUpdates = true
            DebugLogger.shared.log(
                "Auto-update checks were off; force-enabled via one-time migration (issue #42)",
                category: "Update"
            )
        }
        if !applied {
            defaults.set(true, forKey: AutoUpdateMigration.defaultsKey)
        }
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updaterController.updater.automaticallyDownloadsUpdates }
        set { updaterController.updater.automaticallyDownloadsUpdates = newValue }
    }

    /// Update check interval in seconds
    var updateCheckInterval: TimeInterval {
        get { updaterController.updater.updateCheckInterval }
        set { updaterController.updater.updateCheckInterval = newValue }
    }

    /// Standard interval options
    enum CheckFrequency: TimeInterval, CaseIterable {
        case daily = 86_400
        case weekly = 604_800
        case monthly = 2_592_000

        var title: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            }
        }

        /// Find the closest matching frequency for a given interval
        static func from(interval: TimeInterval) -> CheckFrequency {
            let sorted = allCases.sorted { abs($0.rawValue - interval) < abs($1.rawValue - interval) }
            return sorted.first ?? .weekly
        }
    }
}

/// One-time migration policy for re-enabling automatic update checks (issue #42).
enum AutoUpdateMigration {
    /// UserDefaults key recording that the migration has already run.
    static let defaultsKey = "AutoCheckMigrationApplied"

    /// Whether the one-time migration should force-enable automatic checks.
    ///
    /// Acts only when the migration has not yet run *and* checks are currently off,
    /// so a user who deliberately disables checks after the migration is respected.
    static func shouldEnableChecks(migrationApplied: Bool, currentlyEnabled: Bool) -> Bool {
        !migrationApplied && !currentlyEnabled
    }
}
