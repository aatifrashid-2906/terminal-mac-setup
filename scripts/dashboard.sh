#!/usr/bin/env bash
# dashboard.sh — launch a 4-pane tmux dashboard
#
#   ┌──────────────────────┬──────────────────────┐
#   │                      │                      │
#   │       btop           │      fastfetch       │
#   │  (top — full height) │  (top right)         │
#   │                      │                      │
#   │                      ├──────────────────────┤
#   │                      │  weather (wttr.in)   │
#   │                      │  refreshes every 10m │
#   ├──────────────────────┴──────────────────────┤
#   │  clx (Hacker News TUI)  — bottom full-width │
#   └─────────────────────────────────────────────┘
#
# Launch: dashboard       (after install.sh wires the alias)
# Detach: Ctrl-b d        (the tmux session keeps running)
# Kill:   Ctrl-b x        (kill current pane)
# Reattach: dashboard     (re-runs and re-attaches)

set -euo pipefail

SESSION="dashboard"
WEATHER_CITY="${WEATHER_CITY:-Delhi}"

# If a session is already running, just attach to it.
if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

# Build the layout.
tmux new-session  -d -s "$SESSION" -n "main" "btop"

# Right column, top: fastfetch on a refresh loop so the window stays alive.
tmux split-window -h -t "$SESSION:main" \
  "while true; do clear; fastfetch; sleep 600; done"

# Right column, bottom: rolling weather report.
tmux split-window -v -t "$SESSION:main.2" \
  "while true; do clear; curl -s \"wttr.in/${WEATHER_CITY}?2qF\"; sleep 600; done"

# Bottom full-width row: Hacker News (clx).
tmux select-pane -t "$SESSION:main.1"
tmux split-window -v -p 25 -t "$SESSION:main.1" "clx"

# Resize columns so btop gets ~55 % of width.
tmux resize-pane -t "$SESSION:main.1" -x 60%

# Focus btop and attach.
tmux select-pane -t "$SESSION:main.1"
exec tmux attach -t "$SESSION"
