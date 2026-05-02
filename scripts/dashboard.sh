#!/usr/bin/env bash
# dashboard.sh — Three AI assistants + compact system monitor
#
#   ┌──────────────┬──────────────┬──────────────┐
#   │              │              │              │
#   │   Claude     │   ChatGPT    │   Gemini     │
#   │  (Anthropic) │   (codex)    │  (Google)    │
#   │              │              │              │
#   ├──────────────┴──────────────┴──────────────┤
#   │             btop (25 % strip)              │
#   └────────────────────────────────────────────┘
#
# Each AI pane runs the official CLI for that model.
# Set the corresponding API key in your shell (~/.zshrc.local works):
#   export ANTHROPIC_API_KEY=...   (claude — or run `claude /login`)
#   export OPENAI_API_KEY=...      (codex)
#   export GEMINI_API_KEY=...      (gemini)
#
# Launch:    dashboard
# Detach:    Ctrl-b d         (session keeps running; assistants keep state)
# Re-attach: dashboard
# Zoom one pane to fullscreen: Ctrl-b z   (toggle)
# Move pane:  Ctrl-b ←/↑/→/↓  or click

SESSION="dashboard"

# Already running? Just attach.
if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

_split() { tmux split-window -P -F '#{pane_id}' "$@"; }

# Create with a comfortable initial size; tmux resizes on client attach.
tmux new-session -d -s "$SESSION" -n "main" -x 280 -y 80 "claude"
claude_id=$(tmux list-panes -t "$SESSION:main" -F '#{pane_id}' | head -1)

# Bottom strip: btop (25 % of total height).
btop_id=$(_split   -v -p 25 -t "$claude_id" "btop")

# Top row: Claude | Codex | Gemini.
codex_id=$(_split  -h -p 66 -t "$claude_id" "codex")
gemini_id=$(_split -h -p 50 -t "$codex_id"  "gemini")

# Focus Claude (top-left), attach.
tmux select-pane -t "$claude_id"
exec tmux attach -t "$SESSION"
