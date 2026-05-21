//
//  MenuBarController.swift
//  ScreenshotRenamer
//
//  Menu bar application controller
//  Swift port of src/menubar_app.py
//

import Cocoa
import Sparkle
import UserNotifications
import os.log

// swiftlint:disable type_body_length function_body_length attributes

/// Controls the menu bar icon and menu
class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var watcher: ScreenshotWatcher?
    private var settings: ScreenshotSettings!
    private var detector: ScreenshotDetector!
    private var isWatcherRunning = false

    // Menu items (strong references)
    private var watcherMenuItem: NSMenuItem!
    private var quickRenameMenuItem: NSMenuItem!
    private var locationMenuItem: NSMenuItem!
    private var prefixMenuItem: NSMenuItem!
    private var formatMenuItem: NSMenuItem!
    private var optionsMenuItem: NSMenuItem!
    private var debugMenuItem: NSMenuItem!

    // Settings window
    private var settingsWindowController: SettingsWindowController?

    // Auto-update
    private var updateManager: UpdateManager!

    // Main-thread heartbeat (diagnostic for unresponsive menu bar reports)
    private var heartbeatTimer: Timer?
    private var heartbeatCount: Int = 0
    private let heartbeatStart = Date()

    override init() {
        super.init()
        print("📋 MenuBarController initializing...")

        // Initialize detector first (needed by buildMenu)
        detector = ScreenshotDetector()
        updateManager = UpdateManager()

        setupMenuBar()
        requestNotificationPermissions()
        loadSettings()
        if SettingsSnapshot.restoreIfNeeded(detector: detector) {
            loadSettings() // Reload after restore
        }
        SettingsSnapshot.save() // Persist current known-good state
        autoStartWatcher()
        startHeartbeat()
        print("📋 MenuBarController initialized")
    }

    // A gap between heartbeats means the main run loop was stalled;
    // continuous beats while the icon is reported unresponsive points
    // at NSStatusItem itself, not at us.
    private func startHeartbeat() {
        let timer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.heartbeatCount += 1
            let uptime = Int(Date().timeIntervalSince(self.heartbeatStart))
            let watcherState = self.watcher?.isRunning == true ? "running" : "stopped"
            os_log("Heartbeat #%d uptime=%ds watcher=%{public}@",
                   log: .default, type: .info,
                   self.heartbeatCount, uptime, watcherState)
            DebugLogger.shared.log(
                "Heartbeat #\(self.heartbeatCount) uptime=\(uptime)s watcher=\(watcherState)",
                category: "App"
            )
        }
        RunLoop.main.add(timer, forMode: .common)
        heartbeatTimer = timer
    }

    /// Setup menu bar status item
    private func setupMenuBar() {
        print("🔧 Setting up menu bar...")

        // Create status item
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        print("✅ Status item created: \(statusItem != nil)")

        if let button = statusItem.button {
            print("✅ Status item button exists")

            // Use SF Symbol camera icon (macOS 11+)
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(
                    pointSize: 0,
                    weight: .regular
                )
                button.image = NSImage(
                    systemSymbolName: "camera.fill",
                    accessibilityDescription: "Screenshot Renamer"
                )?.withSymbolConfiguration(config)
                button.image?.isTemplate = true
                print("✅ SF Symbol icon set")
            } else {
                // Fallback for older macOS
                button.title = "📷"
                print("✅ Emoji icon set")
            }
        } else {
            print("❌ ERROR: Status item button is nil!")
        }

        buildMenu()
        print("✅ Menu built and attached")
    }

    /// Build the menu
    private func buildMenu() {
        let menu = NSMenu()

        // Watcher toggle
        watcherMenuItem = NSMenuItem(
            title: "Stop Watcher",
            action: #selector(toggleWatcher),
            keyEquivalent: ""
        )
        watcherMenuItem.target = self
        watcherMenuItem.state = .on // Auto-starts, so initially on
        menu.addItem(watcherMenuItem)

        // Quick rename
        quickRenameMenuItem = NSMenuItem(
            title: "Quick Rename...",
            action: #selector(quickRename),
            keyEquivalent: "r"
        )
        quickRenameMenuItem.target = self
        menu.addItem(quickRenameMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // User Guide
        let userGuideItem = NSMenuItem(
            title: "User Guide",
            action: #selector(openUserGuide),
            keyEquivalent: ""
        )
        userGuideItem.target = self
        menu.addItem(userGuideItem)

        menu.addItem(NSMenuItem.separator())

        // Info items (non-clickable, grey text)
        locationMenuItem = NSMenuItem(
            title: "Location: ...",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(locationMenuItem)

        prefixMenuItem = NSMenuItem(
            title: "Prefix: ...",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(prefixMenuItem)

        formatMenuItem = NSMenuItem(
            title: "Format: ...",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(formatMenuItem)

        optionsMenuItem = NSMenuItem(
            title: "Options: ...",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(optionsMenuItem)

        debugMenuItem = NSMenuItem(
            title: "Debug: Off",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(debugMenuItem)

        menu.addItem(NSMenuItem.separator())

        // About
        let aboutItem = NSMenuItem(
            title: "About Screenshot Renamer",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Screenshot Renamer",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    /// Load screenshot settings from macOS
    private func loadSettings() {
        print("⚙️  Loading settings...")
        settings = detector.detectSettings()
        print("✅ Settings loaded: \(settings.location.path)")
        print("✅ Prefix: \(settings.prefix)")
        updateInfoMenuItems()
    }

    /// Update informational menu items
    private func updateInfoMenuItems() {
        locationMenuItem.title = "Location: \(shortenPath(settings.location.path))"
        prefixMenuItem.title = "Prefix: \(settings.prefix)"

        // Update format
        let prefs = detector.detectPreferences()
        formatMenuItem.title = "Format: \(prefs.format.rawValue.uppercased())"

        // Update options summary
        var options: [String] = []
        options.append(prefs.showThumbnail ? "Thumb" : "No Thumb")
        options.append(prefs.includeCursor ? "Cursor" : "No Cursor")
        options.append(prefs.disableShadow ? "No Shadow" : "Shadow")
        options.append(prefs.includeDate ? "Date" : "No Date")
        if prefs.captureDelay > 0 {
            options.append("\(prefs.captureDelay)s Delay")
        }
        options.append(LaunchAtLoginManager.shared.isEnabled ? "Auto-start" : "No Auto-start")
        options.append(updateManager.automaticallyChecksForUpdates ? "Auto-update" : "No Auto-update")
        optionsMenuItem.title = options.joined(separator: " | ")

        // Update debug status
        debugMenuItem.title = "Debug: \(DebugLogger.shared.isEnabled ? "On" : "Off")"
    }

    /// Shorten path for display
    private func shortenPath(_ path: String, maxLength: Int = 40) -> String {
        guard path.count > maxLength else { return path }

        // Replace home directory with ~
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        var shortened = path.replacingOccurrences(of: homeDir, with: "~")

        // Still too long? Truncate middle
        if shortened.count > maxLength {
            let prefix = shortened.prefix(15)
            let suffix = shortened.suffix(20)
            shortened = "\(prefix)...\(suffix)"
        }

        return shortened
    }

    /// Auto-start watcher on launch
    private func autoStartWatcher() {
        do {
            try startWatcher()
            os_log("Auto-started watcher", log: .default, type: .info)
        } catch {
            os_log("Failed to auto-start watcher: %{public}@",
                   log: .default, type: .error, error.localizedDescription)
            Task { @MainActor in
                showAlert(
                    title: "Watcher Error",
                    message: "Failed to start watcher: \(error.localizedDescription)"
                )
            }
        }
    }

    /// Toggle watcher on/off
    @MainActor
    @objc private func toggleWatcher() {
        // Use watcher's actual running state instead of separate flag
        // This eliminates race condition between flag and actual state
        if let watcher = watcher, watcher.isRunning {
            stopWatcher()
            watcherMenuItem.title = "Start Watcher"
            watcherMenuItem.state = .off
            showNotification(
                title: "Watcher Stopped",
                message: "Screenshot watcher has been stopped"
            )
        } else {
            do {
                try startWatcher()
                watcherMenuItem.title = "Stop Watcher"
                watcherMenuItem.state = .on
                showNotification(
                    title: "Watcher Started",
                    message: "Watching: \(shortenPath(settings.location.path))"
                )
            } catch {
                Task { @MainActor in
                    showAlert(
                        title: "Error",
                        message: "Failed to start watcher: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    /// Start the file watcher
    private func startWatcher() throws {
        // Check watcher's actual state instead of separate flag
        guard watcher == nil || watcher?.isRunning == false else { return }

        watcher = ScreenshotWatcher(settings: settings)
        watcher?.startWatching()
        isWatcherRunning = watcher?.isRunning ?? false
    }

    /// Stop the file watcher
    private func stopWatcher() {
        // Check watcher's actual state instead of separate flag
        guard let watcher = watcher, watcher.isRunning else { return }

        watcher.stopWatching()
        self.watcher = nil
        isWatcherRunning = false
    }

    /// Quick rename existing screenshots
    @objc private func quickRename() {
        Task { @MainActor in
            do {
                let renamer = ScreenshotRenamer(
                    settings: settings,
                    whitelist: [settings.location]
                )

                let result = try await renamer.renameScreenshotsAsync()

                showAlert(
                    title: "Quick Rename Complete",
                    message: result.detailedSummary
                )
            } catch {
                showAlert(
                    title: "Quick Rename Failed",
                    message: error.localizedDescription
                )
            }
        }
    }

    /// Open settings window
    @MainActor
    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                detector: detector,
                updateManager: updateManager,
                onSettingsChanged: { [weak self] in
                    self?.reloadSettingsAfterChange()
                }
            )
        }
        settingsWindowController?.showWindow()
    }

    /// Reload settings after changes from settings window
    private func reloadSettingsAfterChange() {
        let wasRunning = watcher?.isRunning ?? false
        if wasRunning {
            stopWatcher()
        }
        loadSettings()
        SettingsSnapshot.save()
        if wasRunning {
            try? startWatcher()
        }
    }

    /// Quit the application
    @objc private func quit() {
        // Use watcher's actual state to avoid race condition
        if watcher?.isRunning == true {
            stopWatcher()
        }
        NSApplication.shared.terminate(self)
    }

    // MARK: - User Guide

    /// Open the user guide in the default browser
    @objc private func openUserGuide() {
        if let url = URL(string: "https://tpak.github.io/ScreenshotRenamer/") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - About

    /// Show the About dialog
    @MainActor
    @objc private func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        let alert = NSAlert()
        alert.messageText = "Screenshot Renamer"
        alert.informativeText = """
            Version \(version)

            Automatically renames screenshots from 12-hour to 24-hour format.

            © 2026 Chris Tirpak
            MIT License
            """
        alert.alertStyle = .informational

        // Set camera icon
        if let icon = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "Screenshot Renamer") {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
            if let configuredIcon = icon.withSymbolConfiguration(config) {
                alert.icon = configuredIcon
            }
        }

        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "GitHub")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/tpak/ScreenshotRenamer") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - User Notifications

    /// Request notification permissions
    private func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                os_log("Notification permission error: %{public}@",
                       log: .default, type: .debug, error.localizedDescription)
            }
        }
    }

    /// Show macOS notification using modern UserNotifications framework
    @MainActor
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = nil

        // Create request with unique identifier
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                os_log("Failed to show notification: %{public}@",
                       log: .default, type: .debug, error.localizedDescription)
            }
        }
    }

    /// Show alert dialog
    @MainActor
    private func showAlert(title: String, message: String) {
        // Activate app to bring alert to front
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
