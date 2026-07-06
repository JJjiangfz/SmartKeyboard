#if os(macOS)
import AppKit
import ApplicationServices
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
    private var preferences = SmartKeyboardPreferences()
    private var engine = SmartKeyboardEngine()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastDecisionSummary = "No decision yet"

    func applicationDidFinishLaunching(_ notification: Notification) {
        preferences = preferencesStore.load()
        refreshEngineConfiguration()
        configureStatusItem()
        rebuildMenu()
        startPassiveMonitoring()
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
            ? "Input Monitoring: Allowed"
            : "Input Monitoring: Needs Permission"
        let permissionItem = NSMenuItem(title: permissionTitle, action: #selector(openPrivacySettings), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)

        menu.addItem(NSMenuItem(title: "Last: \(lastDecisionSummary)", action: nil, keyEquivalent: ""))

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
        guard preferences.enabled else {
            return
        }

        let result = engine.handle(signal(from: event))
        guard let decision = result.decision else {
            return
        }

        lastDecisionSummary = "\(decision.token) -> \(decision.intent.rawValue) \(String(format: "%.2f", decision.confidence))"

        switch result.action {
        case .none:
            break
        case .switchToPinyin:
            selectConfiguredSource(preferences.pinyinInputSourceID, fallback: \.isLikelyChinesePinyin)
        case .switchToEnglish:
            selectConfiguredSource(preferences.englishInputSourceID, fallback: \.isLikelyEnglish)
        }

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

        guard let text = event.charactersIgnoringModifiers,
              let character = text.first,
              text.count == 1 else {
            return .separator
        }

        return .character(character)
    }

    private func selectConfiguredSource(_ configuredID: String?, fallback: (KeyboardInputSource) -> Bool) {
        let sources = inputSources.listInputSources()
        guard let targetID = configuredID ?? sources.first(where: fallback)?.id,
              inputSources.currentInputSourceID() != targetID else {
            return
        }

        do {
            try inputSources.selectInputSource(id: targetID)
        } catch {
            lastDecisionSummary = "Switch failed: \(error.localizedDescription)"
        }
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

    @objc private func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
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
        print("Press Ctrl+C in this terminal, or use the menu item, to stop it.")
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
