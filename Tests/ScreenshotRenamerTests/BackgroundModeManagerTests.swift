//
//  BackgroundModeManagerTests.swift
//  ScreenshotRenamerTests
//
//  Unit tests for the "run in background" preference (issue #33)
//

import XCTest
@testable import ScreenshotRenamer

class BackgroundModeManagerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var manager: BackgroundModeManager!

    override func setUp() {
        super.setUp()
        suiteName = "BackgroundModeManagerTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        manager = BackgroundModeManager(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        manager = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsToVisibleMenuBarIcon() {
        // Existing users must not lose their menu bar icon on upgrade.
        XCTAssertFalse(manager.isEnabled)
    }

    func testEnablingPersists() {
        manager.isEnabled = true
        XCTAssertTrue(manager.isEnabled)

        // A fresh manager over the same store sees it — this is what a relaunch does.
        let reloaded = BackgroundModeManager(defaults: defaults)
        XCTAssertTrue(reloaded.isEnabled)
    }

    func testDisablingPersists() {
        manager.isEnabled = true
        manager.isEnabled = false
        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(BackgroundModeManager(defaults: defaults).isEnabled)
    }

    func testWritesToTheDocumentedKey() {
        manager.isEnabled = true
        XCTAssertTrue(defaults.bool(forKey: BackgroundModeManager.defaultsKey))
    }

    func testDefaultsKeyIsStable() {
        // Persisted contract: renaming it would silently un-hide the icon for
        // users who had chosen background mode.
        XCTAssertEqual(BackgroundModeManager.defaultsKey, "RunInBackground")
    }

    func testShowSettingsNotificationNameIsStable() {
        // Both processes involved in a relaunch must agree on this string, and
        // an older running instance may be the one listening.
        XCTAssertEqual(
            Notification.Name.screenshotRenamerShowSettings.rawValue,
            "com.tirpak.screenshot-renamer.showSettings"
        )
    }
}
