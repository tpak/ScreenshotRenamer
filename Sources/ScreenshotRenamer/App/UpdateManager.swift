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

    func updater(_ updater: SPUUpdater, didFinishLoadingAppcast appcast: SUAppcast) {
        log("Sparkle loaded appcast with \(appcast.items.count) item(s)")
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        log("Sparkle found update: \(item.displayVersionString)")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        log("Sparkle did not find an installable update")
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: NSError) {
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

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        let autoChecks = updaterController.updater.automaticallyChecksForUpdates
        let autoDownloads = updaterController.updater.automaticallyDownloadsUpdates
        DebugLogger.shared.log(
            "Sparkle updater initialized (autoChecks=\(autoChecks), autoDownloads=\(autoDownloads))",
            category: "Update"
        )
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
