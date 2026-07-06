import Testing
@testable import SmartKeyboardCore

@Suite
struct SmartKeyboardEngineTests {
    @Test
    func engineSwitchesOnceForClearPinyinToken() {
        let engine = SmartKeyboardEngine()
        var actions: [SwitchingAction] = []

        for character in "nihao" {
            actions.append(engine.handle(.character(character)).action)
        }

        #expect(actions.filter { $0 == .switchToPinyin }.count == 1)
        #expect(engine.token == "nihao")
    }

    @Test
    func separatorResetsTokenAndAllowsNextIntent() {
        let engine = SmartKeyboardEngine()

        for character in "nihao" {
            _ = engine.handle(.character(character))
        }

        _ = engine.handle(.separator)
        #expect(engine.token == "")

        var actions: [SwitchingAction] = []
        for character in "keyboard" {
            actions.append(engine.handle(.character(character)).action)
        }

        #expect(actions.contains(.switchToEnglish))
    }

    @Test
    func englishWordsThatLookPinyinLikeStillSwitchToEnglish() {
        let engine = SmartKeyboardEngine()
        var actions: [SwitchingAction] = []

        for character in "chinese" {
            actions.append(engine.handle(.character(character)).action)
        }

        #expect(actions.contains(.switchToEnglish))
    }

    @Test
    func technicalEnglishWordsSwitchToEnglish() {
        let engine = SmartKeyboardEngine()
        var actions: [SwitchingAction] = []

        for character in "print" {
            actions.append(engine.handle(.character(character)).action)
        }

        #expect(actions.contains(.switchToEnglish))
    }

    @Test
    func backspaceUpdatesTokenWithoutSwitching() {
        let engine = SmartKeyboardEngine()

        for character in "niha" {
            _ = engine.handle(.character(character))
        }

        let result = engine.handle(.backspace)
        #expect(result.token == "nih")
        #expect(result.action == .none)
    }

    @Test
    func bufferedModePlansTokenReplayWhenSwitching() {
        let engine = SmartKeyboardEngine(
            configuration: SmartKeyboardEngineConfiguration(bufferedMode: true)
        )
        var replay: BufferedReplay?

        for character in "nihao" {
            let result = engine.handle(.character(character))
            replay = result.bufferedReplay ?? replay
        }

        #expect(replay == BufferedReplay(text: "nihao", deleteCount: 5))
    }

    @Test
    func passiveModeDoesNotPlanTokenReplay() {
        let engine = SmartKeyboardEngine()
        var replays: [BufferedReplay] = []

        for character in "nihao" {
            let result = engine.handle(.character(character))
            if let replay = result.bufferedReplay {
                replays.append(replay)
            }
        }

        #expect(replays.isEmpty)
    }

    @Test
    func modifiedKeyClearsToken() {
        let engine = SmartKeyboardEngine()
        _ = engine.handle(.character("n"))
        _ = engine.handle(.character("i"))
        let result = engine.handle(.modifiedKey)

        #expect(result.token == "")
        #expect(result.action == .none)
    }

    @Test
    func disabledEngineDoesNotClassify() {
        let engine = SmartKeyboardEngine(
            configuration: SmartKeyboardEngineConfiguration(isEnabled: false)
        )

        let result = engine.handle(.character("n"))
        #expect(result.decision == nil)
        #expect(result.action == .none)
    }
}
