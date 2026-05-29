# Codex Hooks

把下面配置合并到 `~/.codex/hooks.json`。如果你已有同名事件配置，不要覆盖原配置，只追加新的 hook entry。

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.codex/touchbar-hook.sh SessionStart"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.codex/touchbar-hook.sh UserPromptSubmit"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.codex/touchbar-hook.sh PreToolUse"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.codex/touchbar-hook.sh PostToolUse"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.codex/touchbar-hook.sh PermissionRequest",
            "timeout": 86400
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.codex/touchbar-hook.sh Stop"
          }
        ]
      }
    ]
  }
}
```

Codex 可能会在第一次执行新 hook 时要求信任。确认命令是 `bash ~/.codex/touchbar-hook.sh ...` 后再允许。
