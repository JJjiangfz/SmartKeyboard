# SmartKeyboard

SmartKeyboard is a macOS menu-bar helper for people who constantly move between Pinyin and English. It watches local key events, infers whether the current token is likely Pinyin or English, then switches between your existing input sources when confidence is high enough. It does not install a new input method or modify system input-method configuration. ✨

SmartKeyboard 是一个 macOS 菜单栏小工具，适合经常在拼音和英文之间来回切换的人。它会本地监听按键，判断当前输入的 token 更像拼音还是英文，并在足够确定时切换到你已有的输入源。它不会安装新输入法，也不会修改系统输入法配置。✨

## What It Feels Like / 使用体验

When you type Pinyin such as `nihao` or `zhongwen` while the English source is active, SmartKeyboard rolls back the letters that already appeared, switches to Pinyin, and replays the full token so the Pinyin IME receives it cleanly.

当你在英文输入源下输入 `nihao`、`zhongwen` 这类拼音时，SmartKeyboard 会撤回已经打出的字母，切到拼音输入法，再重放完整 token，让拼音输入法干净地接收到整段拼音。

When you type English such as `print`, `chinese`, `python`, or `openai` while Pinyin is active, it switches to the English source and replays the token there.

当你在拼音输入法下输入 `print`、`chinese`、`python`、`openai` 这类英文时，它会切到英文输入源，并在那里重放这个 token。

Ambiguous short tokens such as `shi`, `ma`, and `name` are intentionally left alone. This keeps everyday Chinese typing from being interrupted by over-eager switching. 🧠

像 `shi`、`ma`、`name` 这类短词或高歧义词会被故意保留不动。这样可以避免日常中文输入被过于积极的自动切换打断。🧠

## Quick Start / 快速开始

Build and launch the local menu-bar app after the first clone or after code changes:

首次 clone 或代码更新后，用下面的命令构建并启动本地菜单栏 app：

```sh
swift build
Scripts/reset-permissions.sh
Scripts/run-menu-app.sh --rebuild
```

Grant macOS permissions to the generated app at `BuildProducts/SmartKeyboard.app`.

然后在 macOS 系统设置里给生成的 `BuildProducts/SmartKeyboard.app` 授权。

To install a clickable release app into Applications:

如果想安装成可从“应用程序”随时点击启动的 release app：

```sh
Scripts/install-app.sh
```

Grant macOS permissions to `/Applications/SmartKeyboard.app` after installation. To start it automatically after login, add SmartKeyboard in System Settings -> General -> Login Items.

安装后请给 `/Applications/SmartKeyboard.app` 授权。如果希望开机登录后自动启动，可以在系统设置 -> 通用 -> 登录项里添加 SmartKeyboard。

Required permissions:

需要开启的权限：

- Accessibility
- Input Monitoring

After permissions are granted, use the normal launcher for day-to-day restarts:

授权完成后，日常重启测试只需要运行：

```sh
Scripts/run-menu-app.sh
```

## Permission Notes / 权限说明

The development app is ad-hoc signed. After `--rebuild`, macOS may still show SmartKeyboard as enabled in System Settings, while the new executable no longer matches the old permission record. If the menu says permissions are missing, reset and grant again:

开发版 app 使用本地 ad-hoc 签名。每次 `--rebuild` 后，macOS 系统设置里可能仍然显示 SmartKeyboard 已开启权限，但新的可执行文件已经不匹配旧权限记录。如果菜单栏里显示权限缺失，请重置后重新授权：

```sh
Scripts/reset-permissions.sh
Scripts/run-menu-app.sh --rebuild
```

Then add or re-enable `BuildProducts/SmartKeyboard.app` in both Accessibility and Input Monitoring.

然后在 Accessibility 和 Input Monitoring 两处重新添加或重新开启 `BuildProducts/SmartKeyboard.app`。

## Menu Setup / 菜单设置

Open the SmartKeyboard menu from the keyboard icon in the macOS menu bar. Keep `SmartKeyboard: On`, keep `Buffered Mode: On`, choose your Pinyin source under `Chinese Source`, and choose `ABC` or your preferred English layout under `English Source`.

从 macOS 菜单栏里的键盘图标打开 SmartKeyboard 菜单。保持 `SmartKeyboard: On`，保持 `Buffered Mode: On`，在 `Chinese Source` 中选择你的拼音输入法，在 `English Source` 中选择 `ABC` 或你常用的英文键盘布局。

Buffered Mode is the smoother mode: it removes the already typed letters, switches input sources, and replays the token. You can turn it off for a more conservative passive-switching behavior.

Buffered Mode 是更顺滑的模式：它会删除已经打出的字母、切换输入源、再重放 token。如果你想使用更保守的被动切换，也可以在菜单里关闭它。

## Verify / 验证

Run the build, the dependency-free self test, and the classifier preview:

可以运行构建、自带无依赖自测，以及分类器预览：

```sh
swift build
swift run SmartKeyboardSelfTest
swift run SmartKeyboardCLI
swift test --enable-swift-testing --disable-xctest
```

`SmartKeyboardSelfTest` is the most reliable local verification path. On some Command Line Tools installations, `swift test` builds the Swift Testing bundle without printing a full execution report.

`SmartKeyboardSelfTest` 是当前最可靠的本地验证方式。在某些 Command Line Tools 环境下，`swift test` 会构建 Swift Testing 测试包，但不会输出完整运行报告。

## Project Layout / 项目结构

`SmartKeyboardCore` contains intent classification, token state, preferences, and input-source management.

`SmartKeyboardCore` 包含意图分类、token 状态机、偏好设置和输入源管理。

`SmartKeyboardApp` contains the macOS menu-bar app, permission status, input-source switching, and buffered replay.

`SmartKeyboardApp` 包含 macOS 菜单栏 app、权限状态、输入源切换和 buffered replay。

`SmartKeyboardCLI` previews classifier decisions, and `SmartKeyboardSelfTest` provides a lightweight self-test entry point.

`SmartKeyboardCLI` 用来预览分类器判断，`SmartKeyboardSelfTest` 提供轻量自测入口。

## Safety Boundaries / 安全边界

SmartKeyboard does not write to `~/Library/Input Methods`, does not write to `~/Library/Rime`, does not install a custom input source, and does not persist raw typed text.

SmartKeyboard 不会写入 `~/Library/Input Methods`，不会写入 `~/Library/Rime`，不会安装自定义输入源，也不会持久化保存原始输入内容。
