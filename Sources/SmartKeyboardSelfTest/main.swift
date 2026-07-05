import Foundation
import SmartKeyboardCore

private enum SelfTestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw SelfTestFailure.failed(message)
    }
}

private func expectIntent(_ token: String, _ expected: InputIntent, classifier: ConservativeIntentClassifier) throws {
    let decision = classifier.classify(token)
    try expect(
        decision.intent == expected,
        "\(token) expected \(expected.rawValue), got \(decision.intent.rawValue), pinyin=\(decision.pinyinScore), english=\(decision.englishScore), reason=\(decision.reason)"
    )
}

private func testClassifier() throws {
    let classifier = ConservativeIntentClassifier()

    for token in ["nihao", "zhongwen", "xiexie", "shenme", "qiehuan", "zhineng"] {
        try expectIntent(token, .pinyin, classifier: classifier)
    }

    for token in ["hello", "world", "keyboard", "switch", "HTTP"] {
        try expectIntent(token, .english, classifier: classifier)
    }

    for token in ["inputSourceID", "user_name", "name@example.com", "https://github.com", "/Users/test/file"] {
        try expectIntent(token, .english, classifier: classifier)
    }

    for token in ["he", "shi", "ma", "ai", "to"] {
        try expectIntent(token, .unknown, classifier: classifier)
    }
}

private func testEngine() throws {
    let pinyinEngine = SmartKeyboardEngine()
    var pinyinActions: [SwitchingAction] = []
    for character in "nihao" {
        pinyinActions.append(pinyinEngine.handle(.character(character)).action)
    }
    try expect(pinyinActions.filter { $0 == .switchToPinyin }.count == 1, "expected one pinyin switch")
    try expect(pinyinEngine.token == "nihao", "expected token to remain nihao")

    _ = pinyinEngine.handle(.separator)
    try expect(pinyinEngine.token.isEmpty, "separator should reset token")

    var englishActions: [SwitchingAction] = []
    for character in "keyboard" {
        englishActions.append(pinyinEngine.handle(.character(character)).action)
    }
    try expect(englishActions.contains(.switchToEnglish), "expected english switch")

    let backspaceEngine = SmartKeyboardEngine()
    for character in "niha" {
        _ = backspaceEngine.handle(.character(character))
    }
    let backspace = backspaceEngine.handle(.backspace)
    try expect(backspace.token == "nih", "backspace should remove last token character")
    try expect(backspace.action == .none, "backspace should not switch input source")

    let disabled = SmartKeyboardEngine(
        configuration: SmartKeyboardEngineConfiguration(isEnabled: false)
    )
    let disabledResult = disabled.handle(.character("n"))
    try expect(disabledResult.decision == nil, "disabled engine should not classify")
    try expect(disabledResult.action == .none, "disabled engine should not switch")
}

private func testPreferences() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appendingPathComponent("preferences.json")
    let store = SmartKeyboardPreferencesStore(fileURL: fileURL)
    let preferences = SmartKeyboardPreferences(
        enabled: false,
        bufferedMode: true,
        pinyinInputSourceID: "com.apple.inputmethod.SCIM.ITABC",
        englishInputSourceID: "com.apple.keylayout.ABC"
    )

    try store.save(preferences)
    try expect(store.load() == preferences, "preferences should round-trip")
}

do {
    try testClassifier()
    try testEngine()
    try testPreferences()
    print("SmartKeyboardSelfTest passed")
} catch {
    fputs("SmartKeyboardSelfTest failed: \(error)\n", stderr)
    exit(1)
}
