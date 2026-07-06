#if os(macOS)
import AppKit
import ApplicationServices
import SmartKeyboardCore

final class SyntheticKeyReplayer {
    private let eventSource = CGEventSource(stateID: .hidSystemState)

    func isReplayEvent(_ event: NSEvent) -> Bool {
        event.cgEvent?.getIntegerValueField(.eventSourceUserData) == Self.eventMarker
    }

    func deleteCharacters(count: Int) {
        postBackspaces(count: count)
    }

    func replayLetters(_ text: String) {
        postLetters(text)
    }

    private func postBackspaces(count: Int) {
        for _ in 0..<count {
            postKey(keyCode: 51)
        }
    }

    private func postLetters(_ text: String) {
        for character in text {
            guard let keyCode = Self.keyCode(for: character) else {
                continue
            }

            let flags: CGEventFlags = Self.requiresShift(for: character) ? .maskShift : []
            postKey(keyCode: keyCode, flags: flags)
        }
    }

    private func postKey(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard let keyDown = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: keyCode,
            keyDown: true
        ),
            let keyUp = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: keyCode,
                keyDown: false
            ) else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        keyUp.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private static func keyCode(for character: Character) -> CGKeyCode? {
        guard let lowercased = String(character).lowercased().first else {
            return nil
        }

        return letterKeyCodes[lowercased]
    }

    private static func requiresShift(for character: Character) -> Bool {
        let string = String(character)
        return string.uppercased() == string && string.lowercased() != string
    }

    private static let eventMarker: Int64 = 0x534D_4B42

    private static let letterKeyCodes: [Character: CGKeyCode] = [
        "a": 0,
        "s": 1,
        "d": 2,
        "f": 3,
        "h": 4,
        "g": 5,
        "z": 6,
        "x": 7,
        "c": 8,
        "v": 9,
        "b": 11,
        "q": 12,
        "w": 13,
        "e": 14,
        "r": 15,
        "y": 16,
        "t": 17,
        "o": 31,
        "u": 32,
        "i": 34,
        "p": 35,
        "l": 37,
        "j": 38,
        "k": 40,
        "n": 45,
        "m": 46
    ]
}
#endif
