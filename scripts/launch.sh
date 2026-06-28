#!/usr/bin/env bash
# UserPromptSubmit hook: silently start the Review Pilot server and open the browser UI,
# but only when the submitted prompt invokes /r-pilot. Reads the hook JSON on stdin and
# emits nothing to stdout, so nothing shows in the chat.
set -uo pipefail

input="$(cat)"
# Match the r-pilot slash command / skill invocation in the submitted prompt.
printf '%s' "$input" | grep -qiE '(^|[/$[:space:]])r-pilot([[:space:]]|$|")' || exit 0

PORT=3922
SERVER="$(cd "$(dirname "$0")/.." && pwd)/server.js"
URL="http://localhost:$PORT"
LOG=/tmp/reviewpilot-server.log

# Everything below runs detached and silent so the hook returns immediately
# and prints nothing to the chat.
(
  # ── Start server if not already running ────────────────────────────────────
  if ! curl -s --max-time 1 "$URL/health" >/dev/null 2>&1; then
    [ -f "$SERVER" ] || exit 0
    nohup node "$SERVER" > "$LOG" 2>&1 &
    for _ in 1 2 3 4 5; do
      sleep 1
      curl -s --max-time 1 "$URL/health" >/dev/null 2>&1 && break
    done
    curl -s --max-time 1 "$URL/health" >/dev/null 2>&1 || exit 0
  fi

  # ── Open browser (cross-platform) ──────────────────────────────────────────
  uname="$(uname -s 2>/dev/null || echo Windows)"
  case "$uname" in
    Darwin) open "$URL" ;;
    Linux)
      # WSL: uname reports Linux but the Windows browser is reachable via cmd.exe
      if grep -qi microsoft /proc/version 2>/dev/null; then
        cmd.exe /c start "" "$URL" 2>/dev/null \
          || powershell.exe -c "Start-Process '$URL'" 2>/dev/null
      else
        xdg-open "$URL"
      fi ;;
    MINGW*|MSYS*|CYGWIN*)
      cmd.exe /c start "" "$URL" 2>/dev/null \
        || powershell.exe -c "Start-Process '$URL'" 2>/dev/null ;;
    *)
      xdg-open "$URL" 2>/dev/null || open "$URL" 2>/dev/null \
        || cmd.exe /c start "" "$URL" 2>/dev/null ;;
  esac
) >/dev/null 2>&1 &

exit 0
