# dotfiles

One-command setup for a fresh Ubuntu/Debian machine (bare metal, VM, or WSL).

```sh
curl -fsSL https://raw.githubusercontent.com/gian-g3dai/dotfiles/main/install.sh | bash
```

Safe to re-run. Every step checks before it acts.

## What it does

1. Installs git, tmux, curl, build-essential, vim via apt.
2. Installs the GitHub CLI (`gh`) from the official apt repo.
3. Installs Claude Code via the official installer.
4. Clones this repo to `~/dotfiles` and symlinks `gitconfig`, `tmux.conf`,
   and the global `~/.claude/CLAUDE.md`. Existing files are backed up as `*.bak.<timestamp>`.
5. Writes git identity to `~/.gitconfig.local` (included from `gitconfig`).
6. Hooks `shell/dotfiles.sh` into `~/.bashrc` and `~/.zshrc` for PATH, aliases, and secrets.
7. Prompts once for an OpenAI API key and stores it in `~/.secrets` (mode 600, never in git).
8. On WSL, checks that `code` is reachable and tells you what to install on Windows if not.
9. Runs `gh auth login` and the Claude Code sign-in if either is missing.

## Layout

```
install.sh          bootstrap script
gitconfig           shared git settings and aliases
tmux.conf           tmux settings
shell/dotfiles.sh   sourced by bash/zsh: PATH, aliases, loads ~/.secrets
claude/CLAUDE.md    global Claude Code instructions
claude/settings.json seed settings, copied once if none exist
```

## Secrets

`~/.secrets` is sourced on every shell start and is not tracked. Add more keys there:

```sh
export OPENAI_API_KEY=sk-...
```
