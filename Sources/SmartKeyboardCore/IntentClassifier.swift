import Foundation

public protocol IntentClassifying {
    func classify(_ token: String) -> IntentDecision
}

public final class ConservativeIntentClassifier: IntentClassifying {
    private let config: ClassificationConfig
    private let pinyinModel = PinyinModel()
    private let englishModel = EnglishModel()

    public init(config: ClassificationConfig = ClassificationConfig()) {
        self.config = config
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
}

private struct PinyinModel {
    private let syllables = PinyinSyllables.all
    private let clearWords: Set<String> = [
        "nihao", "zhongwen", "xiexie", "shenme", "zenme", "weishenme",
        "zhongguo", "hanyu", "pinyin", "qiehuan", "shuru", "yingwen",
        "zhineng", "ceshi", "kaifa", "xiangmu", "wenjian", "xitong",
        "yonghu", "qingwen", "haode", "duide", "bucuo", "jixu",
        "keyi", "meiyou", "buyao", "xihuan", "suoyi", "yinwei",
        "ruguo", "danshi", "zhege", "nage", "dianji"
    ]

    func score(_ rawToken: String) -> ModelScore {
        let token = rawToken.lowercased()

        guard token.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            return ModelScore(value: 0, coverage: 0, reason: "not plain latin")
        }

        if clearWords.contains(token) {
            return ModelScore(value: 0.94, coverage: 1, reason: "known clear pinyin word")
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
        return ModelScore(value: clamped, coverage: coverage, reason: reason)
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
    private let commonWords: Set<String> = [
        "about", "after", "again", "also", "and", "app", "apple", "are", "back",
        "build", "button", "case", "change", "chinese", "class", "click", "code",
        "config", "control", "data", "default", "else", "english", "false", "file",
        "for", "from", "func", "github", "hello", "import", "input", "keyboard",
        "let", "main", "menu", "name", "path", "public", "read", "return", "source",
        "string", "struct", "switch", "test", "thanks", "the", "this", "today",
        "true", "update", "user", "value", "var", "while", "window", "with", "world",
        "write"
    ]

    private let englishFragments = [
        "the", "ing", "tion", "ment", "ness", "able", "ough", "ight", "ck",
        "wh", "wr", "th", "qu", "ed", "ly", "er"
    ]

    func score(_ rawToken: String, pinyinCoverage: Double) -> ModelScore {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = token.lowercased()

        if looksLikeEmail(token) {
            return ModelScore(value: 0.96, coverage: 1, reason: "email-like token")
        }

        if looksLikeURL(token) {
            return ModelScore(value: 0.97, coverage: 1, reason: "url-like token")
        }

        if looksLikePath(token) {
            return ModelScore(value: 0.91, coverage: 1, reason: "path-like token")
        }

        if looksLikeCodeIdentifier(token) {
            return ModelScore(value: 0.90, coverage: 1, reason: "code identifier")
        }

        guard lowered.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            return ModelScore(value: 0, coverage: 0, reason: "not plain latin")
        }

        if isAcronym(token) {
            return ModelScore(value: 0.92, coverage: 1, reason: "uppercase acronym")
        }

        if commonWords.contains(lowered), lowered.count >= 3 {
            return ModelScore(value: 0.88, coverage: 1, reason: "common english word")
        }

        if lowered.count <= 2 {
            return ModelScore(value: 0.22, coverage: 0.2, reason: "short ambiguous english")
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

        if lowered.count >= 7 && pinyinCoverage < 0.7 {
            value += 0.08
        }

        return ModelScore(value: min(value, 0.86), coverage: value, reason: "english shape heuristics")
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
}

private enum PinyinSyllables {
    static let all: Set<String> = [
        "a", "ai", "an", "ang", "ao",
        "ba", "bai", "ban", "bang", "bao", "bei", "ben", "beng", "bi", "bian", "biao", "bie", "bin", "bing", "bo", "bu",
        "ca", "cai", "can", "cang", "cao", "ce", "cen", "ceng", "cha", "chai", "chan", "chang", "chao", "che", "chen", "cheng", "chi", "chong", "chou", "chu", "chua", "chuai", "chuan", "chuang", "chui", "chun", "chuo", "ci", "cong", "cou", "cu", "cuan", "cui", "cun", "cuo",
        "da", "dai", "dan", "dang", "dao", "de", "dei", "den", "deng", "di", "dia", "dian", "diao", "die", "ding", "diu", "dong", "dou", "du", "duan", "dui", "dun", "duo",
        "e", "ei", "en", "eng", "er",
        "fa", "fan", "fang", "fei", "fen", "feng", "fo", "fou", "fu",
        "ga", "gai", "gan", "gang", "gao", "ge", "gei", "gen", "geng", "gong", "gou", "gu", "gua", "guai", "guan", "guang", "gui", "gun", "guo",
        "ha", "hai", "han", "hang", "hao", "he", "hei", "hen", "heng", "hong", "hou", "hu", "hua", "huai", "huan", "huang", "hui", "hun", "huo",
        "ji", "jia", "jian", "jiang", "jiao", "jie", "jin", "jing", "jiong", "jiu", "ju", "juan", "jue", "jun",
        "ka", "kai", "kan", "kang", "kao", "ke", "ken", "keng", "kong", "kou", "ku", "kua", "kuai", "kuan", "kuang", "kui", "kun", "kuo",
        "la", "lai", "lan", "lang", "lao", "le", "lei", "leng", "li", "lia", "lian", "liang", "liao", "lie", "lin", "ling", "liu", "lo", "long", "lou", "lu", "lv", "luan", "lve", "lun", "luo",
        "ma", "mai", "man", "mang", "mao", "me", "mei", "men", "meng", "mi", "mian", "miao", "mie", "min", "ming", "miu", "mo", "mou", "mu",
        "na", "nai", "nan", "nang", "nao", "ne", "nei", "nen", "neng", "ni", "nian", "niang", "niao", "nie", "nin", "ning", "niu", "nong", "nou", "nu", "nv", "nuan", "nve", "nun", "nuo",
        "o", "ou",
        "pa", "pai", "pan", "pang", "pao", "pei", "pen", "peng", "pi", "pian", "piao", "pie", "pin", "ping", "po", "pou", "pu",
        "qi", "qia", "qian", "qiang", "qiao", "qie", "qin", "qing", "qiong", "qiu", "qu", "quan", "que", "qun",
        "ran", "rang", "rao", "re", "ren", "reng", "ri", "rong", "rou", "ru", "rua", "ruan", "rui", "run", "ruo",
        "sa", "sai", "san", "sang", "sao", "se", "sen", "seng", "sha", "shai", "shan", "shang", "shao", "she", "shei", "shen", "sheng", "shi", "shou", "shu", "shua", "shuai", "shuan", "shuang", "shui", "shun", "shuo", "si", "song", "sou", "su", "suan", "sui", "sun", "suo",
        "ta", "tai", "tan", "tang", "tao", "te", "teng", "ti", "tian", "tiao", "tie", "ting", "tong", "tou", "tu", "tuan", "tui", "tun", "tuo",
        "wa", "wai", "wan", "wang", "wei", "wen", "weng", "wo", "wu",
        "xi", "xia", "xian", "xiang", "xiao", "xie", "xin", "xing", "xiong", "xiu", "xu", "xuan", "xue", "xun",
        "ya", "yan", "yang", "yao", "ye", "yi", "yin", "ying", "yo", "yong", "you", "yu", "yuan", "yue", "yun",
        "za", "zai", "zan", "zang", "zao", "ze", "zei", "zen", "zeng", "zha", "zhai", "zhan", "zhang", "zhao", "zhe", "zhei", "zhen", "zheng", "zhi", "zhong", "zhou", "zhu", "zhua", "zhuai", "zhuan", "zhuang", "zhui", "zhun", "zhuo", "zi", "zong", "zou", "zu", "zuan", "zui", "zun", "zuo"
    ]
}
