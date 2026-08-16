//
//  BackgroundModeManager.swift
//  ScreenshotRenamer
//
//  "Run in background" preference — hides the menu bar icon (issue #33)
//

import Foundation

extension Notification.Name {
    /// Posted (locally and via `DistributedNotificationCenter`) to ask the running
    /// instance to surface its Settings window. This is the way back in when the
    /// menu bar icon is hidden.
    static let screenshotRenamerShowSettings =
        Notification.Name("com.tirpak.screenshot-renamer.showSettings")
}

/// Persists whether the app runs as a pure background task with no menu bar icon.
///
/// Hiding the icon removes the app's only UI affordance — there is no dock icon
/// either (`LSUIElement`) — so re-launching the app is wired up to reopen the
/// Settings window instead of starting a second instance. See `AppDelegate`.
final class BackgroundModeManager {
    static let shared = BackgroundModeManager()

    /// UserDefaults key backing the preference. Persisted contract — keep stable.
    static let defaultsKey = "RunInBackground"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Whether the menu bar icon should be hidden. Defaults to `false`.
    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.defaultsKey) }
        set { defaults.set(newValue, forKey: Self.defaultsKey) }
    }
}
