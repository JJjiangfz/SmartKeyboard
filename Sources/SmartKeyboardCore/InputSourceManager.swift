#if os(macOS)
import Carbon
import Foundation

public struct KeyboardInputSource: Equatable, Identifiable, Sendable {
    public let id: String
    public let localizedName: String
    public let category: String?
    public let isSelectable: Bool

    public init(id: String, localizedName: String, category: String?, isSelectable: Bool) {
        self.id = id
        self.localizedName = localizedName
        self.category = category
        self.isSelectable = isSelectable
    }

    public var isLikelyChinesePinyin: Bool {
        let haystack = "\(id) \(localizedName)".lowercased()
        return haystack.contains("pinyin")
            || haystack.contains("拼音")
            || haystack.contains("chinese")
            || haystack.contains("scim")
            || haystack.contains("itabc")
    }

    public var isLikelyEnglish: Bool {
        let haystack = "\(id) \(localizedName)".lowercased()
        return haystack.contains("abc")
            || haystack.contains("u.s.")
            || haystack.contains("us")
            || haystack.contains("british")
            || haystack.contains("australian")
    }
}

public protocol InputSourceManaging {
    func listInputSources() -> [KeyboardInputSource]
    func currentInputSourceID() -> String?
    func selectInputSource(id: String) throws
}

public enum InputSourceError: Error, Equatable, LocalizedError {
    case notFound(String)
    case selectionFailed(String, OSStatus)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Input source not found: \(id)"
        case .selectionFailed(let id, let status):
            return "Failed to select input source \(id), status \(status)"
        }
    }
}

public final class SystemInputSourceManager: InputSourceManaging {
    public init() {}

    public func listInputSources() -> [KeyboardInputSource] {
        allTISSources().compactMap { source in
            guard let id = stringProperty(source, kTISPropertyInputSourceID) else {
                return nil
            }

            return KeyboardInputSource(
                id: id,
                localizedName: stringProperty(source, kTISPropertyLocalizedName) ?? id,
                category: stringProperty(source, kTISPropertyInputSourceCategory),
                isSelectable: boolProperty(source, kTISPropertyInputSourceIsSelectCapable) ?? false
            )
        }
        .filter(\.isSelectable)
    }

    public func currentInputSourceID() -> String? {
        guard let unmanaged = TISCopyCurrentKeyboardInputSource() else {
            return nil
        }

        let source = unmanaged.takeRetainedValue()
        return stringProperty(source, kTISPropertyInputSourceID)
    }

    public func selectInputSource(id: String) throws {
        guard let source = allTISSources().first(where: {
            stringProperty($0, kTISPropertyInputSourceID) == id
        }) else {
            throw InputSourceError.notFound(id)
        }

        let status = TISSelectInputSource(source)
        guard status == noErr else {
            throw InputSourceError.selectionFailed(id, status)
        }
    }

    private func allTISSources() -> [TISInputSource] {
        guard let unmanaged = TISCreateInputSourceList(nil, false) else {
            return []
        }

        return (unmanaged.takeRetainedValue() as NSArray).compactMap {
            $0 as! TISInputSource?
        }
    }

    private func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else {
            return nil
        }

        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool? {
        guard let pointer = TISGetInputSourceProperty(source, key) else {
            return nil
        }

        let value = Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue()
        return CFBooleanGetValue(value)
    }
}
#endif

