# Codex Touch Bar

在 MacBook Pro Touch Bar 上显示 Codex CLI 的实时状态。原生 Swift 单文件实现，状态由 Codex hooks 驱动，支持多 Codex 会话优先级聚合。

## 效果

```text
Touch Bar:
┌──────────────────────────────────────────────────┐
│ [🐟 原地摆烂 / 🤯 脑细胞燃烧中 / 💻 命令行渡劫] │
│                      Native Control Strip 保持不变 │
└──────────────────────────────────────────────────┘
```

## 状态映射

| Codex hook | Touch Bar | 按钮底色 | SF Symbol |
| --- | --- | --- | --- |
| `SessionStart` / `Stop` | 🐟 原地摆烂 | 🟩 绿色 | `sparkles` |
| `UserPromptSubmit` / `PostToolUse` | 🤯 脑细胞燃烧中 | 🟪 紫色 | `brain.head.profile` |
| `PreToolUse` command/shell/exec | 💻 命令行渡劫 | 🟧 橙色 | `terminal.fill` |
| `PreToolUse` patch/edit/write | ✍️ 和 BUG 对线 | 🟦 蓝色 | `pencil.and.outline` |
| `PreToolUse` other tools | 🔨 花式整活 | 🟪 紫色 | `hammer.fill` |
| `PermissionRequest` | 🙋 求大佬放行 | 🟥 红色 | `exclamationmark.triangle.fill` |

## 系统要求

- macOS 14+
- MacBook Pro with Touch Bar
- Swift compiler / Xcode Command Line Tools
- Codex CLI with hooks support

安装 Swift 编译器：

```bash
xcode-select --install
```

## 安装

```bash
git clone https://github.com/EmilyTsang211/codex-touchbar.git
cd codex-touchbar
bash deploy.sh
```

安装脚本会：

- 编译 `CodexTouchBar.swift`
- 安装 app 到 `~/.codex/CodexTouchBar.app`
- 安装状态 hook 到 `~/.codex/touchbar-hook.sh`
- 创建 LaunchAgent：`~/Library/LaunchAgents/com.codex.touchbar.plist`
- 打印需要合并到 `~/.codex/hooks.json` 的 hooks 配置

首次运行后，如果 Touch Bar 没有显示，请到：

```text
系统设置 -> 隐私与安全性 -> 辅助功能
```

给 `CodexTouchBar` 开启权限。

## 配置 Codex Hooks

`deploy.sh` 不会覆盖你的 `~/.codex/hooks.json`。请把脚本输出的 hooks 配置合并到现有文件里。

如果你已经有同名事件的 hooks，保留原配置，在对应事件数组里追加这一类 hook：

```json
{
  "matcher": "*",
  "hooks": [
    {
      "type": "command",
      "command": "bash ~/.codex/touchbar-hook.sh UserPromptSubmit"
    }
  ]
}
```

完整示例见 [docs/hooks.md](docs/hooks.md)。

## 多会话规则

每个 Codex 会话写入自己的状态文件：

```bash
~/.codex/touchbar_sessions/*.json
```

Touch Bar app 只读取聚合后的全局状态：

```bash
~/.codex/touchbar_status.txt
```

多个 Codex 会话同时运行时，按以下优先级显示：

1. `🙋 求大佬放行`
2. `💻 命令行渡劫`
3. `✍️ 和 BUG 对线`
4. `🔨 花式整活`
5. `🤯 脑细胞燃烧中`
6. `🐟 原地摆烂`

同优先级时，以最近更新的会话为准。过久未更新的会话状态会被自动忽略。

## 卸载

```bash
pkill -f CodexTouchBar
rm -rf ~/.codex/CodexTouchBar.app ~/.codex/CodexTouchBar.swift
rm -rf ~/.codex/touchbar_sessions
rm -f ~/.codex/touchbar-update.sh ~/.codex/touchbar-hook.sh ~/.codex/touchbar_status.txt
rm -f ~/Library/LaunchAgents/com.codex.touchbar.plist
```

然后从 `~/.codex/hooks.json` 里删除 `bash ~/.codex/touchbar-hook.sh ...` 相关 hooks。

## 注意

这个项目使用 macOS 私有 `DFRFoundation` API 展示 Touch Bar 内容。它在系统升级后可能失效，也不适合上架 App Store。

## 致谢

本项目基于 Touch Bar 私有 API 思路改造，灵感来自 [mateocehn-jpg/claude-touchbar](https://github.com/mateocehn-jpg/claude-touchbar)。

## License

MIT
