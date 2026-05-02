#!/usr/bin/env bash
# dashboard.sh — Two-tab tmux dashboard
#
# USAGE
#   dashboard [WORK_DIR]
#       WORK_DIR  directory to start every CLI in.
#                 Defaults to $PWD when set, else $HOME.
#
# LAYOUT
#
#   Tab 1 — "ai":
#   ┌──────────────────────┬──────────────────────┐
#   │       Claude         │        Codex         │     ← top 70 % (AI panes)
#   │     (Anthropic)      │       (OpenAI)       │
#   ├──────────────────────┴──────────────────────┤
#   │ tms-sessions — recent Claude + Codex sessions│   ← bottom 30 % (picker)
#   │ click a row to resume in the matching pane  │
#   └─────────────────────────────────────────────┘
#
#   Tab 2 — "system":
#   ┌────────────────────┬───────────────────────┐
#   │                    │   fastfetch           │
#   │       btop         ├───────────────────────┤
#   │  (full height)     │     yazi              │
#   └────────────────────┴───────────────────────┘
#
# SWITCHING TABS
#   Ctrl-b 1   tab 1 (ai)        Ctrl-b n   next tab
#   Ctrl-b 2   tab 2 (system)    Ctrl-b p   previous tab
#
# OTHER USEFUL KEYS
#   Ctrl-b ←/↑/→/↓    move between panes
#   Ctrl-b z          zoom focused pane to fullscreen (toggle)
#   Ctrl-b d          detach (everything keeps running)

# ── Argument parsing ────────────────────────────────────────────
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,30p' "$0"; exit 0
fi

WORK_DIR="${1:-${PWD:-$HOME}}"
[ -d "$WORK_DIR" ] || { printf '\033[1;31m✗\033[0m no such dir: %s\n' "$WORK_DIR" >&2; exit 1; }
WORK_DIR="$(cd "$WORK_DIR" && pwd -P)"
SESSION="dashboard"

# Already running? Just attach.
if tmux has-session -t "$SESSION" 2>/dev/null; then
  printf '\033[1;33m!\033[0m dashboard already running — attaching.\n'
  printf '   Start fresh in %s with: tmux kill-session -t %s ; dashboard %s\n' \
    "$WORK_DIR" "$SESSION" "$WORK_DIR"
  exec tmux attach -t "$SESSION"
fi

printf '\033[1;36m▶\033[0m starting dashboard in %s\n' "$WORK_DIR"

_split() { tmux split-window -P -F '#{pane_id}' "$@"; }

# ── Window 1: "ai" — Claude+Codex on top, sessions strip across bottom
# Each AI pane runs `tms-ai-pane <tool>` which shows ITS OWN dir picker
# first, so Claude and Codex can be on totally different projects.
# Split order: bottom strip first (so it spans full width), then split top.
tmux new-session -d -s "$SESSION" -n "ai" -c "$WORK_DIR" -x 280 -y 80 \
  "$HOME/.local/bin/tms-ai-pane claude"
claude_id=$(tmux list-panes -t "$SESSION:ai" -F '#{pane_id}' | head -1)

# 1. Bottom strip (full width)
sessions_id=$(_split -v -p 30 -c "$WORK_DIR" -t "$claude_id" \
              "TMUX_SESSION=$SESSION '$HOME/.local/bin/tms-sessions'")

# 2. Codex (top-right) — also gets its own dir picker
codex_id=$(_split    -h -p 50 -c "$WORK_DIR" -t "$claude_id" \
              "$HOME/.local/bin/tms-ai-pane codex")

# Stash pane IDs in tmux session env so tms-sessions can find them.
tmux set-environment -t "$SESSION" '@claude_pane' "$claude_id"
tmux set-environment -t "$SESSION" '@codex_pane'  "$codex_id"

# ── Window 2: "system" — btop (left), fastfetch + yazi (right)
tmux new-window -t "$SESSION:" -n "system" -c "$WORK_DIR" "btop"
btop_id=$(tmux list-panes -t "$SESSION:system" -F '#{pane_id}' | head -1)
ff_id=$(_split   -h -p 50 -c "$WORK_DIR" -t "$btop_id" \
  "while :; do clear; fastfetch; sleep 600; done")
yazi_id=$(_split -v -p 60 -c "$WORK_DIR" -t "$ff_id" "yazi '$WORK_DIR'")

# Land on AI tab first.
tmux select-window -t "$SESSION:ai"
tmux select-pane   -t "$claude_id"
exec tmux attach -t "$SESSION"
