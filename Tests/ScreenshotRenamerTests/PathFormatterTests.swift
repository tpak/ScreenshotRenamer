//
//  PathFormatterTests.swift
//  ScreenshotRenamerTests
//
//  Unit tests for display formatting of file system paths
//

import XCTest
@testable import ScreenshotRenamer

class PathFormatterTests: XCTestCase {
    private let home = "/Users/testuser"

    // MARK: - abbreviatingHome

    func testAbbreviatingHomeReplacesHomeDirectory() {
        let result = PathFormatter.abbreviatingHome("/Users/testuser/Desktop", homeDirectory: home)
        XCTAssertEqual(result, "~/Desktop")
    }

    func testAbbreviatingHomeLeavesOtherPathsUntouched() {
        let result = PathFormatter.abbreviatingHome("/Volumes/External/Shots", homeDirectory: home)
        XCTAssertEqual(result, "/Volumes/External/Shots")
    }

    func testAbbreviatingHomeHandlesExactHomeDirectory() {
        XCTAssertEqual(PathFormatter.abbreviatingHome(home, homeDirectory: home), "~")
    }

    func testAbbreviatingHomeIgnoresEmptyHomeDirectory() {
        // A blank home must not turn every character boundary into a tilde.
        let path = "/Users/testuser/Desktop"
        XCTAssertEqual(PathFormatter.abbreviatingHome(path, homeDirectory: ""), path)
    }

    // MARK: - shortened: paths that fit

    func testShortPathReturnedUnchanged() {
        let path = "/tmp/shots"
        XCTAssertEqual(PathFormatter.shortened(path, homeDirectory: home), path)
    }

    func testPathWithinBudgetKeepsHomeDirectory() {
        // Long-standing menu bar behavior: paths already short enough are shown
        // verbatim, without tilde substitution.
        let path = "/Users/testuser/Desktop"
        XCTAssertLessThanOrEqual(path.count, PathFormatter.defaultMaxLength)
        XCTAssertEqual(PathFormatter.shortened(path, homeDirectory: home), path)
    }

    // MARK: - shortened: paths that need abbreviating

    func testTildeSubstitutionAloneCanBringPathWithinBudget() {
        let path = "/Users/testuser/Documents/Screenshots/2026"
        XCTAssertGreaterThan(path.count, PathFormatter.defaultMaxLength)

        let result = PathFormatter.shortened(path, homeDirectory: home)

        XCTAssertEqual(result, "~/Documents/Screenshots/2026")
        XCTAssertFalse(result.contains("..."), "No truncation needed once ~ is applied")
    }

    func testVeryLongPathIsElidedInTheMiddle() {
        let path = "/Users/testuser/Documents/Projects/Archive/Screenshots/Captured/2026/June"

        let result = PathFormatter.shortened(path, homeDirectory: home)

        XCTAssertTrue(result.contains("..."), "Expected middle elision, got \(result)")
        XCTAssertTrue(result.hasSuffix("June"), "Tail should survive so the leaf stays readable")
    }

    // MARK: - shortened: the maxLength contract

    func testResultNeverExceedsMaxLength() {
        let path = "/Users/testuser/Documents/Projects/Archive/Screenshots/Captured/2026/June"

        for maxLength in 4...80 {
            let result = PathFormatter.shortened(path, maxLength: maxLength, homeDirectory: home)
            XCTAssertLessThanOrEqual(
                result.count, maxLength,
                "maxLength \(maxLength) violated by \(result.count)-char result: \(result)"
            )
        }
    }

    func testTinyMaxLengthDegradesGracefully() {
        let path = "/Users/testuser/Documents/Screenshots/Captured"

        let result = PathFormatter.shortened(path, maxLength: 2, homeDirectory: home)

        XCTAssertEqual(result.count, 2)
    }

    func testElisionKeepsBothHeadAndTail() {
        let path = "/Users/testuser/Documents/Projects/Archive/Screenshots/Captured/2026/June"

        let result = PathFormatter.shortened(path, maxLength: 40, homeDirectory: home)

        let parts = result.components(separatedBy: "...")
        XCTAssertEqual(parts.count, 2)
        XCTAssertFalse(parts[0].isEmpty, "Head should be preserved")
        XCTAssertFalse(parts[1].isEmpty, "Tail should be preserved")
    }
}
