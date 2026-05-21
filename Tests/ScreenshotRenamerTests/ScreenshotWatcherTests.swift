//
//  ScreenshotWatcherTests.swift
//  ScreenshotRenamerTests
//
//  Integration tests for ScreenshotWatcher — exercise FSEvents, the
//  300ms debounce, and the end-to-end rename flow against a real
//  temp directory.
//

import XCTest
@testable import ScreenshotRenamer

class ScreenshotWatcherTests: XCTestCase {
    private var testDir: URL!
    private var watcher: ScreenshotWatcher!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("watcher-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let settings = ScreenshotSettings(location: testDir, prefix: "Screenshot")
        watcher = ScreenshotWatcher(settings: settings)
        watcher.startWatching()
    }

    override func tearDownWithError() throws {
        watcher?.stopWatching()
        watcher = nil
        if let dir = testDir {
            try? FileManager.default.removeItem(at: dir)
        }
        try super.tearDownWithError()
    }

    func testRenamesDetectedScreenshot() throws {
        let source = testDir.appendingPathComponent("Screenshot 2026-03-31 at 10.15.30 AM.png")
        let expected = testDir.appendingPathComponent("screenshot 2026-03-31 at 10.15.30.png")

        try "data".write(to: source, atomically: true, encoding: .utf8)

        expectFileExists(at: expected, timeout: 2.0)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: source.path),
            "Original 12-hour file should be gone"
        )
    }

    func testIgnoresNonScreenshotFiles() throws {
        let unrelated = testDir.appendingPathComponent("just-a-file.txt")
        try "data".write(to: unrelated, atomically: true, encoding: .utf8)

        // Wait well past the 300ms debounce, then assert nothing changed.
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        let contents = try FileManager.default.contentsOfDirectory(atPath: testDir.path)
        XCTAssertEqual(contents, ["just-a-file.txt"], "Non-screenshot file should not be touched")
    }

    func testDebouncesAndRenamesBurst() throws {
        for i in 0..<5 {
            let url = testDir.appendingPathComponent("Screenshot 2026-03-31 at 11.30.0\(i) AM.png")
            try "data\(i)".write(to: url, atomically: true, encoding: .utf8)
        }

        expectRenamedCount(5, timeout: 2.0)
    }

    // MARK: - Helpers

    private func expectFileExists(at url: URL, timeout: TimeInterval) {
        let predicate = NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: url.path)
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        wait(for: [expectation], timeout: timeout)
    }

    private func expectRenamedCount(_ count: Int, timeout: TimeInterval) {
        let dir = testDir!
        let predicate = NSPredicate { _, _ in
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path)
            else { return false }
            return files.filter { $0.hasPrefix("screenshot ") }.count == count
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        wait(for: [expectation], timeout: timeout)
    }
}
