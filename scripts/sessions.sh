#!/usr/bin/env bash
# sessions.sh — pick a recent Claude or Codex session and respawn the
# corresponding pane in the running tmux dashboard.
#
# Data sources:
#   Claude: ~/.claude/projects/<encoded>/<uuid>.jsonl  (first line has aiTitle, sessionId)
#   Codex:  ~/.codex/session_index.jsonl              (id, thread_name, updated_at)
#
# On select:
#   - figures out [tool], session-id, project dir
#   - tmux respawn-pane -k -c <dir> -t <pane> "<tool> --resume <id>"
#   - falls back to the CLI's own picker if the id-based resume fails
#
# Designed to run inside a tmux pane in the "ai" window. After each
# selection it re-renders the picker so the strip stays interactive.
#
# Pane targets are read from tmux env vars set by dashboard.sh:
#   @claude_pane     stable %-id of the Claude pane
#   @codex_pane      stable %-id of the Codex pane

set -euo pipefail

# ── Helpers ─────────────────────────────────────────────────────
_relative_time() {
  # Convert epoch seconds → "3h ago" / "2d ago" / "1w ago"
  local now ts diff
  now="$(date +%s)"
  ts="$1"
  diff=$(( now - ts ))
  if   [ $diff -lt 60      ]; then echo "${diff}s ago"
  elif [ $diff -lt 3600    ]; then echo "$((diff/60))m ago"
  elif [ $diff -lt 86400   ]; then echo "$((diff/3600))h ago"
  elif [ $diff -lt 604800  ]; then echo "$((diff/86400))d ago"
  else                              echo "$((diff/604800))w ago"
  fi
}

_decode_claude_path() {
  # Claude encodes "/Users/apple/d" as "-Users-apple-d"
  # Just replace every "-" with "/" — the leading "-" becomes the leading "/"
  echo "${1//-//}"
}

# ── Build the unified session list ──────────────────────────────
_list_sessions() {
  # Output format (TSV, mtime first for sorting):
  #   <mtime>\t<tool>\t<session-id>\t<project-dir>\t<title>

  # Claude
  if [ -d "$HOME/.claude/projects" ]; then
    while IFS= read -r jsonl; do
      [ -f "$jsonl" ] || continue
      local mtime project encoded sid title
      mtime="$(stat -f '%m' "$jsonl" 2>/dev/null || echo 0)"
      encoded="$(basename "$(dirname "$jsonl")")"
      project="$(_decode_claude_path "$encoded")"
      # Get aiTitle + sessionId from the first JSON line
      read -r sid title < <(
        head -1 "$jsonl" 2>/dev/null \
          | python3 -c '
import json,sys
try:
    j=json.loads(sys.stdin.read())
    sid=j.get("sessionId","")
    title=(j.get("aiTitle") or "").replace("\t"," ")[:80]
    if sid: print(sid, title)
except Exception:
    pass
' 2>/dev/null
      )
      [ -n "${sid:-}" ] || continue
      [ -n "${title:-}" ] || title="(untitled)"
      printf '%s\tclaude\t%s\t%s\t%s\n' "$mtime" "$sid" "$project" "$title"
    done < <(find "$HOME/.claude/projects" -name '*.jsonl' -type f 2>/dev/null)
  fi

  # Codex
  if [ -f "$HOME/.codex/session_index.jsonl" ]; then
    python3 - <<'PY' 2>/dev/null
import json, os, time, pathlib
idx = pathlib.Path.home() / ".codex" / "session_index.jsonl"
for line in idx.read_text().splitlines():
    try:
        j = json.loads(line)
        sid = j.get("id","")
        title = (j.get("thread_name") or "").replace("\t"," ")[:80] or "(untitled)"
        ts = j.get("updated_at","")
        # Convert ISO8601 → epoch
        if ts:
            t = time.strptime(ts.split(".")[0].rstrip("Z"), "%Y-%m-%dT%H:%M:%S")
            mtime = int(time.mktime(t))
        else:
            mtime = 0
        # Codex doesn't store cwd in the index — leave blank, codex resume figures it out
        print(f"{mtime}\tcodex\t{sid}\t-\t{title}")
    except Exception:
        continue
PY
  fi
}

# ── Render rows for fzf ─────────────────────────────────────────
# Pretty form:
#   [claude] 3h ago    ~/d/terminal-mac-setup    Set up terminal tools
_render() {
  _list_sessions \
    | sort -rn \
    | head -50 \
    | while IFS=$'\t' read -r mtime tool sid project title; do
        local rel home_short
        rel="$(_relative_time "$mtime")"
        # Shorten ~/...
        home_short="${project/#$HOME/~}"
        # Build the visible line, then a hidden TAB-prefixed payload for parsing
        printf '%-9s %-10s %-45s %s\t%s\t%s\t%s\n' \
          "[$tool]" "$rel" "$home_short" "$title" \
          "$tool" "$sid" "$project"
      done
}

# ── Pick + respawn loop ─────────────────────────────────────────
SESSION="${TMUX_SESSION:-dashboard}"

_respawn_pane_with() {
  local tool="$1" sid="$2" project="$3"
  local target_var="${tool}_pane"
  local target
  target="$(tmux show-environment -t "$SESSION" "@${target_var}" 2>/dev/null \
            | sed -n "s/^@${target_var}=//p")"
  if [ -z "$target" ]; then
    echo "✗ Could not find @${target_var} in tmux env. Is the dashboard running?"
    return 1
  fi
  local cwd cmd
  cwd="${project:-$HOME}"
  [ "$cwd" = "-" ] && cwd="$HOME"   # codex: dir unknown
  case "$tool" in
    claude) cmd="claude --resume '$sid'" ;;
    codex)  cmd="codex resume '$sid'" ;;
    *)      echo "Unknown tool: $tool"; return 1 ;;
  esac
  tmux respawn-pane -k -c "$cwd" -t "$target" "$cmd"
}

clear
echo "Recent Claude + Codex sessions  ·  click or arrow+Enter to resume  ·  Ctrl-C to close"
echo

while :; do
  PICK="$(
    _render | fzf \
      --height=100% \
      --layout=reverse \
      --border=none \
      --prompt='resume › ' \
      --pointer='▶' \
      --info=inline \
      --color='fg:#c0caf5,bg:#1a1b26,hl:#7aa2f7,fg+:#c0caf5,bg+:#414868,hl+:#7dcfff,info:#bb9af7,prompt:#7aa2f7,pointer:#9ece6a,marker:#9ece6a' \
      --with-nth=1 \
      --delimiter=$'\t' \
      --no-multi \
      || true
  )"

  [ -z "$PICK" ] && { echo "(no selection — picker idle)"; sleep 1; clear; continue; }

  # Parse the hidden payload (fields 2,3,4 after the visible field)
  TOOL="$(    echo "$PICK" | awk -F'\t' '{print $2}')"
  SID="$(     echo "$PICK" | awk -F'\t' '{print $3}')"
  PROJECT="$( echo "$PICK" | awk -F'\t' '{print $4}')"

  printf '\033[1;36m▶\033[0m resuming [%s] %s in %s\n' "$TOOL" "$SID" "${PROJECT/#$HOME/~}"

  if ! _respawn_pane_with "$TOOL" "$SID" "$PROJECT"; then
    echo '⚠  ID-based resume failed; firing up the CLI'\''s built-in picker instead'
    case "$TOOL" in
      claude) tmux respawn-pane -k -c "${PROJECT:-$HOME}" -t "$(tmux show-environment -t "$SESSION" '@claude_pane' | cut -d= -f2)" "claude --resume" ;;
      codex)  tmux respawn-pane -k -c "${PROJECT:-$HOME}" -t "$(tmux show-environment -t "$SESSION" '@codex_pane'  | cut -d= -f2)" "codex resume --all" ;;
    esac
  fi
  sleep 0.6
done
