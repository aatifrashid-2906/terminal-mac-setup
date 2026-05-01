#!/usr/bin/env bash
# uninstall.sh — reverse install.sh
#
# Removes the brew packages listed in Brewfile and restores the most
# recent backup for each config dir under ~/.config. Does NOT remove
# Homebrew itself, Ghostty.app, fonts, or shared deps that other apps
# may depend on (ffmpeg, jq, fzf, etc.) — those are left in place.

set -euo pipefail

say()  { printf '\033[1;36m▶\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# Tools introduced by this setup that are safe to uninstall.
# (We deliberately don't touch ffmpeg/jq/fzf/zoxide/fd/ripgrep/imagemagick
#  because you likely had/want them anyway.)
TOOLS=(helix yazi btop fastfetch kew newsboat achannarasappa/tap/ticker aichat chafa circumflex mpv sevenzip poppler resvg)

say "Uninstalling brew packages"
for t in "${TOOLS[@]}"; do
  if brew list --formula "$t" >/dev/null 2>&1; then
    brew uninstall --ignore-dependencies "$t" || warn "could not uninstall $t"
  fi
done
ok "Brew packages removed"

# Restore most recent backup for each tool config
say "Restoring config backups"
for tool in ghostty helix yazi btop fastfetch newsboat aichat; do
  dst="$CONFIG_DIR/$tool"
  latest_bak="$(ls -1dt "$dst".bak.* 2>/dev/null | head -1 || true)"
  [ -d "$dst" ] && rm -rf "$dst"
  if [ -n "$latest_bak" ] && [ -d "$latest_bak" ]; then
    mv "$latest_bak" "$dst"
    ok "  $tool ← $(basename "$latest_bak")"
  fi
done

# Strip our zshrc block
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ] && grep -qF "# >>> terminal-mac-setup >>>" "$ZSHRC"; then
  say "Removing shell wiring from ~/.zshrc"
  cp "$ZSHRC" "$ZSHRC.bak.$(date +%Y%m%d-%H%M%S)"
  awk '
    /# >>> terminal-mac-setup >>>/ { skip=1 }
    !skip
    /# <<< terminal-mac-setup <<</ { skip=0 }
  ' "$ZSHRC.bak."* > "$ZSHRC.new" 2>/dev/null && mv "$ZSHRC.new" "$ZSHRC" || warn "could not strip block; check $ZSHRC manually"
  ok "Shell wiring removed (backup left at $ZSHRC.bak.*)"
fi

ok "Uninstall complete. Open a new shell to pick up changes."
