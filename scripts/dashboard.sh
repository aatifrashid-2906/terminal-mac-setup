#!/usr/bin/env bash
# dashboard.sh — Two-tab tmux dashboard
#
#   ╔══════════════════════════════════════════════════╗
#   ║  Tab 1: ai      Tab 2: system                    ║   <- the tmux status bar
#   ╠══════════════════════════════════════════════════╣
#
#   Tab 1 — "ai":
#   ┌──────────────────────────────────────────────────┐
#   │                                                  │
#   │             Claude Code (full screen)            │
#   │                                                  │
#   └──────────────────────────────────────────────────┘
#
#   Tab 2 — "system":
#   ┌────────────────────────┬──────────────────────────┐
#   │                        │     fastfetch            │
#   │         btop           ├──────────────────────────┤
#   │   (full height)        │       yazi               │
#   │                        │   (file manager)         │
#   └────────────────────────┴──────────────────────────┘
#
# ─────────────────────────────────────────────────────────
# SWITCHING TABS / WORKSPACES
# ─────────────────────────────────────────────────────────
#   Ctrl-b 1            → jump to tab 1 (ai)
#   Ctrl-b 2            → jump to tab 2 (system)
#   Ctrl-b n            → next tab
#   Ctrl-b p            → previous tab
#   Click the tab name in the top status bar
# ─────────────────────────────────────────────────────────
# OTHER USEFUL KEYS
# ─────────────────────────────────────────────────────────
#   Ctrl-b ←/↑/→/↓      → move between panes within the current tab
#   Ctrl-b z            → zoom focused pane to fullscreen (toggle)
#   Ctrl-b d            → detach (everything keeps running; re-attach with `dashboard`)

SESSION="dashboard"

# Already running? Just attach.
if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

_split() { tmux split-window -P -F '#{pane_id}' "$@"; }

# ── Window 1: "ai"  (just Claude) ───────────────────────────────
tmux new-session -d -s "$SESSION" -n "ai" -x 280 -y 80 "claude"

# ── Window 2: "system" (btop big-left, fastfetch + yazi right) ──
tmux new-window -t "$SESSION:" -n "system" "btop"
btop_id=$(tmux list-panes -t "$SESSION:system" -F '#{pane_id}' | head -1)

ff_id=$(_split   -h -p 50 -t "$btop_id" \
  "while :; do clear; fastfetch; sleep 600; done")
yazi_id=$(_split -v -p 60 -t "$ff_id" "yazi $HOME")

# Land on the AI tab (Claude) on first attach.
tmux select-window -t "$SESSION:ai"
exec tmux attach -t "$SESSION"
