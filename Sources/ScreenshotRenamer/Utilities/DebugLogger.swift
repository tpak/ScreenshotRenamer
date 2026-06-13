//
//  DebugLogger.swift
//  ScreenshotRenamer
//
//  Debug logging utility for diagnostics
//

import Foundation

/// Singleton debug logger that writes timestamped entries to a log file
class DebugLogger {
    static let shared = DebugLogger()
    static let maxFileSizeBytes: UInt64 = 1_048_576

    private let queue = DispatchQueue(label: "com.screenshot-renamer.debug-logger", qos: .utility)
    private let formatter = ISO8601DateFormatter()

    private static let enabledKey = "DebugLoggingEnabled"
    private static let logFileURLKey = "DebugLogFileURL"

    /// Whether debug logging is enabled. No-ops when disabled.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    /// Custom log file location. Falls back to default if not set.
    var logFileURL: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: Self.logFileURLKey) {
                return URL(fileURLWithPath: path)
            }
            return Self.defaultLogFileURL
        }
        set {
            UserDefaults.standard.set(newValue.path, forKey: Self.logFileURLKey)
        }
    }

    /// Default log location: ~/Library/Logs/ScreenshotRenamer/screenshotrenamer-debug.log
    static var defaultLogFileURL: URL {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/ScreenshotRenamer")
        return logsDir.appendingPathComponent("screenshotrenamer-debug.log")
    }

    static func archivedLogFileURL(for url: URL) -> URL {
        url.appendingPathExtension("1")
    }

    private init() {}

    /// Log a message with a category tag
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: Category tag (e.g. "PatternMatcher", "Renamer")
    func log(_ message: String, category: String) {
        guard isEnabled else { return }

        let timestamp = formatter.string(from: Date())
        let entry = "[\(timestamp)] [\(category)] \(message)\n"
        let entryData = Data(entry.utf8)

        queue.async { [weak self] in
            guard let self = self else { return }
            let url = self.logFileURL

            // Ensure parent directory exists
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.rotateLogIfNeeded(at: url, incomingBytes: UInt64(entryData.count))

            if FileManager.default.fileExists(atPath: url.path) {
                // Append to existing file
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(entryData)
                    handle.closeFile()
                }
            } else {
                // Create new file
                try? entryData.write(to: url)
            }
        }
    }

    /// Remove the log file
    func clear() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.logFileURL)
            try? FileManager.default.removeItem(at: Self.archivedLogFileURL(for: self.logFileURL))
        }
    }

    /// Flush pending writes (blocks until queue drains). Useful for tests.
    func flush() {
        queue.sync {}
    }

    private func rotateLogIfNeeded(at url: URL, incomingBytes: UInt64) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let currentSize = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
        guard currentSize + incomingBytes > Self.maxFileSizeBytes else { return }

        let archivedURL = Self.archivedLogFileURL(for: url)
        try? FileManager.default.removeItem(at: archivedURL)
        try? FileManager.default.moveItem(at: url, to: archivedURL)
    }
}
