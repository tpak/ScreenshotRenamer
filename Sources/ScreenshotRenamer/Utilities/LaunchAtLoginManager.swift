import Foundation
import ServiceManagement

/// Manages launch at login functionality for the app
/// Uses SMAppService for macOS 13+ with graceful fallback
final class LaunchAtLoginManager {
    // MARK: - Singleton

    static let shared = LaunchAtLoginManager()

    private init() {}

    // MARK: - Public Properties

    /// Whether the app is currently set to launch at login
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // For macOS 12, check legacy LaunchAgents
            return isEnabledLegacy()
        }
    }

    // MARK: - Public Methods

    /// Toggle launch at login on or off
    /// - Returns: Result indicating success or failure with error
    @discardableResult
    func toggle() -> Result<Bool, Error> {
        if #available(macOS 13.0, *) {
            return toggleModern()
        } else {
            return toggleLegacy()
        }
    }

    /// Enable launch at login
    /// - Returns: Result indicating success or failure with error
    @discardableResult
    func enable() -> Result<Void, Error> {
        if isEnabled {
            return .success(())
        }

        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                return .success(())
            } catch {
                return .failure(LaunchAtLoginError.registrationFailed(error))
            }
        } else {
            return enableLegacy()
        }
    }

    /// Disable launch at login
    /// - Returns: Result indicating success or failure with error
    @discardableResult
    func disable() -> Result<Void, Error> {
        if !isEnabled {
            return .success(())
        }

        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.unregister()
                return .success(())
            } catch {
                return .failure(LaunchAtLoginError.unregistrationFailed(error))
            }
        } else {
            return disableLegacy()
        }
    }

    // MARK: - Private Methods (macOS 13+)

    @available(macOS 13.0, *)
    private func toggleModern() -> Result<Bool, Error> {
        let service = SMAppService.mainApp

        do {
            switch service.status {
            case .enabled:
                try service.unregister()
                return .success(false)
            case .notRegistered, .notFound:
                try service.register()
                return .success(true)
            case .requiresApproval:
                // User needs to approve in System Settings
                return .failure(LaunchAtLoginError.requiresApproval)
            @unknown default:
                return .failure(LaunchAtLoginError.unknownStatus)
            }
        } catch {
            return .failure(LaunchAtLoginError.toggleFailed(error))
        }
    }

    // MARK: - Private Methods (macOS 12 Legacy)

    private func isEnabledLegacy() -> Bool {
        let launchAgentPath = getLaunchAgentPath()
        return FileManager.default.fileExists(atPath: launchAgentPath)
    }

    private func enableLegacy() -> Result<Void, Error> {
        let launchAgentPath = getLaunchAgentPath()
        let plistContent = createLaunchAgentPlist()

        do {
            // Create LaunchAgents directory if needed
            let launchAgentsDir = (launchAgentPath as NSString).deletingLastPathComponent
            if !FileManager.default.fileExists(atPath: launchAgentsDir) {
                try FileManager.default.createDirectory(
                    atPath: launchAgentsDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            // Write plist file
            try plistContent.write(toFile: launchAgentPath, atomically: true, encoding: .utf8)

            // Load with launchctl
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["load", launchAgentPath]
            try task.run()
            task.waitUntilExit()

            // Verify launchctl succeeded
            guard task.terminationStatus == 0 else {
                let error = NSError(
                    domain: "LaunchCtl",
                    code: Int(task.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "launchctl load failed with status \(task.terminationStatus)"]
                )
                return .failure(LaunchAtLoginError.legacyEnableFailed(error))
            }

            return .success(())
        } catch {
            return .failure(LaunchAtLoginError.legacyEnableFailed(error))
        }
    }

    private func disableLegacy() -> Result<Void, Error> {
        let launchAgentPath = getLaunchAgentPath()

        do {
            // Unload with launchctl
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["unload", launchAgentPath]
            try task.run()
            task.waitUntilExit()

            // Verify launchctl succeeded
            guard task.terminationStatus == 0 else {
                let error = NSError(
                    domain: "LaunchCtl",
                    code: Int(task.terminationStatus),
                    userInfo: [
                        NSLocalizedDescriptionKey: "launchctl unload failed with status \(task.terminationStatus)"
                    ]
                )
                return .failure(LaunchAtLoginError.legacyDisableFailed(error))
            }

            // Remove plist file
            try FileManager.default.removeItem(atPath: launchAgentPath)

            return .success(())
        } catch {
            return .failure(LaunchAtLoginError.legacyDisableFailed(error))
        }
    }

    private func toggleLegacy() -> Result<Bool, Error> {
        if isEnabledLegacy() {
            return disableLegacy().map { false }
        } else {
            return enableLegacy().map { true }
        }
    }

    private func getLaunchAgentPath() -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDir)/Library/LaunchAgents/com.tirpak.screenshot-renamer.plist"
    }

    private func createLaunchAgentPlist() -> String {
        guard let bundlePath = Bundle.main.bundlePath as String? else {
            return ""
        }

        let executablePath = "\(bundlePath)/Contents/MacOS/ScreenshotRenamer"

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.tirpak.screenshot-renamer</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """
    }
}

// MARK: - Error Types

enum LaunchAtLoginError: LocalizedError {
    case registrationFailed(Error)
    case unregistrationFailed(Error)
    case toggleFailed(Error)
    case requiresApproval
    case unknownStatus
    case legacyEnableFailed(Error)
    case legacyDisableFailed(Error)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let error):
            return "Failed to enable launch at login: \(error.localizedDescription)"
        case .unregistrationFailed(let error):
            return "Failed to disable launch at login: \(error.localizedDescription)"
        case .toggleFailed(let error):
            return "Failed to toggle launch at login: \(error.localizedDescription)"
        case .requiresApproval:
            return "Launch at login requires approval in System Settings > General > Login Items"
        case .unknownStatus:
            return "Unknown launch at login status"
        case .legacyEnableFailed(let error):
            return "Failed to enable launch at login (legacy): \(error.localizedDescription)"
        case .legacyDisableFailed(let error):
            return "Failed to disable launch at login (legacy): \(error.localizedDescription)"
        }
    }
}
