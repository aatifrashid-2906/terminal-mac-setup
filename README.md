# terminal-mac-setup

A one-shot installer for the "WEiRDEST Way to Use a Mac" terminal lineup
(inspired by [Dave2D's video](https://www.youtube.com/watch?v=0vFErGxD2QY))
on Apple Silicon Macs.

It installs every CLI tool from the lineup, drops opinionated default
configs into `~/.config`, and wires up zsh — all from a single
`install.sh`. Re-running is safe (idempotent).

```bash
git clone https://github.com/<you>/terminal-mac-setup.git
cd terminal-mac-setup
bash install.sh           # or: bash install.sh --dry-run
```

---

## What you get

| Tool                                                | What it is                              |
| --------------------------------------------------- | --------------------------------------- |
| [Homebrew](https://brew.sh)                         | Install programs from the terminal      |
| [Ghostty](https://ghostty.org)                      | Modern terminal emulator (Tokyo Night)  |
| [Yazi](https://yazi-rs.github.io)                   | File manager with image previews        |
| [Helix](https://helix-editor.com)                   | Modal text editor, no plugins needed    |
| [btop](https://github.com/aristocratos/btop)        | Resource monitor                        |
| [fastfetch](https://github.com/fastfetch-cli/fastfetch) | System info (`neofetch` successor)  |
| [kew](https://github.com/ravachol/kew)              | Music player                            |
| [Newsboat](https://newsboat.org)                    | RSS/Atom reader (pre-seeded with Reddit feeds) |
| [ticker](https://github.com/achannarasappa/ticker)  | Real-time stock prices                  |
| [wttr.in](https://github.com/chubin/wttr.in)        | Plain-text weather (`weather` function, defaults to Delhi) |
| [aichat](https://github.com/sigoden/aichat)         | LLM CLI (OpenAI by default)             |
| [chafa](https://hpjansson.org/chafa)                | Images → ANSI art                       |
| [circumflex](https://github.com/bensadeh/circumflex) | Hacker News in the terminal            |
| [mpv](https://mpv.io)                               | Full-featured media player (incl. terminal video via `--vo=tct`) |

Plus runtime deps: `ffmpeg`, `sevenzip`, `jq`, `poppler`, `fd`, `ripgrep`,
`fzf`, `zoxide`, `imagemagick`, `resvg`, JetBrainsMono Nerd Font.

---

## How it works

`install.sh` does five things, in order:

1. **Preflight** — verifies macOS arm64, installs Homebrew if missing.
2. **Detect Ghostty** — if `/Applications/Ghostty.app` already exists
   (e.g. you installed it from <https://ghostty.org>), the cask is
   skipped. Otherwise it's installed.
3. **Backup + install** — moves any existing `~/.config/{ghostty,helix,
   yazi,btop,fastfetch,newsboat,aichat}` to `~/.config/<tool>.bak.<ts>`,
   then runs `brew bundle --file=Brewfile`.
4. **Drop configs** — copies everything in `config/` into `~/.config/`.
5. **Wire `~/.zshrc`** — appends a guarded block (between `# >>>
   terminal-mac-setup >>>` markers) that adds:
   - `EDITOR=hx`, `VISUAL=hx`
   - `zoxide init zsh`
   - `fzf` keybindings (`^R`, `^T`)
   - `weather` function (defaults to **Delhi**)
   - `y` wrapper so the shell follows Yazi's last directory on quit

```bash
bash install.sh              # full install
bash install.sh --no-configs # brew packages only, leave dotfiles alone
bash install.sh --dry-run    # print actions, change nothing
```

---

## After install

Open a fresh Ghostty window and try:

```bash
fastfetch                              # system info
hx README.md                           # Helix (quit: ESC : q!)
y                                      # Yazi
btop                                   # resource monitor
weather                                # Delhi
weather london                         # any city
newsboat                               # press R to refresh
circumflex                             # Hacker News
ticker                                 # stocks (edit ~/.config/.ticker.yaml)
chafa some-image.jpg                   # ANSI art
mpv --vo=tct --really-quiet some.mp4   # video in the terminal
aichat                                 # set OPENAI_API_KEY first
```

### aichat

`aichat` reads `OPENAI_API_KEY` from the environment. Add to a private
file the repo doesn't track (e.g. `~/.zshrc.local`):

```bash
export OPENAI_API_KEY="sk-..."
```

Default model is `openai:gpt-4o`. Edit
`~/.config/aichat/config.yaml` to switch.

### Helix tutorial

```bash
hx --tutor
```

(Quit: `ESC` then `:q!` — memorize it or you will be memed.)

---

## Repo layout

```
terminal-mac-setup/
├── README.md
├── install.sh              # idempotent installer
├── uninstall.sh            # reverses install.sh
├── Brewfile                # brew bundle target
├── .gitignore
└── config/                 # copied to ~/.config/
    ├── ghostty/config
    ├── helix/{config.toml, languages.toml}
    ├── yazi/{yazi.toml, keymap.toml, theme.toml}
    ├── btop/btop.conf
    ├── fastfetch/config.jsonc
    ├── newsboat/{config, urls}
    └── aichat/config.yaml
```

---

## Uninstall

```bash
bash uninstall.sh
```

Removes the brew packages this setup introduced, restores the most recent
config backup for each tool, and strips the guarded block from
`~/.zshrc`. Does **not** uninstall Homebrew, fonts, Ghostty.app, or
shared deps (`ffmpeg`, `jq`, `fzf`, …).

---

## Credits

Inspired by [Dave2D — "The WEiRDEST Way to Use a Mac"](https://www.youtube.com/watch?v=0vFErGxD2QY).
