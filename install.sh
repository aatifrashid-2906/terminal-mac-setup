#!/usr/bin/env bash
# install.sh — terminal-first Mac setup (Dave2D-style)
#
# Usage:
#   bash install.sh              # install everything + drop configs + wire shell
#   bash install.sh --no-configs # install brew packages only
#   bash install.sh --dry-run    # print actions, change nothing

set -euo pipefail

# ── flags ────────────────────────────────────────────────────────────
DRY_RUN=0
NO_CONFIGS=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=1 ;;
    --no-configs) NO_CONFIGS=1 ;;
    -h|--help)
      sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

# ── helpers ──────────────────────────────────────────────────────────
say()   { printf '\033[1;36m▶\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m!\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }
run()   {
  if [ "$DRY_RUN" = 1 ]; then
    printf '\033[2m  $ %s\033[0m\n' "$*"
  else
    eval "$@"
  fi
}

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# ── preflight ────────────────────────────────────────────────────────
say "Preflight checks"
if [ "$(uname)" != "Darwin" ]; then
  err "macOS only. You're on $(uname)."
  exit 1
fi
if [ "$(uname -m)" != "arm64" ]; then
  warn "Expected Apple Silicon (arm64). You're on $(uname -m). Continuing anyway."
fi

if ! command -v brew >/dev/null 2>&1; then
  say "Homebrew not found — installing"
  run '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
ok "Homebrew $(brew --version | head -1)"

# ── Ghostty: detect existing install ─────────────────────────────────
GHOSTTY_BREWFILE="$REPO_DIR/Brewfile.ghostty"
if [ -d "/Applications/Ghostty.app" ]; then
  ok "Ghostty already installed at /Applications/Ghostty.app — skipping cask"
  rm -f "$GHOSTTY_BREWFILE"
else
  say "Ghostty not found — adding cask to install set"
  echo 'cask "ghostty"' > "$GHOSTTY_BREWFILE"
fi

# ── brew bundle ──────────────────────────────────────────────────────
say "brew update"
run "brew update"

say "Installing packages from Brewfile"
run "brew bundle --file='$REPO_DIR/Brewfile'"
if [ -f "$GHOSTTY_BREWFILE" ]; then
  run "brew bundle --file='$GHOSTTY_BREWFILE'"
  rm -f "$GHOSTTY_BREWFILE"
fi
ok "Packages installed"

# ── configs ──────────────────────────────────────────────────────────
if [ "$NO_CONFIGS" = 1 ]; then
  warn "--no-configs: skipping config copy and shell wiring"
else
  say "Backing up existing configs (if any)"
  for tool in ghostty helix yazi btop fastfetch newsboat aichat tmux; do
    src="$REPO_DIR/config/$tool"
    dst="$CONFIG_DIR/$tool"
    [ -d "$src" ] || continue
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      bak="$dst.bak.$TS"
      run "mv '$dst' '$bak'"
      ok "  $tool → backed up to $bak"
    fi
    run "mkdir -p '$CONFIG_DIR'"
    run "cp -R '$src' '$dst'"
    ok "  $tool config installed"
  done

  # Single-file: starship.toml
  if [ -f "$REPO_DIR/config/starship.toml" ]; then
    if [ -e "$CONFIG_DIR/starship.toml" ]; then
      run "mv '$CONFIG_DIR/starship.toml' '$CONFIG_DIR/starship.toml.bak.$TS'"
      ok "  starship.toml → backed up"
    fi
    run "mkdir -p '$CONFIG_DIR'"
    run "cp '$REPO_DIR/config/starship.toml' '$CONFIG_DIR/starship.toml'"
    ok "  starship.toml installed"
  fi

  # Single-file: ticker config (~/.ticker.yaml — ticker's default path)
  if [ -f "$REPO_DIR/config/ticker.yaml" ]; then
    if [ -e "$HOME/.ticker.yaml" ]; then
      run "mv '$HOME/.ticker.yaml' '$HOME/.ticker.yaml.bak.$TS'"
      ok "  ~/.ticker.yaml → backed up"
    fi
    run "cp '$REPO_DIR/config/ticker.yaml' '$HOME/.ticker.yaml'"
    ok "  ~/.ticker.yaml installed (edit watchlist)"
  fi

  # Launcher / dashboard / sessions scripts → ~/.local/bin
  if [ -d "$REPO_DIR/scripts" ]; then
    run "mkdir -p '$HOME/.local/bin'"
    [ -f "$REPO_DIR/scripts/launcher.sh" ] && \
      run "install -m 0755 '$REPO_DIR/scripts/launcher.sh' '$HOME/.local/bin/tms-launcher'" && \
      ok "  tms-launcher installed (Ghostty startup dir picker)"
    [ -f "$REPO_DIR/scripts/dashboard.sh" ] && \
      run "install -m 0755 '$REPO_DIR/scripts/dashboard.sh' '$HOME/.local/bin/tms-dashboard'" && \
      ok "  tms-dashboard installed"
    [ -f "$REPO_DIR/scripts/sessions.sh" ] && \
      run "install -m 0755 '$REPO_DIR/scripts/sessions.sh' '$HOME/.local/bin/tms-sessions'" && \
      ok "  tms-sessions installed (recent Claude/Codex picker)"
  fi

  # ── shell wiring (zsh) ──────────────────────────────────────────────
  ZSHRC="$HOME/.zshrc"
  MARKER_BEGIN="# >>> terminal-mac-setup >>>"
  MARKER_END="# <<< terminal-mac-setup <<<"
  if [ -f "$ZSHRC" ] && grep -qF "$MARKER_BEGIN" "$ZSHRC"; then
    ok "Shell wiring already present in ~/.zshrc — skipping"
  else
    say "Appending shell wiring to ~/.zshrc"
    if [ "$DRY_RUN" = 1 ]; then
      printf '\033[2m  (would append guarded block to %s)\033[0m\n' "$ZSHRC"
    else
      cat >> "$ZSHRC" <<'EOF'

# >>> terminal-mac-setup >>>
# Added by terminal-mac-setup install.sh
export EDITOR=hx
export VISUAL=hx

# zoxide: smart cd
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# starship: prompt
command -v starship >/dev/null && eval "$(starship init zsh)"

# dashboard: tmux dashboard with 3 AI chats + btop
alias dashboard="$HOME/.local/bin/tms-dashboard"

# Quick web nav (open in default browser)
# Override Jira URL by exporting JIRA_URL in ~/.zshrc.local
alias jira='open "${JIRA_URL:-https://www.atlassian.com/software/jira}"'
alias mail='open https://mail.google.com'
alias gcal='open https://calendar.google.com'   # google calendar
alias gmail='open https://mail.google.com'      # alias of mail

# fzf keybindings (^R history, ^T file picker)
[ -f "$(brew --prefix 2>/dev/null)/opt/fzf/shell/key-bindings.zsh" ] && \
  source "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh"
[ -f "$(brew --prefix 2>/dev/null)/opt/fzf/shell/completion.zsh" ] && \
  source "$(brew --prefix)/opt/fzf/shell/completion.zsh"

# Plain-text weather (defaults to Delhi)
weather() { curl -s "wttr.in/${1:-Delhi}"; }

# Yazi: cd into the directory yazi was last in on quit
y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp" 2>/dev/null || true
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}
# <<< terminal-mac-setup <<<
EOF
      ok "Shell wiring appended"
    fi
  fi
fi

# ── done ─────────────────────────────────────────────────────────────
cat <<'EOF'

────────────────────────────────────────────────────────────
✓ Done. Try this:

  1. Open a new Ghostty window (or `source ~/.zshrc` in this one).
  2. fastfetch                          # system info
  3. hx README.md                       # text editor (quit: ESC : q!)
  4. y                                  # Yazi (quits with q, cd-follows)
  5. btop                               # resource monitor
  6. weather                            # wttr.in for Delhi
  7. aichat                             # add OPENAI_API_KEY first
  8. clx                                # Hacker News (circumflex)
  9. ticker                             # stocks (edit ~/.config/.ticker.yaml)
 10. mpv --vo=tct --really-quiet FILE   # video in the terminal
────────────────────────────────────────────────────────────
EOF
