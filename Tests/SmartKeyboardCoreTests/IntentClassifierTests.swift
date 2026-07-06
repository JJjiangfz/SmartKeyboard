import Testing
@testable import SmartKeyboardCore

private let stableEnglishWords: Set<String> = [
    "because", "casual", "database", "delete", "feature", "final", "language",
    "normal", "notebook", "office", "plugin", "software", "system", "cursor", "words"
]

private let stableEnglishPrefixes: Set<String> = [
    "casu", "casua", "datab", "databa", "langu", "langua"
]

private final class FakeEnglishWordChecker: EnglishWordChecking {
    func isKnownEnglishWord(_ token: String) -> Bool {
        stableEnglishWords.contains(token.lowercased())
    }

    func hasEnglishCompletion(forPrefix token: String) -> Bool {
        stableEnglishPrefixes.contains(token.lowercased())
    }
}

func makeTestClassifier() -> ConservativeIntentClassifier {
    ConservativeIntentClassifier(
        config: ClassificationConfig(),
        englishWordChecker: FakeEnglishWordChecker()
    )
}

@Suite
struct IntentClassifierTests {
    private let classifier = makeTestClassifier()

    @Test
    func clearPinyinTokens() {
        for token in ["nihao", "zhongwen", "xiexie", "shenme", "qiehuan", "zhineng"] {
            expectIntent(token, .pinyin)
        }
    }

    @Test
    func clearEnglishTokens() {
        for token in ["hello", "world", "keyboard", "switch", "HTTP", "print", "python", "react"] {
            expectIntent(token, .english)
        }
    }

    @Test
    func strongEnglishWordsBeatMechanicalPinyinSegmentation() {
        for token in ["chinese", "openai", "project", "meeting", "server", "debug"] {
            expectIntent(token, .english)
        }
    }

    @Test
    func systemDictionaryEnglishWordsBeatMechanicalPinyinSegmentation() {
        for token in [
            "language", "database", "delete", "feature", "system", "software",
            "because", "normal", "casual", "office", "cursor", "plugin",
            "words", "final"
        ] {
            expectIntent(token, .english)
        }
    }

    @Test
    func injectedDictionaryWordsAreRecognizedAsEnglish() {
        expectIntent("notebook", .english)
    }

    @Test
    func commonPinyinPhrasesStayPinyin() {
        for token in [
            "women", "nimen", "tamen", "mama", "baba", "laoshi", "qingchu",
            "zhongwen", "wenjian", "xiangmu"
        ] {
            expectIntent(token, .pinyin)
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
        for token in ["he", "shi", "ma", "wo", "ni", "hao", "ai", "to", "name", "lang", "long", "can"] {
            expectIntent(token, .unknown)
        }
    }

    private func expectIntent(_ token: String, _ expected: InputIntent) {
        let decision = classifier.classify(token)
        #expect(decision.intent == expected, "\(token) -> \(decision.intent.rawValue), pinyin=\(decision.pinyinScore), english=\(decision.englishScore), reason=\(decision.reason)")
    }
}
