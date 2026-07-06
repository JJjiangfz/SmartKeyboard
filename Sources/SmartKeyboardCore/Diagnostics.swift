import Foundation

public struct DiagnosticSnapshot: Codable, Equatable, Sendable {
    public var keyEventCount: Int
    public var classifiedEventCount: Int
    public var switchRequestCount: Int
    public var lastTokenLength: Int
    public var lastIntent: InputIntent
    public var lastConfidence: Double
    public var lastAction: String
    public var accessibilityAllowed: Bool
    public var inputMonitoringStatus: String

    public init(
        keyEventCount: Int = 0,
        classifiedEventCount: Int = 0,
        switchRequestCount: Int = 0,
        lastTokenLength: Int = 0,
        lastIntent: InputIntent = .unknown,
        lastConfidence: Double = 0,
        lastAction: String = "none",
        accessibilityAllowed: Bool = false,
        inputMonitoringStatus: String = "Unknown"
    ) {
        self.keyEventCount = keyEventCount
        self.classifiedEventCount = classifiedEventCount
        self.switchRequestCount = switchRequestCount
        self.lastTokenLength = lastTokenLength
        self.lastIntent = lastIntent
        self.lastConfidence = lastConfidence
        self.lastAction = lastAction
        self.accessibilityAllowed = accessibilityAllowed
        self.inputMonitoringStatus = inputMonitoringStatus
    }
}

public final class DiagnosticsStore {
    public let fileURL: URL

    public init(fileURL: URL = DiagnosticsStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public func save(_ snapshot: DiagnosticSnapshot) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(snapshot).write(to: fileURL, options: [.atomic])
        } catch {
            // Diagnostics must never interrupt typing.
        }
    }

    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return base
            .appendingPathComponent("SmartKeyboard", isDirectory: true)
            .appendingPathComponent("diagnostics.json")
    }
}
