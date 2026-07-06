# SmartKeyboard

SmartKeyboard is a conservative macOS input-source assistant for Chinese users who switch between Pinyin and English often. The first version is a menu-bar app plus a CLI preview harness.

The project deliberately does **not** install a custom input method and does **not** edit existing input-method configuration. It only calls macOS input-source selection APIs when the typed token is highly likely to be Pinyin or English.

## Current Shape

- `SmartKeyboardCore`: classification, token state, preferences, and macOS input-source selection.
- `SmartKeyboardCLI`: deterministic preview for classifier tuning.
- `SmartKeyboardApp`: AppKit menu-bar app with passive switching.

Buffered key replay is represented as an experimental setting, but the first app build keeps passive switching as the default and safe behavior.

## Safety Boundaries

- No writes to `~/Library/Input Methods`.
- No writes to `~/Library/Rime`.
- No installation of a new input source.
- User preferences live under `~/Library/Application Support/SmartKeyboard`.
- Tests use temporary directories.
- Runtime does not persist raw typed text.

## Development

```sh
swift build
swift test --enable-swift-testing --disable-xctest
swift run SmartKeyboardSelfTest
swift run SmartKeyboardCLI
swift run SmartKeyboardApp
```

For a more realistic menu-bar launch during development, use the local app-bundle wrapper:

```sh
chmod +x Scripts/run-menu-app.sh
Scripts/run-menu-app.sh
```

The wrapper creates `BuildProducts/SmartKeyboard.app`, launches it with `open`, and stops any previous development instance first. It reuses the existing app by default so macOS privacy permissions do not get invalidated on every restart. Use `Scripts/run-menu-app.sh --rebuild` only after code changes.

The menu-bar app needs macOS input-monitoring/accessibility permissions to observe global key events reliably.
Grant the visible `BuildProducts/SmartKeyboard.app` in both Privacy & Security pages:

- Accessibility
- Input Monitoring

If macOS shows SmartKeyboard as enabled but the app still says permission is missing, reset stale TCC entries and grant the freshly rebuilt app again:

```sh
Scripts/reset-permissions.sh
Scripts/run-menu-app.sh --rebuild
```

This machine's Command Line Tools installation does not include an importable XCTest module, so the repository uses Swift Testing for the lightweight test target and also carries a dependency-free self-test executable. `SmartKeyboardSelfTest` prints an explicit pass/fail result and covers the file-system preference round trip.
