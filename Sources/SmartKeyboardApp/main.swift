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
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let inputSources = SystemInputSourceManager()
    private let preferencesStore = SmartKeyboardPreferencesStore()
    private let diagnosticsStore = DiagnosticsStore()
    private var preferences = SmartKeyboardPreferences()
    private var engine = SmartKeyboardEngine()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var diagnostics = DiagnosticSnapshot()
    private var lastDecisionSummary = "No decision yet"
    private var suppressKeyboardEventsUntil = Date.distantPast
    private let syntheticEventSource = CGEventSource(stateID: .hidSystemState)

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
        statusItem.button?.title = "SmartKeyboard"
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
        statusItem.button?.title = preferences.enabled ? "SmartKeyboard" : "SmartKeyboard Off"
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
        guard !isSyntheticReplayEvent(event), Date() >= suppressKeyboardEventsUntil else {
            return
        }

        guard preferences.enabled else {
            return
        }

        refreshDiagnosticsPermissions()
        diagnostics.keyEventCount += 1
        let result = engine.handle(signal(from: event))
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

    private func signal(from event: NSEvent) -> KeyboardSignal {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .function])
        if !flags.isEmpty {
            return .modifiedKey
        }

        switch event.keyCode {
        case 51:
            return .backspace
        case 36, 48, 49, 76:
            return .separator
        case 53:
            return .cancel
        default:
            break
        }

        guard let text = event.characters,
              let character = text.first,
              text.count == 1 else {
            return .separator
        }

        return .character(character)
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
        postBackspaces(count: replay.deleteCount)

        guard selectInputSource(id: targetID) else {
            Thread.sleep(forTimeInterval: 0.03)
            postLetters(replay.text)
            suppressReplayedEvents()
            return
        }

        Thread.sleep(forTimeInterval: 0.05)
        postLetters(replay.text)
        suppressReplayedEvents()
    }

    private func suppressReplayedEvents(for duration: TimeInterval = 0.2) {
        suppressKeyboardEventsUntil = max(suppressKeyboardEventsUntil, Date().addingTimeInterval(duration))
    }

    private func postBackspaces(count: Int) {
        for _ in 0..<count {
            postKey(keyCode: 51)
        }
    }

    private func postLetters(_ text: String) {
        for character in text {
            guard let keyCode = Self.keyCode(for: character) else {
                continue
            }

            let flags: CGEventFlags = Self.requiresShift(for: character) ? .maskShift : []
            postKey(keyCode: keyCode, flags: flags)
        }
    }

    private func postKey(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard let keyDown = CGEvent(
            keyboardEventSource: syntheticEventSource,
            virtualKey: keyCode,
            keyDown: true
        ),
            let keyUp = CGEvent(
                keyboardEventSource: syntheticEventSource,
                virtualKey: keyCode,
                keyDown: false
            ) else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
        keyUp.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func isSyntheticReplayEvent(_ event: NSEvent) -> Bool {
        event.cgEvent?.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker
    }

    private static func keyCode(for character: Character) -> CGKeyCode? {
        guard let lowercased = String(character).lowercased().first else {
            return nil
        }

        return letterKeyCodes[lowercased]
    }

    private static func requiresShift(for character: Character) -> Bool {
        let string = String(character)
        return string.uppercased() == string && string.lowercased() != string
    }

    private static let letterKeyCodes: [Character: CGKeyCode] = [
        "a": 0,
        "s": 1,
        "d": 2,
        "f": 3,
        "h": 4,
        "g": 5,
        "z": 6,
        "x": 7,
        "c": 8,
        "v": 9,
        "b": 11,
        "q": 12,
        "w": 13,
        "e": 14,
        "r": 15,
        "y": 16,
        "t": 17,
        "o": 31,
        "u": 32,
        "i": 34,
        "p": 35,
        "l": 37,
        "j": 38,
        "k": 40,
        "n": 45,
        "m": 46
    ]

    private static let syntheticEventMarker: Int64 = 0x534D_4B42

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
        print("Look for 'SmartKeyboard' in the macOS menu bar near Control Center / battery / clock.")
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
