#if os(macOS)
import AppKit
import SmartKeyboardCore

enum KeyboardEventMapper {
    static func signal(from event: NSEvent) -> KeyboardSignal {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .function])
        if !flags.isEmpty {
            return .modifiedKey
        }

        switch event.keyCode {
        case 51:
            return .backspace
        case 36, 48, 49, 76:
            return .separator
        case 53:
            return .cancel
        default:
            break
        }

        guard let text = event.characters,
              let character = text.first,
              text.count == 1 else {
            return .separator
        }

        return .character(character)
    }
}
#endif
