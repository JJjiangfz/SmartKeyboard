import Foundation

public enum KeyboardSignal: Equatable, Sendable {
    case character(Character)
    case backspace
    case separator
    case cancel
    case modifiedKey
}

public enum SwitchingAction: Equatable, Sendable {
    case none
    case switchToPinyin
    case switchToEnglish
}

public struct BufferedReplay: Equatable, Sendable {
    public let text: String
    public let deleteCount: Int

    public init(text: String, deleteCount: Int) {
        self.text = text
        self.deleteCount = deleteCount
    }
}

public struct EngineResult: Equatable, Sendable {
    public let token: String
    public let decision: IntentDecision?
    public let action: SwitchingAction
    public let bufferedReplay: BufferedReplay?

    public init(
        token: String,
        decision: IntentDecision?,
        action: SwitchingAction,
        bufferedReplay: BufferedReplay? = nil
    ) {
        self.token = token
        self.decision = decision
        self.action = action
        self.bufferedReplay = bufferedReplay
    }
}

public struct SmartKeyboardEngineConfiguration: Equatable, Sendable {
    public var isEnabled: Bool
    public var bufferedMode: Bool

    public init(isEnabled: Bool = true, bufferedMode: Bool = false) {
        self.isEnabled = isEnabled
        self.bufferedMode = bufferedMode
    }
}

public final class SmartKeyboardEngine {
    public private(set) var token = ""

    private let classifier: IntentClassifying
    private var configuration: SmartKeyboardEngineConfiguration
    private var lastRequestedIntent: InputIntent?

    public init(
        classifier: IntentClassifying = ConservativeIntentClassifier(),
        configuration: SmartKeyboardEngineConfiguration = SmartKeyboardEngineConfiguration()
    ) {
        self.classifier = classifier
        self.configuration = configuration
    }

    public func update(configuration: SmartKeyboardEngineConfiguration) {
        self.configuration = configuration
    }

    public func reset() {
        token = ""
        lastRequestedIntent = nil
    }

    @discardableResult
    public func handle(_ signal: KeyboardSignal) -> EngineResult {
        guard configuration.isEnabled else {
            return EngineResult(token: token, decision: nil, action: .none)
        }

        switch signal {
        case .character(let character):
            guard character.isASCII && character.isLetter else {
                token = ""
                lastRequestedIntent = nil
                return EngineResult(token: token, decision: nil, action: .none)
            }

            token.append(character)
            let decision = classifier.classify(token)
            let action = action(for: decision)
            return EngineResult(
                token: token,
                decision: decision,
                action: action,
                bufferedReplay: bufferedReplay(for: action)
            )

        case .backspace:
            if !token.isEmpty {
                token.removeLast()
            }

            let decision = token.isEmpty ? nil : classifier.classify(token)
            return EngineResult(token: token, decision: decision, action: .none)

        case .separator, .cancel, .modifiedKey:
            token = ""
            lastRequestedIntent = nil
            return EngineResult(token: token, decision: nil, action: .none)
        }
    }

    private func action(for decision: IntentDecision) -> SwitchingAction {
        guard decision.intent != .unknown, decision.intent != lastRequestedIntent else {
            return .none
        }

        lastRequestedIntent = decision.intent

        switch decision.intent {
        case .pinyin:
            return .switchToPinyin
        case .english:
            return .switchToEnglish
        case .unknown:
            return .none
        }
    }

    private func bufferedReplay(for action: SwitchingAction) -> BufferedReplay? {
        guard configuration.bufferedMode, action != .none, !token.isEmpty else {
            return nil
        }

        return BufferedReplay(text: token, deleteCount: token.count)
    }
}
