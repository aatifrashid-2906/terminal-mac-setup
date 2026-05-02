#!/usr/bin/env bash
# launcher.sh — interactive directory picker that hands off to dashboard
#
# Sources for the picker (in priority order):
#   1. zoxide query --list (frequent dirs you've cd'd to)
#   2. $HOME as a fallback option
#
# fzf has full mouse + keyboard support: type to filter, click or
# arrow+Enter to pick. Esc cancels and starts the dashboard at $HOME.
#
# This script is what Ghostty runs on startup, so its UX is the first
# thing you see when you open a new window.

set -euo pipefail

# ── Banner + theme ──────────────────────────────────────────────
clear
cat <<'BANNER'
   ╔══════════════════════════════════════════════════════════════╗
   ║                  terminal-mac-setup launcher                 ║
   ║                                                              ║
   ║      Pick a working directory  ·  type to filter             ║
   ║      [Enter] launch  ·  [Esc] use $HOME                      ║
   ╚══════════════════════════════════════════════════════════════╝
BANNER
echo

# ── Build the directory list ────────────────────────────────────
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Always include $HOME so you can fall back without aborting
echo "$HOME" >> "$TMP"

if command -v zoxide >/dev/null 2>&1; then
  # Most-frecent dirs first (zoxide's natural ordering)
  zoxide query --list 2>/dev/null >> "$TMP" || true
fi

# Dedupe while preserving order
DIR_LIST="$(awk '!seen[$0]++' "$TMP")"

# ── fzf picker ──────────────────────────────────────────────────
SELECTED="$(
  printf '%s\n' "$DIR_LIST" \
    | fzf \
        --height=70% \
        --layout=reverse \
        --border=rounded \
        --prompt='cd › ' \
        --pointer='▶' \
        --marker='✓' \
        --info=inline \
        --color='fg:#c0caf5,bg:#1a1b26,hl:#7aa2f7,fg+:#c0caf5,bg+:#414868,hl+:#7dcfff,info:#bb9af7,prompt:#7aa2f7,pointer:#9ece6a,marker:#9ece6a,spinner:#e0af68,header:#565f89' \
        --preview='ls -la --color=always {} 2>/dev/null | head -40 || ls -la {} 2>/dev/null | head -40' \
        --preview-window='right:50%:wrap' \
        --print-query \
        --expect=enter \
    || true
)"

# fzf with --print-query --expect=enter prints:
#   line 1: the typed query
#   line 2: the key that triggered (e.g. 'enter')
#   line 3: the selected line (or empty)
QUERY="$(echo "$SELECTED" | sed -n '1p')"
KEY="$(echo "$SELECTED"   | sed -n '2p')"
PICKED="$(echo "$SELECTED" | sed -n '3p')"

# Esc / no selection → start at $HOME
if [ -z "$PICKED" ]; then
  if [ -n "$QUERY" ] && [ -d "$QUERY" ]; then
    # User typed a path that exists but didn't match; honor it
    PICKED="$QUERY"
  else
    PICKED="$HOME"
  fi
fi

# Expand ~
PICKED="${PICKED/#\~/$HOME}"

if [ ! -d "$PICKED" ]; then
  printf '\033[1;31m✗\033[0m %s is not a directory. Falling back to $HOME.\n' "$PICKED"
  PICKED="$HOME"
fi

cd "$PICKED"
exec "$HOME/.local/bin/tms-dashboard" "$PICKED"
