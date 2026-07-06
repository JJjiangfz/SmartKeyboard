import Foundation

public struct SmartKeyboardPreferences: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var bufferedMode: Bool
    public var pinyinInputSourceID: String?
    public var englishInputSourceID: String?

    public init(
        enabled: Bool = true,
        bufferedMode: Bool = true,
        pinyinInputSourceID: String? = nil,
        englishInputSourceID: String? = nil
    ) {
        self.enabled = enabled
        self.bufferedMode = bufferedMode
        self.pinyinInputSourceID = pinyinInputSourceID
        self.englishInputSourceID = englishInputSourceID
    }
}

public final class SmartKeyboardPreferencesStore {
    public let fileURL: URL

    public init(fileURL: URL = SmartKeyboardPreferencesStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public func load() -> SmartKeyboardPreferences {
        guard let data = try? Data(contentsOf: fileURL) else {
            return SmartKeyboardPreferences()
        }

        return (try? JSONDecoder().decode(SmartKeyboardPreferences.self, from: data))
            ?? SmartKeyboardPreferences()
    }

    public func save(_ preferences: SmartKeyboardPreferences) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let data = try JSONEncoder.smartKeyboard.encode(preferences)
        try data.write(to: fileURL, options: [.atomic])
    }

    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return base
            .appendingPathComponent("SmartKeyboard", isDirectory: true)
            .appendingPathComponent("preferences.json")
    }
}

private extension JSONEncoder {
    static var smartKeyboard: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
