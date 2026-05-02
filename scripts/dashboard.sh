#!/usr/bin/env bash
# dashboard.sh — Two-tab tmux dashboard
#
# USAGE
#   dashboard [WORK_DIR]
#       WORK_DIR  directory to start every CLI in.
#                 Defaults to $PWD when set, else $HOME.
#
# EXAMPLES
#   dashboard                          # use current shell's PWD
#   dashboard ~/d/terminal-mac-setup   # all CLIs scoped to that repo
#   dashboard /tmp                     # ad-hoc
#
# To CHANGE the working dir on a running dashboard, detach
# (Ctrl-b d), kill the session (`tmux kill-session -t dashboard`),
# then launch again with the new path:
#
#   tmux kill-session -t dashboard ; dashboard ~/projects/foo
#
#
# LAYOUT
#   Tab 1 — "ai":      Claude (left)  ·  Codex (right)
#   Tab 2 — "system":  btop (left)    ·  fastfetch + yazi stacked (right)
#
# SWITCHING TABS
#   Ctrl-b 1   tab 1 (ai)        Ctrl-b n   next tab
#   Ctrl-b 2   tab 2 (system)    Ctrl-b p   previous tab
#   click on the tab name in the top status bar
#
# OTHER USEFUL KEYS
#   Ctrl-b ←/↑/→/↓    move between panes
#   Ctrl-b z          zoom focused pane to fullscreen (toggle)
#   Ctrl-b d          detach (everything keeps running)

# ── Help / argument parsing ─────────────────────────────────────
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,30p' "$0"; exit 0
fi

WORK_DIR="${1:-${PWD:-$HOME}}"
if [ ! -d "$WORK_DIR" ]; then
  printf '\033[1;31m✗\033[0m no such directory: %s\n' "$WORK_DIR" >&2
  exit 1
fi
WORK_DIR="$(cd "$WORK_DIR" && pwd -P)"   # canonicalize
SESSION="dashboard"

# Already running? Just attach.
if tmux has-session -t "$SESSION" 2>/dev/null; then
  printf '\033[1;33m!\033[0m dashboard already running — attaching.\n'
  printf '   To start fresh in %s, first run: tmux kill-session -t %s\n' \
    "$WORK_DIR" "$SESSION"
  exec tmux attach -t "$SESSION"
fi

printf '\033[1;36m▶\033[0m starting dashboard in %s\n' "$WORK_DIR"

_split() { tmux split-window -P -F '#{pane_id}' "$@"; }

# ── Window 1: "ai"  (Claude | Codex) ────────────────────────────
tmux new-session -d -s "$SESSION" -n "ai" -c "$WORK_DIR" -x 280 -y 80 "claude"
claude_id=$(tmux list-panes -t "$SESSION:ai" -F '#{pane_id}' | head -1)
codex_id=$(_split -h -p 50 -c "$WORK_DIR" -t "$claude_id" "codex")

# ── Window 2: "system" (btop big-left, fastfetch + yazi right) ──
tmux new-window -t "$SESSION:" -n "system" -c "$WORK_DIR" "btop"
btop_id=$(tmux list-panes -t "$SESSION:system" -F '#{pane_id}' | head -1)

ff_id=$(_split   -h -p 50 -c "$WORK_DIR" -t "$btop_id" \
  "while :; do clear; fastfetch; sleep 600; done")
yazi_id=$(_split -v -p 60 -c "$WORK_DIR" -t "$ff_id" "yazi '$WORK_DIR'")

# Land on the AI tab on first attach.
tmux select-window -t "$SESSION:ai"
exec tmux attach -t "$SESSION"
