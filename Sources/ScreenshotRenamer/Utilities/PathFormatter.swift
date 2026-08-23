//
//  PathFormatter.swift
//  ScreenshotRenamer
//
//  Shared formatting for file paths shown in the UI
//

import Foundation

/// Formats file system paths for display in the menu bar and Settings window.
///
/// Both call sites abbreviate the user's home directory to `~`; the menu bar
/// additionally truncates so long paths don't stretch the menu. The home
/// directory is injectable so tests don't depend on the machine they run on.
enum PathFormatter {
    /// Default budget for `shortened(_:maxLength:homeDirectory:)`.
    static let defaultMaxLength = 40

    private static var currentHome: String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// Replaces a leading home directory with `~`.
    static func abbreviatingHome(_ path: String, homeDirectory: String? = nil) -> String {
        let home = homeDirectory ?? currentHome
        guard !home.isEmpty else { return path }
        return path.replacingOccurrences(of: home, with: "~")
    }

    /// Abbreviates the home directory and, if the path is still too long,
    /// elides the middle so the result fits within `maxLength`.
    ///
    /// Paths already within `maxLength` are returned unchanged — including
    /// their home directory, matching the menu bar's long-standing behavior.
    static func shortened(_ path: String,
                          maxLength: Int = defaultMaxLength,
                          homeDirectory: String? = nil) -> String {
        guard path.count > maxLength else { return path }

        let shortened = abbreviatingHome(path, homeDirectory: homeDirectory)
        guard shortened.count > maxLength else { return shortened }

        return elidingMiddle(shortened, maxLength: maxLength)
    }

    /// Keeps the head and tail of `text`, replacing the middle with `...`.
    private static func elidingMiddle(_ text: String, maxLength: Int) -> String {
        let ellipsis = "..."
        guard maxLength > ellipsis.count else { return String(text.prefix(maxLength)) }

        // Budget the remaining characters roughly 3:4 between head and tail, so
        // the filename at the end stays readable. Never exceeds maxLength.
        let budget = maxLength - ellipsis.count
        let head = max(1, budget * 3 / 7)
        let tail = budget - head

        return "\(text.prefix(head))\(ellipsis)\(text.suffix(tail))"
    }
}
