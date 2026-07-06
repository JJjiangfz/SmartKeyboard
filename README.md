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

## Quick Start / 快速开始 🏃

For normal daily use, install SmartKeyboard into Applications:

日常使用推荐先安装到“应用程序”：

```sh
Scripts/install-app.sh
```

This builds a release app at `/Applications/SmartKeyboard.app` and opens it. After that, you can start SmartKeyboard like any other Mac app: click it in Applications, Launchpad, or Spotlight. The app runs in the menu bar, so look for the keyboard icon near Control Center / battery / clock.

这会生成 release 版 `/Applications/SmartKeyboard.app` 并启动它。以后就可以像普通 Mac app 一样启动：在“应用程序”、Launchpad 或 Spotlight 中点击 SmartKeyboard。启动后它会常驻菜单栏，请在控制中心 / 电池 / 时钟附近找键盘图标。

Grant macOS permissions to `/Applications/SmartKeyboard.app` after installation:

安装后请给 `/Applications/SmartKeyboard.app` 授权：

- Accessibility
- Input Monitoring

## Menu Setup / 菜单设置

Open the SmartKeyboard menu from the keyboard icon in the macOS menu bar. Keep `SmartKeyboard: On`, keep `Buffered Mode: On`, choose your Pinyin source under `Chinese Source`, and choose `ABC` or your preferred English layout under `English Source`.

从 macOS 菜单栏里的键盘图标打开 SmartKeyboard 菜单。保持 `SmartKeyboard: On`，保持 `Buffered Mode: On`，在 `Chinese Source` 中选择你的拼音输入法，在 `English Source` 中选择 `ABC` 或你常用的英文键盘布局。

**Buffered Mode** is the smoother mode: it removes the already typed letters, switches input sources, and replays the token. You can turn it off for a more conservative passive-switching behavior.

**Buffered Mode** 是更顺滑的模式：它会删除已经打出的字母、切换输入源、再重放 token。如果你想使用更保守的被动切换，也可以在菜单里关闭它。
