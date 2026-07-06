#if os(macOS)
import AppKit
import ApplicationServices
import IOKit.hid
import SmartKeyboardCore

@main
enum SmartKeyboardAppMain {
    @MainActor
    private static let delegate = SmartKeyboardAppDelegate()

    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}

@MainActor
private final class SmartKeyboardAppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusIcon = SmartKeyboardAppDelegate.makeStatusIcon()
    private let inputSources = SystemInputSourceManager()
    private let preferencesStore = SmartKeyboardPreferencesStore()
    private let diagnosticsStore = DiagnosticsStore()
    private let keyReplayer = SyntheticKeyReplayer()
    private var preferences = SmartKeyboardPreferences()
    private var engine = SmartKeyboardEngine()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var diagnostics = DiagnosticSnapshot()
    private var lastDecisionSummary = "No decision yet"
    private var suppressKeyboardEventsUntil = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        preferences = preferencesStore.load()
        refreshEngineConfiguration()
        configureStatusItem()
        rebuildMenu()
        startPassiveMonitoring()
        refreshDiagnosticsPermissions()
        diagnosticsStore.save(diagnostics)
        printStartupSummary()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopPassiveMonitoring()
    }

    private func configureStatusItem() {
        statusItem.isVisible = true
        statusItem.button?.image = statusIcon
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.title = ""
        statusItem.button?.toolTip = "SmartKeyboard"
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let stateItem = NSMenuItem(
            title: preferences.enabled ? "SmartKeyboard: On" : "SmartKeyboard: Off",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        stateItem.target = self
        menu.addItem(stateItem)

        let bufferedItem = NSMenuItem(
            title: "Buffered Mode: \(preferences.bufferedMode ? "On" : "Off")",
            action: #selector(toggleBufferedMode),
            keyEquivalent: ""
        )
        bufferedItem.target = self
        menu.addItem(bufferedItem)

        menu.addItem(.separator())

        let permissionTitle = AXIsProcessTrusted()
            ? "Accessibility: Allowed"
            : "Accessibility: Needs Permission"
        let accessibilityItem = NSMenuItem(title: permissionTitle, action: #selector(requestAccessibilityPermission), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        let inputMonitoringItem = NSMenuItem(
            title: "Input Monitoring: \(inputMonitoringStatusText())",
            action: #selector(requestInputMonitoringPermission),
            keyEquivalent: ""
        )
        inputMonitoringItem.target = self
        menu.addItem(inputMonitoringItem)

        menu.addItem(NSMenuItem(title: "Last: \(lastDecisionSummary)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Events: \(diagnostics.keyEventCount), classified: \(diagnostics.classifiedEventCount), switches: \(diagnostics.switchRequestCount)", action: nil, keyEquivalent: ""))

        menu.addItem(.separator())
        menu.addItem(sourceMenu(title: "Chinese Source", selectedID: preferences.pinyinInputSourceID, mode: .pinyin))
        menu.addItem(sourceMenu(title: "English Source", selectedID: preferences.englishInputSourceID, mode: .english))

        let refreshItem = NSMenuItem(title: "Refresh Sources", action: #selector(refreshSources), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit SmartKeyboard", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.title = ""
        statusItem.button?.toolTip = preferences.enabled ? "SmartKeyboard" : "SmartKeyboard Off"
        statusItem.button?.alphaValue = preferences.enabled ? 1.0 : 0.45
    }

    private static func makeStatusIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        NSColor.black.setStroke()
        NSColor.black.setFill()

        let keyboardRect = NSRect(x: 2.5, y: 4, width: 13, height: 10)
        let keyboardPath = NSBezierPath(roundedRect: keyboardRect, xRadius: 2.5, yRadius: 2.5)
        keyboardPath.lineWidth = 1.6
        keyboardPath.stroke()

        for keyRect in [
            NSRect(x: 5, y: 10, width: 2, height: 1.5),
            NSRect(x: 8, y: 10, width: 2, height: 1.5),
            NSRect(x: 11, y: 10, width: 2, height: 1.5),
            NSRect(x: 5, y: 7, width: 8, height: 1.5)
        ] {
            NSBezierPath(roundedRect: keyRect, xRadius: 0.7, yRadius: 0.7).fill()
        }

        let rightArrow = NSBezierPath()
        rightArrow.move(to: NSPoint(x: 5, y: 2.7))
        rightArrow.line(to: NSPoint(x: 12.2, y: 2.7))
        rightArrow.lineWidth = 1.5
        rightArrow.lineCapStyle = .round
        rightArrow.stroke()

        let rightHead = NSBezierPath()
        rightHead.move(to: NSPoint(x: 12.2, y: 2.7))
        rightHead.line(to: NSPoint(x: 10.3, y: 1.2))
        rightHead.line(to: NSPoint(x: 10.3, y: 4.2))
        rightHead.close()
        rightHead.fill()

        image.unlockFocus()

        image.isTemplate = true
        return image
    }

    private func sourceMenu(title: String, selectedID: String?, mode: SourceMode) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)

        for source in inputSources.listInputSources() {
            let item = NSMenuItem(
                title: source.localizedName,
                action: #selector(selectSource(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = SourceSelection(mode: mode, id: source.id)
            item.state = source.id == selectedID ? .on : .off
            submenu.addItem(item)
        }

        parent.submenu = submenu
        return parent
    }

    private func startPassiveMonitoring() {
        stopPassiveMonitoring()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            DispatchQueue.main.async {
                self?.handle(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func stopPassiveMonitoring() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard !keyReplayer.isReplayEvent(event), Date() >= suppressKeyboardEventsUntil else {
            return
        }

        guard preferences.enabled else {
            return
        }

        refreshDiagnosticsPermissions()
        diagnostics.keyEventCount += 1
        let result = engine.handle(KeyboardEventMapper.signal(from: event))
        guard let decision = result.decision else {
            diagnostics.lastAction = String(describing: result.action)
            diagnosticsStore.save(diagnostics)
            return
        }

        diagnostics.classifiedEventCount += 1
        diagnostics.lastTokenLength = result.token.count
        diagnostics.lastIntent = decision.intent
        diagnostics.lastConfidence = decision.confidence
        diagnostics.lastAction = String(describing: result.action)
        lastDecisionSummary = "\(decision.token) -> \(decision.intent.rawValue) \(String(format: "%.2f", decision.confidence))"

        switch result.action {
        case .none:
            break
        case .switchToPinyin:
            diagnostics.switchRequestCount += 1
            switchToConfiguredSource(
                preferences.pinyinInputSourceID,
                fallback: \.isLikelyChinesePinyin,
                bufferedReplay: result.bufferedReplay
            )
        case .switchToEnglish:
            diagnostics.switchRequestCount += 1
            switchToConfiguredSource(
                preferences.englishInputSourceID,
                fallback: \.isLikelyEnglish,
                bufferedReplay: result.bufferedReplay
            )
        }

        diagnosticsStore.save(diagnostics)
        rebuildMenu()
    }

    private func switchToConfiguredSource(
        _ configuredID: String?,
        fallback: (KeyboardInputSource) -> Bool,
        bufferedReplay: BufferedReplay?
    ) {
        let sources = inputSources.listInputSources()
        guard let targetID = configuredID ?? sources.first(where: fallback)?.id,
              inputSources.currentInputSourceID() != targetID else {
            return
        }

        if let bufferedReplay {
            performBufferedReplay(bufferedReplay, targetID: targetID)
            return
        }

        _ = selectInputSource(id: targetID)
    }

    private func selectInputSource(id targetID: String) -> Bool {
        do {
            try inputSources.selectInputSource(id: targetID)
            return true
        } catch {
            lastDecisionSummary = "Switch failed: \(error.localizedDescription)"
            return false
        }
    }

    private func performBufferedReplay(_ replay: BufferedReplay, targetID: String) {
        guard replay.deleteCount > 0, !replay.text.isEmpty else {
            _ = selectInputSource(id: targetID)
            return
        }

        guard AXIsProcessTrusted() else {
            _ = selectInputSource(id: targetID)
            lastDecisionSummary = "Buffered replay needs Accessibility permission"
            return
        }

        suppressReplayedEvents()
        keyReplayer.deleteCharacters(count: replay.deleteCount)

        guard selectInputSource(id: targetID) else {
            Thread.sleep(forTimeInterval: 0.03)
            keyReplayer.replayLetters(replay.text)
            suppressReplayedEvents()
            return
        }

        Thread.sleep(forTimeInterval: 0.05)
        keyReplayer.replayLetters(replay.text)
        suppressReplayedEvents()
    }

    private func suppressReplayedEvents(for duration: TimeInterval = 0.2) {
        suppressKeyboardEventsUntil = max(suppressKeyboardEventsUntil, Date().addingTimeInterval(duration))
    }

    private func refreshEngineConfiguration() {
        engine.update(
            configuration: SmartKeyboardEngineConfiguration(
                isEnabled: preferences.enabled,
                bufferedMode: preferences.bufferedMode
            )
        )
    }

    private func savePreferences() {
        do {
            try preferencesStore.save(preferences)
        } catch {
            lastDecisionSummary = "Save failed: \(error.localizedDescription)"
        }
    }

    @objc private func toggleEnabled() {
        preferences.enabled.toggle()
        refreshEngineConfiguration()
        savePreferences()
        rebuildMenu()
    }

    @objc private func toggleBufferedMode() {
        preferences.bufferedMode.toggle()
        refreshEngineConfiguration()
        savePreferences()
        rebuildMenu()
    }

    @objc private func refreshSources() {
        rebuildMenu()
    }

    @objc private func selectSource(_ item: NSMenuItem) {
        guard let selection = item.representedObject as? SourceSelection else {
            return
        }

        switch selection.mode {
        case .pinyin:
            preferences.pinyinInputSourceID = selection.id
        case .english:
            preferences.englishInputSourceID = selection.id
        }

        savePreferences()
        rebuildMenu()
    }

    @objc private func requestAccessibilityPermission() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func requestInputMonitoringPermission() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func printStartupSummary() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let sourceCount = inputSources.listInputSources().count
        print("SmartKeyboardApp started. PID: \(pid)")
        print("Look for the keyboard icon in the macOS menu bar near Control Center / battery / clock.")
        print("Selectable input sources found: \(sourceCount)")
        print("Preferences file: \(preferencesStore.fileURL.path)")
        print("Diagnostics file: \(diagnosticsStore.fileURL.path)")
        print("Press Ctrl+C in this terminal, or use the menu item, to stop it.")
    }

    private func inputMonitoringStatusText() -> String {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            return "Allowed"
        case kIOHIDAccessTypeDenied:
            return "Denied"
        case kIOHIDAccessTypeUnknown:
            return "Unknown"
        default:
            return "Unknown"
        }
    }

    private func refreshDiagnosticsPermissions() {
        diagnostics.accessibilityAllowed = AXIsProcessTrusted()
        diagnostics.inputMonitoringStatus = inputMonitoringStatusText()
    }
}

private enum SourceMode {
    case pinyin
    case english
}

private final class SourceSelection: NSObject {
    let mode: SourceMode
    let id: String

    init(mode: SourceMode, id: String) {
        self.mode = mode
        self.id = id
    }
}
#endif
