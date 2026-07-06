# SmartKeyboard

## 中文快速部署 🇨🇳

SmartKeyboard 是一个 macOS 菜单栏小工具，帮助经常中英文混输的人在拼音输入法和英文输入源之间自动切换。它不安装新输入法，也不改系统输入法配置，只在判断足够明确时切换输入源。

### ✨ 当前体验

- 从英文输入法输入 `nihao`、`zhongwen` 等拼音时，会回退已打出的字母，切到拼音，再重放完整拼音。
- 从拼音输入法输入 `print`、`chinese`、`python`、`openai` 等英文时，会切到英文输入源并重放。
- `shi`、`ma`、`name` 这类短词或高歧义词默认不自动切，避免误伤。
- `Buffered Mode` 默认开启；想回到保守的被动切换，可在菜单栏里关闭。

### 🚀 启动测试版

首次运行或代码更新后：

```sh
cd /Users/jiangfuzhen/Desktop/Code_Projects/StartKeyboard
Scripts/reset-permissions.sh
Scripts/run-menu-app.sh --rebuild
```

然后在 macOS 系统设置中给这个 app 授权：

```text
/Users/jiangfuzhen/Desktop/Code_Projects/StartKeyboard/BuildProducts/SmartKeyboard.app
```

需要开启两项权限：

- Accessibility
- Input Monitoring

授权后，如果只是重新启动测试，不要 rebuild：

```sh
Scripts/run-menu-app.sh
```

### ⚠️ 权限错位说明

测试版使用本地 ad-hoc 签名。每次 `--rebuild` 后，macOS 可能仍显示同名 SmartKeyboard 已授权，但运行时实际权限失效。遇到这种情况，重新执行：

```sh
Scripts/reset-permissions.sh
Scripts/run-menu-app.sh --rebuild
```

再到系统设置里重新添加并授权 `BuildProducts/SmartKeyboard.app`。

### 🧪 开发验证

```sh
swift build
swift run SmartKeyboardSelfTest
swift run SmartKeyboardCLI
swift test --enable-swift-testing --disable-xctest
```

`SmartKeyboardSelfTest` 是当前最可靠的命令行验证；部分 Command Line Tools 环境下 `swift test` 只构建测试包，不输出实际运行报告。

### 🧩 项目结构

- `SmartKeyboardCore`: 意图分类、token 状态机、偏好和输入源管理。
- `SmartKeyboardApp`: macOS 菜单栏 app、权限状态、输入源切换和 buffered replay。
- `SmartKeyboardCLI`: 分类器预览工具。
- `SmartKeyboardSelfTest`: 无依赖自测入口。

## English Quick Start 🇺🇸

SmartKeyboard is a macOS menu-bar helper for people who switch between Pinyin and English often. It does not install a custom input method or modify system input-method settings. It only selects an existing input source when the typed token is confident enough.

### ✨ What It Does

- Typing Pinyin such as `nihao` from an English source rolls back the letters, switches to Pinyin, then replays the full token.
- Typing English such as `print`, `chinese`, `python`, or `openai` from a Pinyin source switches to English and replays the token.
- Short or ambiguous tokens such as `shi`, `ma`, and `name` stay untouched.
- `Buffered Mode` is on by default. Turn it off from the menu for passive switching.

### 🚀 Run Locally

After the first install or after code changes:

```sh
cd /Users/jiangfuzhen/Desktop/Code_Projects/StartKeyboard
Scripts/reset-permissions.sh
Scripts/run-menu-app.sh --rebuild
```

Grant permissions to:

```text
/Users/jiangfuzhen/Desktop/Code_Projects/StartKeyboard/BuildProducts/SmartKeyboard.app
```

Required macOS permissions:

- Accessibility
- Input Monitoring

For normal restarts after permissions are granted:

```sh
Scripts/run-menu-app.sh
```

### ⚠️ Permission Mismatch

The local app is ad-hoc signed. After `--rebuild`, macOS may show SmartKeyboard as enabled while the new build no longer matches the old permission record. Reset and re-grant permissions when that happens:

```sh
Scripts/reset-permissions.sh
Scripts/run-menu-app.sh --rebuild
```

### 🧪 Verify

```sh
swift build
swift run SmartKeyboardSelfTest
swift run SmartKeyboardCLI
swift test --enable-swift-testing --disable-xctest
```

`SmartKeyboardSelfTest` is the most reliable local verification path. On some Command Line Tools setups, `swift test` builds the test bundle without printing a full execution report.
