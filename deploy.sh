#!/bin/bash
set -e

CODEX_DIR="$HOME/.codex"
APP_DIR="$CODEX_DIR/CodexTouchBar.app"
STATUS_FILE="$CODEX_DIR/touchbar_status.txt"
AGENT_PLIST="$HOME/Library/LaunchAgents/com.codex.touchbar.plist"
SWIFT_SRC="$CODEX_DIR/CodexTouchBar.swift"

echo "Codex Touch Bar deploy"

mkdir -p "$CODEX_DIR"

if ! command -v swiftc >/dev/null 2>&1; then
    echo "Swift compiler is required. Install it with: xcode-select --install"
    exit 1
fi

cat > "$CODEX_DIR/touchbar-update.sh" << 'SCRIPT'
#!/bin/bash
echo "${1:-idle}" > "$HOME/.codex/touchbar_status.txt"
SCRIPT
chmod +x "$CODEX_DIR/touchbar-update.sh"

cat > "$CODEX_DIR/touchbar-hook.sh" << 'SCRIPT'
#!/bin/bash
EVENT="$1"
PAYLOAD_FILE="$(mktemp "${TMPDIR:-/tmp}/codex-touchbar.XXXXXX")"
cat > "$PAYLOAD_FILE"

python3 - "$EVENT" "$PAYLOAD_FILE" << 'PY'
import hashlib
import json
import os
import sys
import time

event = (sys.argv[1] if len(sys.argv) > 1 else "").lower()
payload_file = sys.argv[2] if len(sys.argv) > 2 else ""
now = time.time()

try:
    with open(payload_file, "r", encoding="utf-8") as f:
        payload = f.read()
except Exception:
    payload = ""

try:
    data = json.loads(payload) if payload.strip() else {}
except Exception:
    data = {}

def find_value(obj, keys):
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key in keys and isinstance(value, (str, int, float)):
                return str(value)
            found = find_value(value, keys)
            if found:
                return found
    elif isinstance(obj, list):
        for item in obj:
            found = find_value(item, keys)
            if found:
                return found
    return ""

def safe_write(path, value):
    tmp_path = path + ".tmp." + str(os.getpid())
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(value)
    os.replace(tmp_path, path)

def status_for_event():
    tool = find_value(data, {"tool_name", "toolName", "name", "tool"})
    text = " ".join([event, tool]).lower()

    if "permission" in event:
        return "waiting approval"
    if "sessionstart" in event:
        return "idle"
    if "userpromptsubmit" in event:
        return "thinking"
    if "pretooluse" in event:
        if any(word in text for word in ("bash", "shell", "exec", "command")):
            return "command"
        if any(word in text for word in ("patch", "edit", "write", "apply_patch")):
            return "edit"
        return "tool"
    if "posttooluse" in event:
        return "thinking"
    if event == "stop" or "stop" in event:
        return "idle"
    return "working"

def session_key():
    from_payload = find_value(data, {
        "session_id", "sessionId",
        "conversation_id", "conversationId",
        "thread_id", "threadId",
        "rollout_id", "rolloutId",
    })
    if from_payload:
        return from_payload

    for name in ("CODEX_SESSION_ID", "CODEX_CONVERSATION_ID", "CODEX_THREAD_ID"):
        value = os.environ.get(name)
        if value:
            return value

    return "ppid:" + str(os.getppid())

def aggregate(session_dir, status_file):
    priority = {
        "waiting approval": 60,
        "command": 50,
        "edit": 45,
        "tool": 40,
        "working": 30,
        "thinking": 20,
        "idle": 0,
    }
    ttl = {
        "waiting approval": 3600,
        "command": 300,
        "edit": 300,
        "tool": 300,
        "working": 900,
        "thinking": 1800,
        "idle": 300,
    }

    best = ("idle", -1, 0.0)

    for name in os.listdir(session_dir):
        if not name.endswith(".json"):
            continue
        path = os.path.join(session_dir, name)
        try:
            with open(path, "r", encoding="utf-8") as f:
                item = json.load(f)
        except Exception:
            continue

        status = str(item.get("status", "idle"))
        updated = float(item.get("updated", 0))
        max_age = ttl.get(status, 300)

        if now - updated > max_age:
            try:
                os.remove(path)
            except OSError:
                pass
            continue

        score = priority.get(status, 0)
        if score > best[1] or (score == best[1] and updated > best[2]):
            best = (status, score, updated)

    safe_write(status_file, best[0] + "\n")

tool = find_value(data, {"tool_name", "name", "tool"})
text = " ".join([event, tool]).lower()

status = status_for_event()
key = session_key()
session_dir = os.path.expanduser("~/.codex/touchbar_sessions")
status_file = os.path.expanduser("~/.codex/touchbar_status.txt")
os.makedirs(session_dir, exist_ok=True)

session_hash = hashlib.sha256(key.encode("utf-8")).hexdigest()[:24]
session_file = os.path.join(session_dir, session_hash + ".json")

if "posttooluse" in event:
    started = now
    time.sleep(1.2)
    try:
        with open(session_file, "r", encoding="utf-8") as f:
            existing = json.load(f)
    except Exception:
        existing = {}
    if float(existing.get("updated", 0)) > started:
        aggregate(session_dir, status_file)
        sys.exit(0)
    now = time.time()

if event == "stop" or "stop" in event:
    try:
        os.remove(session_file)
    except OSError:
        pass
else:
    record = {
        "session": key,
        "status": status,
        "event": event,
        "tool": tool,
        "updated": now,
    }
    safe_write(session_file, json.dumps(record, ensure_ascii=False) + "\n")

aggregate(session_dir, status_file)
PY

rm -f "$PAYLOAD_FILE"
SCRIPT
chmod +x "$CODEX_DIR/touchbar-hook.sh"

cp "$(dirname "$0")/CodexTouchBar.swift" "$SWIFT_SRC"
swiftc "$SWIFT_SRC" -o /tmp/CodexTouchBar

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp /tmp/CodexTouchBar "$APP_DIR/Contents/MacOS/CodexTouchBar"
chmod +x "$APP_DIR/Contents/MacOS/CodexTouchBar"

cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CodexTouchBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.codex.touchbar</string>
    <key>CFBundleName</key>
    <string>CodexTouchBar</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

cat > "$AGENT_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.codex.touchbar</string>
    <key>Program</key>
    <string>$HOME/.codex/CodexTouchBar.app/Contents/MacOS/CodexTouchBar</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
PLIST

echo "idle" > "$STATUS_FILE"

pkill -f CodexTouchBar 2>/dev/null || true
sleep 1
open "$APP_DIR"

echo
echo "CodexTouchBar is installed."
echo "Enable Accessibility permission for CodexTouchBar if Touch Bar does not show it."
echo
echo "Add these Codex hooks to ~/.codex/hooks.json, preserving any hooks already there:"
cat << 'JSON'
{
  "hooks": {
    "SessionStart": [{"matcher": "*", "hooks": [{"type": "command", "command": "bash ~/.codex/touchbar-hook.sh SessionStart"}]}],
    "UserPromptSubmit": [{"matcher": "*", "hooks": [{"type": "command", "command": "bash ~/.codex/touchbar-hook.sh UserPromptSubmit"}]}],
    "PreToolUse": [{"matcher": "*", "hooks": [{"type": "command", "command": "bash ~/.codex/touchbar-hook.sh PreToolUse"}]}],
    "PostToolUse": [{"matcher": "*", "hooks": [{"type": "command", "command": "bash ~/.codex/touchbar-hook.sh PostToolUse"}]}],
    "PermissionRequest": [{"matcher": "*", "hooks": [{"type": "command", "command": "bash ~/.codex/touchbar-hook.sh PermissionRequest", "timeout": 86400}]}],
    "Stop": [{"matcher": "*", "hooks": [{"type": "command", "command": "bash ~/.codex/touchbar-hook.sh Stop"}]}]
  }
}
JSON
