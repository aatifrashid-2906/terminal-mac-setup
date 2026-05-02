# Brewfile — terminal-first Mac setup (Dave2D-style)
# Run with: brew bundle --file=Brewfile
# Re-running is a no-op for already-installed packages.

# ── Core terminal stack ──────────────────────────────────────────────
# Ghostty cask is added conditionally by install.sh (skipped if
# /Applications/Ghostty.app already exists). It's commented here so
# `brew bundle` works standalone too.
# cask "ghostty"

brew "helix"            # text editor
brew "yazi"             # file manager
brew "starship"         # cross-shell prompt
brew "tmux"             # terminal multiplexer (powers `dashboard`)
brew "gemini-cli"       # Google Gemini CLI  (`gemini`)
cask "codex"            # OpenAI Codex CLI    (`codex`)
# Note: `claude` (Anthropic Claude Code CLI) is installed separately via
# https://docs.anthropic.com/en/docs/claude-code/quickstart  — not in brew yet.

# ── Yazi runtime deps for previews ───────────────────────────────────
brew "ffmpeg"           # video thumbnails
brew "sevenzip"         # archive previews
brew "jq"               # json
brew "poppler"          # pdf
brew "fd"               # fast find
brew "ripgrep"          # fast grep
brew "fzf"              # fuzzy picker
brew "zoxide"           # smart cd
brew "imagemagick"      # raster image previews
brew "resvg"            # svg previews

# ── System / fun ─────────────────────────────────────────────────────
brew "btop"             # resource monitor
brew "fastfetch"        # system info
brew "kew"              # music player
brew "newsboat"         # rss/atom reader
tap  "achannarasappa/tap"
brew "achannarasappa/tap/ticker"  # stock prices

# ── Apps ─────────────────────────────────────────────────────────────
brew "aichat"           # multi-LLM CLI (OpenAI/Claude/Gemini/Ollama)
brew "chafa"            # image → ANSI art
brew "circumflex"       # Hacker News TUI
brew "mpv"              # media player (use --vo=tct for terminal video)

# ── Fonts ────────────────────────────────────────────────────────────
cask "font-jetbrains-mono-nerd-font"
cask "font-symbols-only-nerd-font"
