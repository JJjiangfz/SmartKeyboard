import Testing
@testable import SmartKeyboardCore

@Suite
struct IntentClassifierTests {
    private let classifier = ConservativeIntentClassifier()

    @Test
    func clearPinyinTokens() {
        for token in ["nihao", "zhongwen", "xiexie", "shenme", "qiehuan", "zhineng"] {
            expectIntent(token, .pinyin)
        }
    }

    @Test
    func clearEnglishTokens() {
        for token in ["hello", "world", "keyboard", "switch", "HTTP"] {
            expectIntent(token, .english)
        }
    }

    @Test
    func codeAndWebTokensPreferEnglish() {
        for token in ["inputSourceID", "user_name", "name@example.com", "https://github.com", "/Users/test/file"] {
            expectIntent(token, .english)
        }
    }

    @Test
    func shortAmbiguousTokensStayUnknown() {
        for token in ["he", "shi", "ma", "ai", "to"] {
            expectIntent(token, .unknown)
        }
    }

    private func expectIntent(_ token: String, _ expected: InputIntent) {
        let decision = classifier.classify(token)
        #expect(decision.intent == expected, "\(token) -> \(decision.intent.rawValue), pinyin=\(decision.pinyinScore), english=\(decision.englishScore), reason=\(decision.reason)")
    }
}

