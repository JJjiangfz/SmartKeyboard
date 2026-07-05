import Foundation

public enum InputIntent: String, Codable, Equatable, Sendable {
    case pinyin
    case english
    case unknown
}

public struct IntentDecision: Equatable, Sendable {
    public let token: String
    public let intent: InputIntent
    public let confidence: Double
    public let pinyinScore: Double
    public let englishScore: Double
    public let reason: String

    public init(
        token: String,
        intent: InputIntent,
        confidence: Double,
        pinyinScore: Double,
        englishScore: Double,
        reason: String
    ) {
        self.token = token
        self.intent = intent
        self.confidence = confidence
        self.pinyinScore = pinyinScore
        self.englishScore = englishScore
        self.reason = reason
    }
}

public struct ClassificationConfig: Equatable, Sendable {
    public var minimumConfidence: Double
    public var minimumMargin: Double
    public var minimumTokenLength: Int

    public init(
        minimumConfidence: Double = 0.78,
        minimumMargin: Double = 0.16,
        minimumTokenLength: Int = 2
    ) {
        self.minimumConfidence = minimumConfidence
        self.minimumMargin = minimumMargin
        self.minimumTokenLength = minimumTokenLength
    }
}

