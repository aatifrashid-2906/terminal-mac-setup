#!/usr/bin/env bash
# ai-pane.sh — pick a working directory, then run a Claude or Codex
# session in it. Designed to be the FIRST thing a tmux AI pane runs;
# every pane shows its own picker so Claude and Codex can be in
# different projects.
#
# USAGE
#   tms-ai-pane claude
#   tms-ai-pane codex
#
# After the user picks (Enter), the chosen tool is exec'd in that dir.
# `respawn-pane` from tms-sessions can later replace the running tool
# with `<tool> --resume <id>` on the same pane — that flow is unchanged.

set -euo pipefail

TOOL="${1:-}"
case "$TOOL" in
  claude|codex) : ;;
  *) echo "usage: tms-ai-pane <claude|codex>"; exit 1 ;;
esac

# ── Banner ──────────────────────────────────────────────────────
clear
case "$TOOL" in
  claude) ICON="✦"  COLOR=$'\033[1;38;5;75m'  PRETTY="Claude" ;;
  codex)  ICON="◉"  COLOR=$'\033[1;38;5;179m' PRETTY="Codex"  ;;
esac
printf '%s%s %s workspace%s — pick a directory · type to filter · Enter launch · Esc → $HOME\n\n' \
  "$COLOR" "$ICON" "$PRETTY" $'\033[0m'

# ── Build dir list (zoxide + $HOME) ─────────────────────────────
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
echo "$HOME" >> "$TMP"
command -v zoxide >/dev/null && zoxide query --list 2>/dev/null >> "$TMP" || true
DIR_LIST="$(awk '!seen[$0]++' "$TMP")"

# ── fzf picker (per-tool color theme) ───────────────────────────
case "$TOOL" in
  claude) FZF_COLOR='fg:#c0caf5,bg:#1a1b26,hl:#7aa2f7,fg+:#c0caf5,bg+:#414868,hl+:#7dcfff,info:#7aa2f7,prompt:#7aa2f7,pointer:#7aa2f7,marker:#9ece6a' ;;
  codex)  FZF_COLOR='fg:#c0caf5,bg:#1a1b26,hl:#e0af68,fg+:#c0caf5,bg+:#414868,hl+:#e0af68,info:#e0af68,prompt:#e0af68,pointer:#e0af68,marker:#9ece6a' ;;
esac

SELECTED="$(
  printf '%s\n' "$DIR_LIST" \
    | fzf \
        --height=100% \
        --layout=reverse \
        --border=rounded \
        --prompt="$PRETTY › " \
        --pointer='▶' \
        --info=inline \
        --color="$FZF_COLOR" \
        --preview='ls -la {} 2>/dev/null | head -40' \
        --preview-window='right:45%:wrap' \
        --print-query \
    || true
)"

QUERY="$( echo "$SELECTED" | sed -n '1p')"
PICKED="$(echo "$SELECTED" | sed -n '2p')"

if [ -z "$PICKED" ]; then
  if [ -n "$QUERY" ] && [ -d "$QUERY" ]; then
    PICKED="$QUERY"
  else
    PICKED="$HOME"
  fi
fi
PICKED="${PICKED/#\~/$HOME}"
[ -d "$PICKED" ] || PICKED="$HOME"

cd "$PICKED"
printf '%s▶%s starting %s in %s\n' $'\033[1;36m' $'\033[0m' "$TOOL" "$PICKED"
exec "$TOOL"
