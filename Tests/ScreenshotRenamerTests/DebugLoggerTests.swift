//
//  DebugLoggerTests.swift
//  ScreenshotRenamerTests
//
//  Unit tests for DebugLogger
//

import XCTest
@testable import ScreenshotRenamer

class DebugLoggerTests: XCTestCase {
    var testLogURL: URL!
    private var savedEnabled: Bool!
    private var savedLogPath: String?

    override func setUp() {
        super.setUp()
        // Save original state
        savedEnabled = UserDefaults.standard.bool(forKey: "DebugLoggingEnabled")
        savedLogPath = UserDefaults.standard.string(forKey: "DebugLogFileURL")

        // Set up test log file
        testLogURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("debug-logger-test-\(UUID().uuidString)")
            .appendingPathComponent("screenshotrenamer-debug.log")

        DebugLogger.shared.logFileURL = testLogURL
        DebugLogger.shared.isEnabled = false
    }

    override func tearDown() {
        // Clean up test log directory
        let dir = testLogURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dir)

        // Restore original state
        UserDefaults.standard.set(savedEnabled, forKey: "DebugLoggingEnabled")
        if let path = savedLogPath {
            UserDefaults.standard.set(path, forKey: "DebugLogFileURL")
        } else {
            UserDefaults.standard.removeObject(forKey: "DebugLogFileURL")
        }

        super.tearDown()
    }

    func testLogFileCreatedWhenEnabled() {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.log("test message", category: "Test")
        DebugLogger.shared.flush()

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: testLogURL.path),
            "Log file should be created when logging is enabled"
        )
    }

    func testNoLogWhenDisabled() {
        DebugLogger.shared.isEnabled = false
        DebugLogger.shared.log("should not appear", category: "Test")
        DebugLogger.shared.flush()

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: testLogURL.path),
            "Log file should not be created when logging is disabled"
        )
    }

    func testLogEntryFormat() throws {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.log("hello world", category: "MyCategory")
        DebugLogger.shared.flush()

        let contents = try String(contentsOf: testLogURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("[MyCategory]"), "Log entry should contain category")
        XCTAssertTrue(contents.contains("hello world"), "Log entry should contain message")
        // ISO8601 timestamps contain "T" between date and time
        XCTAssertTrue(contents.contains("T"), "Log entry should contain ISO8601 timestamp")
    }

    func testCustomLogLocation() throws {
        let customURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("custom-log-test-\(UUID().uuidString)")
            .appendingPathComponent("custom.log")

        DebugLogger.shared.logFileURL = customURL
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.log("custom location test", category: "Test")
        DebugLogger.shared.flush()

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: customURL.path),
            "Log should be written to custom location"
        )

        // Clean up
        try? FileManager.default.removeItem(at: customURL.deletingLastPathComponent())

        // Restore test URL
        DebugLogger.shared.logFileURL = testLogURL
    }

    func testClear() {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.log("to be cleared", category: "Test")
        DebugLogger.shared.flush()

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: testLogURL.path),
            "Log file should exist before clear"
        )

        DebugLogger.shared.clear()
        DebugLogger.shared.flush()

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: testLogURL.path),
            "Log file should be removed after clear"
        )
    }

    func testLogRotationArchivesPreviousLog() throws {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.log(largeLogMessage(), category: "Test")
        DebugLogger.shared.flush()
        DebugLogger.shared.log("rotated entry", category: "Test")
        DebugLogger.shared.flush()

        let archivedURL = DebugLogger.archivedLogFileURL(for: testLogURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archivedURL.path))

        let currentContents = try String(contentsOf: testLogURL, encoding: .utf8)
        let archivedContents = try String(contentsOf: archivedURL, encoding: .utf8)
        XCTAssertTrue(currentContents.contains("rotated entry"))
        XCTAssertFalse(currentContents.contains(largeLogMarker()))
        XCTAssertTrue(archivedContents.contains(largeLogMarker()))
    }

    func testClearRemovesArchivedLog() {
        DebugLogger.shared.isEnabled = true
        DebugLogger.shared.log(largeLogMessage(), category: "Test")
        DebugLogger.shared.flush()
        DebugLogger.shared.log("rotated entry", category: "Test")
        DebugLogger.shared.flush()

        let archivedURL = DebugLogger.archivedLogFileURL(for: testLogURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archivedURL.path))

        DebugLogger.shared.clear()
        DebugLogger.shared.flush()

        XCTAssertFalse(FileManager.default.fileExists(atPath: archivedURL.path))
    }

    private func largeLogMessage() -> String {
        let repetitions = Int(DebugLogger.maxFileSizeBytes) / largeLogMarker().count + 1
        return String(repeating: largeLogMarker(), count: repetitions)
    }

    private func largeLogMarker() -> String {
        "LARGE_LOG_MARKER"
    }
}
