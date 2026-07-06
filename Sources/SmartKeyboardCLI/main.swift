import Foundation
import SmartKeyboardCore

private struct Sample {
    let token: String
    let expected: InputIntent
}

private let samples: [Sample] = [
    Sample(token: "nihao", expected: .pinyin),
    Sample(token: "zhongwen", expected: .pinyin),
    Sample(token: "xiexie", expected: .pinyin),
    Sample(token: "shenme", expected: .pinyin),
    Sample(token: "qiehuan", expected: .pinyin),
    Sample(token: "zhineng", expected: .pinyin),
    Sample(token: "hello", expected: .english),
    Sample(token: "world", expected: .english),
    Sample(token: "keyboard", expected: .english),
    Sample(token: "switch", expected: .english),
    Sample(token: "print", expected: .english),
    Sample(token: "chinese", expected: .english),
    Sample(token: "python", expected: .english),
    Sample(token: "react", expected: .english),
    Sample(token: "openai", expected: .english),
    Sample(token: "project", expected: .english),
    Sample(token: "meeting", expected: .english),
    Sample(token: "server", expected: .english),
    Sample(token: "debug", expected: .english),
    Sample(token: "women", expected: .pinyin),
    Sample(token: "nimen", expected: .pinyin),
    Sample(token: "tamen", expected: .pinyin),
    Sample(token: "inputSourceID", expected: .english),
    Sample(token: "name@example.com", expected: .english),
    Sample(token: "https://github.com", expected: .english),
    Sample(token: "he", expected: .unknown),
    Sample(token: "shi", expected: .unknown),
    Sample(token: "ma", expected: .unknown),
    Sample(token: "ai", expected: .unknown),
    Sample(token: "name", expected: .unknown),
    Sample(token: "to", expected: .unknown)
]

private let classifier = ConservativeIntentClassifier()

print("SmartKeyboard classifier preview")
print(String(repeating: "=", count: 80))
print("token               expected  predicted confidence pinyin english reason")
print(String(repeating: "-", count: 80))

var correct = 0
var misses: [String] = []

for sample in samples {
    let decision = classifier.classify(sample.token)
    if decision.intent == sample.expected {
        correct += 1
    } else {
        misses.append("\(sample.token): expected \(sample.expected.rawValue), got \(decision.intent.rawValue)")
    }

    print(
        "\(sample.token.padded(to: 19)) "
            + "\(sample.expected.rawValue.padded(to: 9)) "
            + "\(decision.intent.rawValue.padded(to: 9)) "
            + "\(decision.confidence.fixed(2).padded(to: 10)) "
            + "\(decision.pinyinScore.fixed(2).padded(to: 6)) "
            + "\(decision.englishScore.fixed(2).padded(to: 7)) "
            + decision.reason
    )
}

let accuracy = Double(correct) / Double(samples.count)
print(String(repeating: "-", count: 80))
print(String(format: "accuracy: %d/%d (%.1f%%)", correct, samples.count, accuracy * 100))

if !misses.isEmpty {
    print("misses:")
    misses.forEach { print("- \($0)") }
}

print("\nDecision trace for typing 'zhongwen ' then 'keyboard ':")
let engine = SmartKeyboardEngine()
for character in "zhongwen keyboard" {
    let signal: KeyboardSignal = character == " " ? .separator : .character(character)
    let result = engine.handle(signal)
    if let decision = result.decision {
        print(
            "token=\(result.token.padded(to: 8)) "
                + "intent=\(decision.intent.rawValue.padded(to: 7)) "
                + "pinyin=\(decision.pinyinScore.fixed(2)) "
                + "english=\(decision.englishScore.fixed(2)) "
                + "action=\(String(describing: result.action))"
        )
    }
}

private extension String {
    func padded(to width: Int) -> String {
        if count >= width {
            return self
        }

        return self + String(repeating: " ", count: width - count)
    }
}

private extension Double {
    func fixed(_ digits: Int) -> String {
        String(format: "%.\(digits)f", self)
    }
}
