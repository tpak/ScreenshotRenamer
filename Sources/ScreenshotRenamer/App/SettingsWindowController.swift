//
//  SettingsWindowController.swift
//  ScreenshotRenamer
//
//  Settings dialog combining location, screenshot preferences, and debug options
//

import Cocoa
import UniformTypeIdentifiers

// swiftlint:disable type_body_length function_body_length file_length

class SettingsWindowController: NSWindowController, NSTextFieldDelegate, NSWindowDelegate {
    private let detector: ScreenshotDetector
    private let updateManager: UpdateManager
    private var onSettingsChanged: (() -> Void)?

    // UI Elements
    private var locationField: NSTextField!
    private var prefixField: NSTextField!
    private var showThumbnailCheckbox: NSButton!
    private var includeCursorCheckbox: NSButton!
    private var disableShadowCheckbox: NSButton!
    private var includeDateCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var formatPopup: NSPopUpButton!
    private var captureDelayPopup: NSPopUpButton!
    private var autoCheckUpdatesCheckbox: NSButton!
    private var updateFrequencyPopup: NSPopUpButton!
    private var autoDownloadUpdatesCheckbox: NSButton!
    private var runInBackgroundCheckbox: NSButton!
    private var quitButton: NSButton!

    /// Set while this window forced the app out of `.accessory` so it could come
    /// to the front — cleared (and the policy restored) when the window closes.
    private var didElevateActivationPolicy = false

    // Debug UI Elements
    private var debugEnableCheckbox: NSButton!
    private var debugLogPathLabel: NSTextField!

    init(detector: ScreenshotDetector, updateManager: UpdateManager, onSettingsChanged: (() -> Void)? = nil) {
        self.detector = detector
        self.updateManager = updateManager
        self.onSettingsChanged = onSettingsChanged

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 672),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false

        super.init(window: window)

        window.delegate = self
        setupUI()
        loadCurrentSettings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        let margin: CGFloat = 20
        let labelWidth: CGFloat = 100
        let controlX: CGFloat = margin + labelWidth + 10
        var currentY: CGFloat = contentView.bounds.height - 40

        // ============================================================
        // Screenshot Options
        // ============================================================
        let screenshotLabel = createSectionLabel("Screenshot Options:", x: margin, y: currentY)
        contentView.addSubview(screenshotLabel)

        currentY -= 25

        // Save Location
        let locationLabel = createLabel("Save Location:", x: margin, y: currentY)
        contentView.addSubview(locationLabel)

        currentY -= 25

        locationField = NSTextField(frame: NSRect(x: margin, y: currentY, width: 510, height: 22))
        locationField.isEditable = true
        locationField.isSelectable = true
        locationField.backgroundColor = .textBackgroundColor
        locationField.delegate = self
        locationField.placeholderString = "Enter path or use Choose..."
        contentView.addSubview(locationField)

        currentY -= 30

        let chooseButton = NSButton(
            frame: NSRect(x: 510 - 80 + margin, y: currentY, width: 80, height: 24)
        )
        chooseButton.title = "Choose..."
        chooseButton.bezelStyle = .rounded
        chooseButton.target = self
        chooseButton.action = #selector(chooseLocation)
        contentView.addSubview(chooseButton)

        currentY -= 30

        // Prefix
        let prefixLabel = createLabel("Prefix:", x: margin, y: currentY)
        contentView.addSubview(prefixLabel)

        prefixField = NSTextField(frame: NSRect(x: controlX, y: currentY, width: 200, height: 22))
        prefixField.isEditable = true
        prefixField.isSelectable = true
        prefixField.backgroundColor = .textBackgroundColor
        prefixField.delegate = self
        prefixField.placeholderString = "Screenshot"
        contentView.addSubview(prefixField)

        currentY -= 25

        // Checkboxes
        showThumbnailCheckbox = createCheckbox(
            "Show thumbnail preview after capture",
            x: controlX,
            y: currentY,
            action: #selector(toggleShowThumbnail)
        )
        contentView.addSubview(showThumbnailCheckbox)

        currentY -= 22

        includeCursorCheckbox = createCheckbox(
            "Include mouse pointer in screenshots",
            x: controlX,
            y: currentY,
            action: #selector(toggleIncludeCursor)
        )
        contentView.addSubview(includeCursorCheckbox)

        currentY -= 22

        disableShadowCheckbox = createCheckbox(
            "Disable window shadow",
            x: controlX,
            y: currentY,
            action: #selector(toggleDisableShadow)
        )
        contentView.addSubview(disableShadowCheckbox)

        currentY -= 22

        includeDateCheckbox = createCheckbox(
            "Include date in filename",
            x: controlX,
            y: currentY,
            action: #selector(toggleIncludeDate)
        )
        contentView.addSubview(includeDateCheckbox)

        currentY -= 25

        // Format
        let formatLabel = createLabel("Format:", x: margin, y: currentY)
        contentView.addSubview(formatLabel)

        formatPopup = NSPopUpButton(frame: NSRect(x: controlX, y: currentY - 2, width: 100, height: 25))
        formatPopup.addItems(withTitles: ["PNG", "JPG", "PDF", "TIFF"])
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)
        contentView.addSubview(formatPopup)

        currentY -= 30

        // Capture Delay
        let delayLabel = createLabel("Capture Delay:", x: margin, y: currentY)
        contentView.addSubview(delayLabel)

        captureDelayPopup = NSPopUpButton(frame: NSRect(x: controlX, y: currentY - 2, width: 120, height: 25))
        captureDelayPopup.addItems(withTitles: ["None", "5 Seconds", "10 Seconds"])
        captureDelayPopup.target = self
        captureDelayPopup.action = #selector(captureDelayChanged)
        contentView.addSubview(captureDelayPopup)

        currentY -= 30

        // ============================================================
        // App Options
        // ============================================================
        let separator1 = NSBox(frame: NSRect(x: margin, y: currentY, width: 510, height: 1))
        separator1.boxType = .separator
        contentView.addSubview(separator1)

        currentY -= 25

        let appLabel = createSectionLabel("App Options:", x: margin, y: currentY)
        contentView.addSubview(appLabel)

        currentY -= 25

        launchAtLoginCheckbox = createCheckbox(
            "Launch at login",
            x: controlX,
            y: currentY,
            action: #selector(toggleLaunchAtLogin)
        )
        contentView.addSubview(launchAtLoginCheckbox)

        currentY -= 22

        autoCheckUpdatesCheckbox = createCheckbox(
            "Automatically check for updates",
            x: controlX,
            y: currentY,
            action: #selector(toggleAutoCheckUpdates)
        )
        contentView.addSubview(autoCheckUpdatesCheckbox)

        currentY -= 25

        // Update frequency + Check Now
        let frequencyLabel = createLabel("Check:", x: margin, y: currentY)
        contentView.addSubview(frequencyLabel)

        updateFrequencyPopup = NSPopUpButton(frame: NSRect(x: controlX, y: currentY - 2, width: 100, height: 25))
        for freq in UpdateManager.CheckFrequency.allCases {
            updateFrequencyPopup.addItem(withTitle: freq.title)
        }
        updateFrequencyPopup.target = self
        updateFrequencyPopup.action = #selector(updateFrequencyChanged)
        contentView.addSubview(updateFrequencyPopup)

        let checkNowButton = NSButton(title: "Check Now", target: self, action: #selector(checkForUpdatesNow))
        checkNowButton.bezelStyle = .rounded
        checkNowButton.frame = NSRect(x: controlX + 110, y: currentY - 2, width: 90, height: 25)
        contentView.addSubview(checkNowButton)

        currentY -= 27

        autoDownloadUpdatesCheckbox = createCheckbox(
            "Automatically download and install updates",
            x: controlX,
            y: currentY,
            action: #selector(toggleAutoDownloadUpdates)
        )
        contentView.addSubview(autoDownloadUpdatesCheckbox)

        currentY -= 22

        runInBackgroundCheckbox = createCheckbox(
            "Run in background (hide menu bar icon)",
            x: controlX,
            y: currentY,
            action: #selector(toggleRunInBackground)
        )
        runInBackgroundCheckbox.toolTip =
            "Keeps renaming screenshots with no menu bar icon. "
            + "Launch Screenshot Renamer again to reopen this window."
        contentView.addSubview(runInBackgroundCheckbox)

        currentY -= 30

        // ============================================================
        // Debug
        // ============================================================
        let separator2 = NSBox(frame: NSRect(x: margin, y: currentY, width: 510, height: 1))
        separator2.boxType = .separator
        contentView.addSubview(separator2)

        currentY -= 25

        let debugLabel = createSectionLabel("Debug:", x: margin, y: currentY)
        contentView.addSubview(debugLabel)

        currentY -= 25

        debugEnableCheckbox = createCheckbox(
            "Enable debug logging",
            x: controlX,
            y: currentY,
            action: #selector(toggleDebugLogging)
        )
        contentView.addSubview(debugEnableCheckbox)

        currentY -= 22

        let logLabel = createLabel("Log:", x: margin, y: currentY)
        contentView.addSubview(logLabel)

        debugLogPathLabel = NSTextField(frame: NSRect(x: controlX, y: currentY, width: 320, height: 17))
        debugLogPathLabel.stringValue = shortenPath(DebugLogger.shared.logFileURL.path)
        debugLogPathLabel.toolTip = DebugLogger.shared.logFileURL.path
        debugLogPathLabel.isEditable = false
        debugLogPathLabel.isSelectable = true
        debugLogPathLabel.isBordered = false
        debugLogPathLabel.backgroundColor = .clear
        debugLogPathLabel.textColor = .secondaryLabelColor
        debugLogPathLabel.font = NSFont.systemFont(ofSize: 11)
        contentView.addSubview(debugLogPathLabel)

        currentY -= 28

        let debugButtonY = currentY
        let debugButtonWidth: CGFloat = 100

        let setLocationButton = NSButton(
            frame: NSRect(x: controlX, y: debugButtonY, width: debugButtonWidth, height: 24)
        )
        setLocationButton.title = "Set Location..."
        setLocationButton.bezelStyle = .rounded
        setLocationButton.target = self
        setLocationButton.action = #selector(setDebugLogLocation)
        contentView.addSubview(setLocationButton)

        let openButton = NSButton(
            frame: NSRect(x: controlX + debugButtonWidth + 8, y: debugButtonY, width: 60, height: 24)
        )
        openButton.title = "Open"
        openButton.bezelStyle = .rounded
        openButton.target = self
        openButton.action = #selector(openDebugLog)
        contentView.addSubview(openButton)

        let clearButton = NSButton(
            frame: NSRect(x: controlX + debugButtonWidth + 8 + 68, y: debugButtonY, width: 60, height: 24)
        )
        clearButton.title = "Clear"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearDebugLog)
        contentView.addSubview(clearButton)

        // ============================================================
        // Bottom Buttons
        // ============================================================
        currentY -= 15

        let separator3 = NSBox(frame: NSRect(x: margin, y: currentY, width: 510, height: 1))
        separator3.boxType = .separator
        contentView.addSubview(separator3)

        currentY -= 38

        let resetButton = NSButton(frame: NSRect(x: margin, y: currentY, width: 120, height: 28))
        resetButton.title = "Reset to Defaults"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefaults)
        contentView.addSubview(resetButton)

        // Only affordance to quit once the menu bar icon is hidden, so it is
        // shown exactly when background mode is on (see loadCurrentSettings).
        quitButton = NSButton(frame: NSRect(x: margin + 130, y: currentY, width: 90, height: 28))
        quitButton.title = "Quit App"
        quitButton.bezelStyle = .rounded
        quitButton.target = self
        quitButton.action = #selector(quitApp)
        contentView.addSubview(quitButton)

        let closeButton = NSButton(frame: NSRect(x: 450, y: currentY, width: 80, height: 28))
        closeButton.title = "Close"
        closeButton.bezelStyle = .rounded
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        closeButton.keyEquivalent = "\r"
        contentView.addSubview(closeButton)
    }

    private func createLabel(_ text: String, x: CGFloat, y: CGFloat) -> NSTextField {
        let label = NSTextField(frame: NSRect(x: x, y: y, width: 100, height: 17))
        label.stringValue = text
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.alignment = .right
        return label
    }

    private func createSectionLabel(_ text: String, x: CGFloat, y: CGFloat) -> NSTextField {
        let label = NSTextField(frame: NSRect(x: x, y: y, width: 100, height: 17))
        label.stringValue = text
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = NSFont.boldSystemFont(ofSize: 12)
        label.alignment = .left
        return label
    }

    private func createCheckbox(_ title: String, x: CGFloat, y: CGFloat, action: Selector) -> NSButton {
        let checkbox = NSButton(frame: NSRect(x: x, y: y, width: 350, height: 18))
        checkbox.setButtonType(.switch)
        checkbox.title = title
        checkbox.target = self
        checkbox.action = action
        return checkbox
    }

    private func loadCurrentSettings() {
        let settings = detector.detectSettings()
        let prefs = detector.detectPreferences()

        locationField.stringValue = settings.location.path
        locationField.toolTip = settings.location.path
        prefixField.stringValue = settings.prefix

        showThumbnailCheckbox.state = prefs.showThumbnail ? .on : .off
        includeCursorCheckbox.state = prefs.includeCursor ? .on : .off
        disableShadowCheckbox.state = prefs.disableShadow ? .on : .off
        includeDateCheckbox.state = prefs.includeDate ? .on : .off
        launchAtLoginCheckbox.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        autoCheckUpdatesCheckbox.state = updateManager.automaticallyChecksForUpdates ? .on : .off
        let currentFrequency = UpdateManager.CheckFrequency.from(interval: updateManager.updateCheckInterval)
        updateFrequencyPopup.selectItem(withTitle: currentFrequency.title)
        updateFrequencyPopup.isEnabled = updateManager.automaticallyChecksForUpdates
        autoDownloadUpdatesCheckbox.state = updateManager.automaticallyDownloadsUpdates ? .on : .off

        let backgroundMode = BackgroundModeManager.shared.isEnabled
        runInBackgroundCheckbox.state = backgroundMode ? .on : .off
        quitButton.isHidden = !backgroundMode

        switch prefs.format {
        case .png: formatPopup.selectItem(withTitle: "PNG")
        case .jpg: formatPopup.selectItem(withTitle: "JPG")
        case .pdf: formatPopup.selectItem(withTitle: "PDF")
        case .tiff: formatPopup.selectItem(withTitle: "TIFF")
        }

        switch prefs.captureDelay {
        case 5: captureDelayPopup.selectItem(withTitle: "5 Seconds")
        case 10: captureDelayPopup.selectItem(withTitle: "10 Seconds")
        default: captureDelayPopup.selectItem(withTitle: "None")
        }

        // Debug settings
        debugEnableCheckbox.state = DebugLogger.shared.isEnabled ? .on : .off
        debugLogPathLabel.stringValue = shortenPath(DebugLogger.shared.logFileURL.path)
        debugLogPathLabel.toolTip = DebugLogger.shared.logFileURL.path
    }

    private func shortenPath(_ path: String) -> String {
        PathFormatter.abbreviatingHome(path)
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }

        if textField === locationField {
            handleLocationFieldEditing()
        } else if textField === prefixField {
            handlePrefixFieldEditing()
        }
    }

    private func handleLocationFieldEditing() {
        let path = locationField.stringValue
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        // Validate the path exists and is a directory
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)

        if !exists || !isDirectory.boolValue {
            showError("Invalid location: The path must be an existing directory.")
            loadCurrentSettings() // Revert to current setting
            return
        }

        // Apply the new location
        guard detector.setSystemLocation(url) else {
            showError("Failed to change screenshot location.")
            loadCurrentSettings()
            return
        }

        restartSystemUIServer()
        locationField.toolTip = expandedPath
        onSettingsChanged?()
    }

    private func handlePrefixFieldEditing() {
        let trimmed = prefixField.stringValue.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            showError("Prefix cannot be empty.")
            loadCurrentSettings()
            return
        }

        guard detector.setPrefix(trimmed) else {
            showError("Failed to change screenshot prefix.")
            loadCurrentSettings()
            return
        }

        prefixField.stringValue = trimmed
        restartSystemUIServer()
        onSettingsChanged?()
    }

    // MARK: - Actions

    @objc
    private func chooseLocation() {
        let panel = NSOpenPanel()
        panel.title = "Choose Screenshot Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        let currentSettings = detector.detectSettings()
        panel.directoryURL = currentSettings.location

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        guard detector.setSystemLocation(selectedURL) else {
            showError("Failed to change screenshot location.")
            return
        }

        restartSystemUIServer()
        locationField.stringValue = selectedURL.path
        locationField.toolTip = selectedURL.path
        onSettingsChanged?()
    }

    @objc
    private func toggleShowThumbnail() {
        let newValue = showThumbnailCheckbox.state == .on
        guard detector.setShowThumbnail(newValue) else {
            showThumbnailCheckbox.state = newValue ? .off : .on
            showError("Failed to change thumbnail setting.")
            return
        }
        // No SystemUIServer restart needed — screencaptureui reads this
        // preference fresh on each launch (macOS 14+)
        onSettingsChanged?()
    }

    @objc
    private func toggleIncludeCursor() {
        let newValue = includeCursorCheckbox.state == .on
        guard detector.setIncludeCursor(newValue) else {
            includeCursorCheckbox.state = newValue ? .off : .on
            showError("Failed to change cursor setting.")
            return
        }
        onSettingsChanged?()
    }

    @objc
    private func toggleDisableShadow() {
        let newValue = disableShadowCheckbox.state == .on
        guard detector.setDisableShadow(newValue) else {
            disableShadowCheckbox.state = newValue ? .off : .on
            showError("Failed to change shadow setting.")
            return
        }
        onSettingsChanged?()
    }

    @objc
    private func toggleIncludeDate() {
        let newValue = includeDateCheckbox.state == .on
        guard detector.setIncludeDate(newValue) else {
            includeDateCheckbox.state = newValue ? .off : .on
            showError("Failed to change date setting.")
            return
        }
        onSettingsChanged?()
    }

    @objc
    private func toggleLaunchAtLogin() {
        let result = LaunchAtLoginManager.shared.toggle()
        switch result {
        case .success(let isEnabled):
            launchAtLoginCheckbox.state = isEnabled ? .on : .off
        case .failure(let error):
            let currentState = LaunchAtLoginManager.shared.isEnabled
            launchAtLoginCheckbox.state = currentState ? .on : .off
            showError(error.localizedDescription)
        }
        onSettingsChanged?()
    }

    @objc
    private func toggleAutoCheckUpdates() {
        let enabled = autoCheckUpdatesCheckbox.state == .on
        updateManager.automaticallyChecksForUpdates = enabled
        updateFrequencyPopup.isEnabled = enabled
        onSettingsChanged?()
    }

    @objc
    private func toggleAutoDownloadUpdates() {
        updateManager.automaticallyDownloadsUpdates = autoDownloadUpdatesCheckbox.state == .on
        onSettingsChanged?()
    }

    @objc
    private func toggleRunInBackground() {
        let enabled = runInBackgroundCheckbox.state == .on

        // Turning this on removes the app's only visible affordance, so make the
        // way back explicit before committing to it (issue #33).
        if enabled, !confirmBackgroundMode() {
            runInBackgroundCheckbox.state = .off
            return
        }

        BackgroundModeManager.shared.isEnabled = enabled
        quitButton.isHidden = !enabled
        DebugLogger.shared.log("Run in background set to \(enabled)", category: "App")
        onSettingsChanged?()
    }

    /// Explain the trade-off and confirm. Returns `true` if the user agreed.
    private func confirmBackgroundMode() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Hide the menu bar icon?"
        alert.informativeText = """
            Screenshot Renamer keeps running and renaming screenshots, but it \
            will have no menu bar icon.

            To open this window again, launch Screenshot Renamer from \
            Applications or Spotlight.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Hide Icon")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc
    private func checkForUpdatesNow() {
        NSApp.activate(ignoringOtherApps: true)
        updateManager.updaterController.checkForUpdates(nil)
    }

    @objc
    private func updateFrequencyChanged() {
        let index = updateFrequencyPopup.indexOfSelectedItem
        let allFrequencies = UpdateManager.CheckFrequency.allCases
        guard index >= 0, index < allFrequencies.count else { return }
        updateManager.updateCheckInterval = allFrequencies[index].rawValue
        onSettingsChanged?()
    }

    @objc
    private func formatChanged() {
        guard let title = formatPopup.selectedItem?.title else { return }

        let format: ScreenshotFormat
        switch title {
        case "PNG": format = .png
        case "JPG": format = .jpg
        case "PDF": format = .pdf
        case "TIFF": format = .tiff
        default: return
        }

        guard detector.setFormat(format) else {
            loadCurrentSettings()
            showError("Failed to change format.")
            return
        }
        restartSystemUIServer()
        onSettingsChanged?()
    }

    @objc
    private func captureDelayChanged() {
        let delay: Int
        switch captureDelayPopup.indexOfSelectedItem {
        case 1: delay = 5
        case 2: delay = 10
        default: delay = 0
        }
        guard detector.setCaptureDelay(delay) else {
            loadCurrentSettings()
            showError("Failed to change capture delay.")
            return
        }
        restartSystemUIServer()
        onSettingsChanged?()
    }

    // MARK: - Debug Actions

    @objc
    private func toggleDebugLogging() {
        DebugLogger.shared.isEnabled.toggle()
        debugEnableCheckbox.state = DebugLogger.shared.isEnabled ? .on : .off
        if DebugLogger.shared.isEnabled {
            DebugLogger.shared.log("Debug logging enabled", category: "App")
        }
        onSettingsChanged?()
    }

    @objc
    private func setDebugLogLocation() {
        let panel = NSSavePanel()
        panel.title = "Choose Debug Log Location"
        panel.nameFieldStringValue = "screenshotrenamer-debug.log"
        panel.allowedContentTypes = [.log, .plainText]
        panel.directoryURL = DebugLogger.shared.logFileURL.deletingLastPathComponent()

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            DebugLogger.shared.logFileURL = url
            debugLogPathLabel.stringValue = shortenPath(url.path)
            debugLogPathLabel.toolTip = url.path
        }
    }

    @objc
    private func openDebugLog() {
        let url = DebugLogger.shared.logFileURL
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            showError("No debug log file exists yet. Enable debug logging first.")
        }
    }

    @objc
    private func clearDebugLog() {
        DebugLogger.shared.clear()
    }

    @objc
    private func resetToDefaults() {
        let alert = NSAlert()
        alert.messageText = "Reset to Defaults?"
        alert.informativeText = "This will reset all screenshot settings to macOS defaults."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard detector.resetToDefaults() else {
            showError("Failed to reset settings.")
            return
        }

        restartSystemUIServer()
        loadCurrentSettings()
        onSettingsChanged?()
    }

    @objc
    private func closeWindow() {
        window?.close()
    }

    private func restartSystemUIServer() {
        _ = ShellExecutor.restartSystemUIServer()
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showWindow() {
        loadCurrentSettings()

        // Normally the user got here by clicking the menu bar icon, which already
        // made the app active. With the icon hidden there is no such click, and an
        // `.accessory` app cannot reliably pull a window in front of the active
        // app — so become a regular app for as long as this window is open.
        var justElevated = false
        if BackgroundModeManager.shared.isEnabled, !didElevateActivationPolicy {
            NSApp.setActivationPolicy(.regular)
            didElevateActivationPolicy = true
            justElevated = true
        }

        // A policy change only takes effect on the next pass of the run loop —
        // activating in the same turn leaves the window stranded behind whatever
        // app is frontmost.
        if justElevated {
            DispatchQueue.main.async { [weak self] in self?.bringWindowToFront() }
        } else {
            bringWindowToFront()
        }
    }

    private func bringWindowToFront() {
        // Opened without a click to activate us first, an accessory app's window
        // reliably lands *behind* the frontmost app even though AppKit reports it
        // key. Float it so it actually reaches the screen; the level is dropped
        // back to normal when the window closes.
        if didElevateActivationPolicy {
            window?.level = .floating
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()

        DebugLogger.shared.log(
            "Settings window shown (visible=\(window?.isVisible ?? false), "
            + "floating=\(didElevateActivationPolicy))",
            category: "App"
        )
    }

    /// Drop back to a dock-less accessory app once the window is dismissed.
    func windowWillClose(_ notification: Notification) {
        guard didElevateActivationPolicy else { return }
        didElevateActivationPolicy = false
        window?.level = .normal
        NSApp.setActivationPolicy(.accessory)
    }
}
