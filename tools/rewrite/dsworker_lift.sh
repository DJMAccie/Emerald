#!/bin/zsh
# dsworker_lift.sh "<task>": a DeepSeek worker on the DIRTY side (cwd ~/Documents/Emerald, which may read the old mod;
# Petya 2026-11-01: "it has permission to work on the old folder as well") that writes into the clean tree by absolute
# path and may run shell commands (luajit, python3, git) without prompts. Same key/model/env as ~/bin/dsworker.
KEY_FILE="$HOME/.config/dsworker/key"
[[ -r "$KEY_FILE" ]] || { echo "missing $KEY_FILE" >&2; exit 1; }
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || ls -d "$HOME/Library/Application Support/Claude/claude-code"/*/*/claude.app/Contents/MacOS/claude 2>/dev/null | sort -V | tail -1)}"
[[ -x "$CLAUDE_BIN" ]] || { echo "claude binary not found" >&2; exit 1; }
[[ -n "$1" ]] || { echo "usage: dsworker_lift.sh \"<task>\"" >&2; exit 1; }
cd "$HOME/Documents/Emerald" || exit 1
MODEL="${DSWORKER_MODEL:-deepseek-flash}"
env -u ANTHROPIC_API_KEY \
  ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic \
  ANTHROPIC_AUTH_TOKEN="$(cat "$KEY_FILE")" \
  ANTHROPIC_MODEL="$MODEL" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="$MODEL" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="$MODEL" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="$MODEL" \
  ANTHROPIC_SMALL_FAST_MODEL="$MODEL" \
  "$CLAUDE_BIN" -p "$1" --permission-mode acceptEdits --allowedTools Bash Read Edit Write MultiEdit Glob Grep --output-format json
