//
//  AppDelegate.swift
//  ScreenshotRenamer
//
//  Application delegate
//

import Cocoa
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if another instance is already running
        let bundleID = Bundle.main.bundleIdentifier ?? "com.tirpak.screenshot-renamer"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if runningApps.count > 1 {
            print("⚠️ Another instance is already running. Exiting.")
            os_log("Another instance already running, terminating", log: .default, type: .info)
            // Re-launching is the way back in when the menu bar icon is hidden
            // (issue #33) — ask the live instance to show Settings before we go.
            DebugLogger.shared.log(
                "Second instance detected; asking running instance to show Settings",
                category: "App"
            )
            DistributedNotificationCenter.default().postNotificationName(
                .screenshotRenamerShowSettings,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            NSApp.terminate(nil)
            return
        }

        print("🚀 Screenshot Renamer starting...")
        os_log("Screenshot Renamer starting", log: .default, type: .info)
        let debugStatus = DebugLogger.shared.isEnabled ? "enabled" : "disabled"
        DebugLogger.shared.log("App launching, debug logging \(debugStatus)", category: "App")

        // Initialize menu bar BEFORE setting activation policy
        menuBarController = MenuBarController()
        print("✅ Menu bar controller created")

        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)
        print("✅ Set activation policy to accessory")

        DebugLogger.shared.log("App started", category: "App")
        os_log("Screenshot Renamer started", log: .default, type: .info)
        print("✅ Screenshot Renamer fully initialized")
    }

    func applicationWillTerminate(_ notification: Notification) {
        DebugLogger.shared.log("App shutting down", category: "App")
        os_log("Screenshot Renamer stopping", log: .default, type: .info)
    }

    /// Keep app running when all windows closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Launch Services may activate this instance instead of starting a second
    /// process. Treat that like the second-instance path: surface Settings, which
    /// is the only reachable UI when running in background mode (issue #33).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        DebugLogger.shared.log("Reopen requested (hasVisibleWindows=\(flag)), showing Settings", category: "App")
        menuBarController?.showSettingsWindow()
        return true
    }
}
