import AppKit
import Foundation

public protocol IntentClassifying {
    func classify(_ token: String) -> IntentDecision
}

public final class ConservativeIntentClassifier: IntentClassifying {
    private let config: ClassificationConfig
    private let pinyinModel: PinyinModel
    private let englishModel: EnglishModel

    public init(config: ClassificationConfig = ClassificationConfig()) {
        self.config = config
        self.pinyinModel = PinyinModel()
        self.englishModel = EnglishModel(wordChecker: SystemEnglishSpellChecker())
    }

    init(config: ClassificationConfig, englishWordChecker: EnglishWordChecking) {
        self.config = config
        self.pinyinModel = PinyinModel()
        self.englishModel = EnglishModel(wordChecker: englishWordChecker)
    }

    public func classify(_ token: String) -> IntentDecision {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= config.minimumTokenLength else {
            return IntentDecision(
                token: token,
                intent: .unknown,
                confidence: 0,
                pinyinScore: 0,
                englishScore: 0,
                reason: "token too short"
            )
        }

        let pinyin = pinyinModel.score(trimmed)
        let english = englishModel.score(trimmed, pinyinCoverage: pinyin.coverage)

        if english.evidence == .englishPrefix,
           pinyin.evidence == .pinyinShape {
            return IntentDecision(
                token: token,
                intent: .unknown,
                confidence: max(pinyin.value, english.value),
                pinyinScore: pinyin.value,
                englishScore: english.value,
                reason: "english prefix is still ambiguous"
            )
        }

        if english.evidence == .ambiguousPinyinEnglish {
            return IntentDecision(
                token: token,
                intent: .unknown,
                confidence: max(pinyin.value, english.value),
                pinyinScore: pinyin.value,
                englishScore: english.value,
                reason: "ambiguous pinyin/english word"
            )
        }

        let pinyinWins = pinyin.value >= config.minimumConfidence
            && pinyin.value - english.value >= config.minimumMargin
        let englishWins = english.value >= config.minimumConfidence
            && english.value - pinyin.value >= config.minimumMargin

        if pinyinWins {
            return IntentDecision(
                token: token,
                intent: .pinyin,
                confidence: pinyin.value,
                pinyinScore: pinyin.value,
                englishScore: english.value,
                reason: pinyin.reason
            )
        }

        if englishWins {
            return IntentDecision(
                token: token,
                intent: .english,
                confidence: english.value,
                pinyinScore: pinyin.value,
                englishScore: english.value,
                reason: english.reason
            )
        }

        if pinyin.evidence == .clearPinyinWord,
           pinyin.value >= config.minimumConfidence,
           pinyin.value + config.lexicalTieMargin >= english.value {
            return IntentDecision(
                token: token,
                intent: .pinyin,
                confidence: pinyin.value,
                pinyinScore: pinyin.value,
                englishScore: english.value,
                reason: pinyin.reason
            )
        }

        if english.evidence.isStrongEnglish,
           english.value >= config.minimumConfidence,
           english.value + config.lexicalTieMargin >= pinyin.value {
            return IntentDecision(
                token: token,
                intent: .english,
                confidence: english.value,
                pinyinScore: pinyin.value,
                englishScore: english.value,
                reason: english.reason
            )
        }

        return IntentDecision(
            token: token,
            intent: .unknown,
            confidence: max(pinyin.value, english.value),
            pinyinScore: pinyin.value,
            englishScore: english.value,
            reason: "confidence or margin too low"
        )
    }
}

private struct ModelScore {
    let value: Double
    let coverage: Double
    let reason: String
    let evidence: ModelEvidence
}

private enum ModelEvidence {
    case clearPinyinWord
    case pinyinShape
    case strongEnglish
    case ambiguousPinyinEnglish
    case englishPrefix
    case englishShape
    case weak
    case none

    var isStrongEnglish: Bool {
        self == .strongEnglish
    }
}

protocol EnglishWordChecking: AnyObject {
    func isKnownEnglishWord(_ token: String) -> Bool
    func hasEnglishCompletion(forPrefix token: String) -> Bool
}

final class SystemEnglishSpellChecker: EnglishWordChecking {
    private let checker = NSSpellChecker.shared
    private let language = "en_US"
    private var wordCache: [String: Bool] = [:]
    private var completionCache: [String: Bool] = [:]

    func isKnownEnglishWord(_ token: String) -> Bool {
        let lowered = token.lowercased()
        if let cached = wordCache[lowered] {
            return cached
        }

        let isKnown = checker.checkSpelling(
            of: lowered,
            startingAt: 0,
            language: language,
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: nil
        ).location == NSNotFound

        wordCache[lowered] = isKnown
        return isKnown
    }

    func hasEnglishCompletion(forPrefix token: String) -> Bool {
        let lowered = token.lowercased()
        if let cached = completionCache[lowered] {
            return cached
        }

        let length = (lowered as NSString).length
        let completions = checker.completions(
            forPartialWordRange: NSRange(location: 0, length: length),
            in: lowered,
            language: language,
            inSpellDocumentWithTag: 0
        ) ?? []
        let hasCompletion = completions.contains {
            let completion = $0.lowercased()
            return completion.hasPrefix(lowered) && completion != lowered
        }

        completionCache[lowered] = hasCompletion
        return hasCompletion
    }
}

private struct PinyinModel {
    private let syllables = PinyinSyllables.all
    private let clearWords = IntentLexicon.clearPinyinWords

    func score(_ rawToken: String) -> ModelScore {
        let token = rawToken.lowercased()

        guard token.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            return ModelScore(value: 0, coverage: 0, reason: "not plain latin", evidence: .none)
        }

        if clearWords.contains(token) {
            return ModelScore(value: 0.94, coverage: 1, reason: "known clear pinyin word", evidence: .clearPinyinWord)
        }

        let segmentation = segment(token)
        let coverage = Double(segmentation.matchedCharacters) / Double(max(token.count, 1))
        var value = coverage * 0.68

        if segmentation.isComplete {
            value = token.count >= 4 ? 0.76 : 0.48
        }

        if segmentation.syllableCount >= 2 && token.count >= 5 {
            value += 0.08
        }

        if segmentation.syllableCount >= 3 {
            value += 0.06
        }

        if token.contains("zh") || token.contains("ch") || token.contains("sh") {
            value += 0.08
        }

        if token.contains("ang") || token.contains("eng") || token.contains("ong") || token.contains("iao") {
            value += 0.04
        }

        if token.count <= 3 {
            value = min(value, 0.62)
        }

        let clamped = min(value, 0.96)
        let reason = segmentation.isComplete ? "complete pinyin segmentation" : "partial pinyin coverage"
        return ModelScore(value: clamped, coverage: coverage, reason: reason, evidence: .pinyinShape)
    }

    private func segment(_ token: String) -> (matchedCharacters: Int, syllableCount: Int, isComplete: Bool) {
        let characters = Array(token)
        let count = characters.count
        var best = Array(repeating: -1, count: count + 1)
        var syllableCounts = Array(repeating: 0, count: count + 1)
        best[0] = 0

        for index in 0..<count where best[index] >= 0 {
            for length in 1...6 where index + length <= count {
                let candidate = String(characters[index..<(index + length)])
                guard syllables.contains(candidate) else {
                    continue
                }

                let matched = best[index] + length
                if matched > best[index + length] {
                    best[index + length] = matched
                    syllableCounts[index + length] = syllableCounts[index] + 1
                }
            }
        }

        let matched = best.max() ?? 0
        let bestIndex = best.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        return (
            matchedCharacters: max(matched, 0),
            syllableCount: syllableCounts[bestIndex],
            isComplete: best[count] == count
        )
    }
}

private struct EnglishModel {
    private let commonWords = IntentLexicon.commonEnglishWords
    private let englishFragments = IntentLexicon.englishFragments
    private let ambiguousPinyinEnglishWords = IntentLexicon.ambiguousPinyinEnglishWords
    private let englishStartingClusters = IntentLexicon.englishStartingClusters
    private let englishEndingClusters = IntentLexicon.englishEndingClusters
    private let wordChecker: EnglishWordChecking

    init(wordChecker: EnglishWordChecking) {
        self.wordChecker = wordChecker
    }

    func score(_ rawToken: String, pinyinCoverage: Double) -> ModelScore {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = token.lowercased()

        if looksLikeEmail(token) {
            return ModelScore(value: 0.96, coverage: 1, reason: "email-like token", evidence: .strongEnglish)
        }

        if looksLikeURL(token) {
            return ModelScore(value: 0.97, coverage: 1, reason: "url-like token", evidence: .strongEnglish)
        }

        if looksLikePath(token) {
            return ModelScore(value: 0.91, coverage: 1, reason: "path-like token", evidence: .strongEnglish)
        }

        if looksLikeCodeIdentifier(token) {
            return ModelScore(value: 0.90, coverage: 1, reason: "code identifier", evidence: .strongEnglish)
        }

        guard lowered.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            return ModelScore(value: 0, coverage: 0, reason: "not plain latin", evidence: .none)
        }

        if isAcronym(token) {
            return ModelScore(value: 0.92, coverage: 1, reason: "uppercase acronym", evidence: .strongEnglish)
        }

        if ambiguousPinyinEnglishWords.contains(lowered) {
            return ModelScore(value: 0.88, coverage: 1, reason: "ambiguous pinyin/english word", evidence: .ambiguousPinyinEnglish)
        }

        if commonWords.contains(lowered), lowered.count >= 3 {
            return ModelScore(value: 0.92, coverage: 1, reason: "common english word", evidence: .strongEnglish)
        }

        if lowered.count <= 2 {
            return ModelScore(value: 0.22, coverage: 0.2, reason: "short ambiguous english", evidence: .weak)
        }

        if lowered.count >= 4, wordChecker.isKnownEnglishWord(lowered) {
            return ModelScore(value: 0.93, coverage: 1, reason: "system english dictionary word", evidence: .strongEnglish)
        }

        if lowered.count >= 4, wordChecker.hasEnglishCompletion(forPrefix: lowered) {
            return ModelScore(value: 0.72, coverage: 0.72, reason: "system english dictionary prefix", evidence: .englishPrefix)
        }

        var value = 0.18
        if englishFragments.contains(where: { lowered.contains($0) }) {
            value += 0.34
        }

        if pinyinCoverage < 0.45 && lowered.count >= 4 {
            value += 0.34
        } else if pinyinCoverage < 0.65 && lowered.count >= 5 {
            value += 0.22
        }

        if containsConsonantCluster(lowered) {
            value += 0.12
        }

        if hasEnglishStartingCluster(lowered) {
            value += 0.22
        }

        if hasEnglishEndingCluster(lowered) {
            value += 0.22
        }

        if lowered.count >= 7 && pinyinCoverage < 0.7 {
            value += 0.08
        }

        let clamped = min(value, 0.88)
        let evidence: ModelEvidence = clamped >= 0.78 ? .strongEnglish : .englishShape
        return ModelScore(value: clamped, coverage: value, reason: "english shape heuristics", evidence: evidence)
    }

    private func looksLikeURL(_ token: String) -> Bool {
        token.contains("://") || token.hasPrefix("www.") || token.hasSuffix(".com") || token.hasSuffix(".dev")
    }

    private func looksLikeEmail(_ token: String) -> Bool {
        token.contains("@") && token.contains(".")
    }

    private func looksLikePath(_ token: String) -> Bool {
        token.contains("/") || token.contains("\\")
    }

    private func looksLikeCodeIdentifier(_ token: String) -> Bool {
        if token.contains("_") || token.contains("-") {
            return true
        }

        let scalars = Array(token.unicodeScalars)
        guard scalars.count >= 3 else {
            return false
        }

        for index in 1..<scalars.count {
            if CharacterSet.lowercaseLetters.contains(scalars[index - 1])
                && CharacterSet.uppercaseLetters.contains(scalars[index]) {
                return true
            }
        }

        return token.contains(where: { $0.isNumber })
    }

    private func isAcronym(_ token: String) -> Bool {
        token.count >= 2 && token.allSatisfy { $0.isASCII && ($0.isUppercase || $0.isNumber) }
    }

    private func containsConsonantCluster(_ lowered: String) -> Bool {
        let vowels = Set("aeiouv")
        var run = 0

        for character in lowered {
            if vowels.contains(character) {
                run = 0
            } else {
                run += 1
                if run >= 3 {
                    return true
                }
            }
        }

        return false
    }

    private func hasEnglishStartingCluster(_ lowered: String) -> Bool {
        englishStartingClusters.contains { lowered.hasPrefix($0) }
    }

    private func hasEnglishEndingCluster(_ lowered: String) -> Bool {
        englishEndingClusters.contains { lowered.hasSuffix($0) }
    }

}
