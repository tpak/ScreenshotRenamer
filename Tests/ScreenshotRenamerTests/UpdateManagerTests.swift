//
//  UpdateManagerTests.swift
//  ScreenshotRenamerTests
//
//  Unit tests for the auto-update migration policy (issue #42)
//

import XCTest
@testable import ScreenshotRenamer

class UpdateManagerTests: XCTestCase {
    // MARK: - AutoUpdateMigration.shouldEnableChecks

    func testForceEnablesWhenNotMigratedAndCurrentlyOff() {
        // The bug case: a fresh-from-old-build user whose checks are off and
        // who has never run the migration should get checks turned on.
        XCTAssertTrue(
            AutoUpdateMigration.shouldEnableChecks(migrationApplied: false, currentlyEnabled: false)
        )
    }

    func testDoesNotTouchWhenAlreadyEnabled() {
        // Already checking — nothing to fix, don't write anything.
        XCTAssertFalse(
            AutoUpdateMigration.shouldEnableChecks(migrationApplied: false, currentlyEnabled: true)
        )
    }

    func testRespectsUserWhoDisabledAfterMigration() {
        // Once the migration has run, a user who deliberately turns checks off
        // must be respected — we never force-enable a second time.
        XCTAssertFalse(
            AutoUpdateMigration.shouldEnableChecks(migrationApplied: true, currentlyEnabled: false)
        )
    }

    func testNoOpWhenMigratedAndEnabled() {
        XCTAssertFalse(
            AutoUpdateMigration.shouldEnableChecks(migrationApplied: true, currentlyEnabled: true)
        )
    }

    func testMigrationKeyIsStable() {
        // The key is a persisted contract; changing it would re-run the
        // migration for everyone and re-enable checks they may have disabled.
        XCTAssertEqual(AutoUpdateMigration.defaultsKey, "AutoCheckMigrationApplied")
    }
}
