#!/usr/bin/env bash
# Bootstrap a fresh Ubuntu/Debian machine (bare metal, VM, or WSL).
# Safe to re-run: every step checks before it acts.
#
#   curl -fsSL https://raw.githubusercontent.com/gian-g3dai/dotfiles/main/install.sh | bash
set -euo pipefail

# When piped through curl, stdin is the pipe. Reattach it to the terminal so
# prompts and the interactive logins at the end work.
if [ ! -t 0 ] && (exec < /dev/tty) 2>/dev/null; then
  exec < /dev/tty
fi

REPO_URL="https://github.com/gian-g3dai/dotfiles.git"
DOTFILES="$HOME/dotfiles"
GIT_NAME="gian-g3dai"
GIT_EMAIL="125449997+gian-g3dai@users.noreply.github.com"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m    %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- sanity
if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script targets Ubuntu/Debian (apt-get not found)." >&2
  exit 1
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
  $SUDO -v
fi

IS_WSL=false
if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
fi

export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------- apt
log "Installing base packages"
$SUDO apt-get update -qq
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  git tmux curl wget ca-certificates gnupg build-essential unzip vim >/dev/null
ok "git, tmux, curl, build-essential, vim"

# ---------------------------------------------------------------- gh cli
if command -v gh >/dev/null 2>&1; then
  ok "gh already installed"
else
  log "Installing GitHub CLI"
  $SUDO mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq gh >/dev/null
  ok "gh installed"
fi

# ---------------------------------------------------------------- claude code
if command -v claude >/dev/null 2>&1; then
  ok "claude already installed"
else
  log "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
  ok "claude installed"
fi

# ---------------------------------------------------------------- dotfiles repo
log "Syncing dotfiles repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/gitconfig" ] && [ -f "$SCRIPT_DIR/tmux.conf" ]; then
  DOTFILES="$SCRIPT_DIR"
  ok "running from $DOTFILES"
elif [ -d "$DOTFILES/.git" ]; then
  git -C "$DOTFILES" pull --ff-only -q
  ok "updated $DOTFILES"
else
  git clone -q "$REPO_URL" "$DOTFILES"
  ok "cloned to $DOTFILES"
fi

# ---------------------------------------------------------------- symlinks
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
    warn "backed up existing $dst"
  fi
  ln -sfn "$src" "$dst"
  ok "linked $dst"
}

log "Linking configs"
link "$DOTFILES/gitconfig"        "$HOME/.gitconfig"
link "$DOTFILES/tmux.conf"        "$HOME/.tmux.conf"
link "$DOTFILES/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# Claude Code rewrites settings.json itself, so copy once rather than link.
if [ ! -f "$HOME/.claude/settings.json" ]; then
  mkdir -p "$HOME/.claude"
  cp "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
  ok "seeded ~/.claude/settings.json"
fi

# ---------------------------------------------------------------- git identity
log "Git identity"
git config --file "$HOME/.gitconfig.local" user.name  "$GIT_NAME"
git config --file "$HOME/.gitconfig.local" user.email "$GIT_EMAIL"
ok "$GIT_NAME <$GIT_EMAIL>"

# ---------------------------------------------------------------- shell hook
log "Shell integration"
SOURCE_LINE='[ -f "$HOME/dotfiles/shell/dotfiles.sh" ] && . "$HOME/dotfiles/shell/dotfiles.sh"'
if [ "$DOTFILES" != "$HOME/dotfiles" ]; then
  SOURCE_LINE="[ -f \"$DOTFILES/shell/dotfiles.sh\" ] && . \"$DOTFILES/shell/dotfiles.sh\""
fi
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  if ! grep -Fq 'dotfiles/shell/dotfiles.sh' "$rc"; then
    printf '\n# dotfiles\n%s\n' "$SOURCE_LINE" >> "$rc"
    ok "hooked into $rc"
  fi
done

# ---------------------------------------------------------------- secrets
log "Secrets"
SECRETS="$HOME/.secrets"
if [ -f "$SECRETS" ] && grep -q '^export OPENAI_API_KEY=' "$SECRETS"; then
  ok "OPENAI_API_KEY already in ~/.secrets"
else
  printf '    Paste your OpenAI API key (input hidden, Enter to skip): '
  read -rs OPENAI_KEY || OPENAI_KEY=""
  echo
  if [ -n "$OPENAI_KEY" ]; then
    touch "$SECRETS"
    chmod 600 "$SECRETS"
    printf 'export OPENAI_API_KEY=%q\n' "$OPENAI_KEY" >> "$SECRETS"
    ok "saved to ~/.secrets (mode 600)"
  else
    warn "skipped; add 'export OPENAI_API_KEY=...' to ~/.secrets later"
  fi
fi

# ---------------------------------------------------------------- WSL / VS Code
if $IS_WSL; then
  log "WSL detected"
  if command -v code >/dev/null 2>&1; then
    ok "VS Code is reachable from WSL ('code .' works)"
  else
    warn "Install VS Code on Windows plus the 'WSL' extension,"
    warn "then open a new terminal and run 'code .' to finish the server install."
  fi
fi

# ---------------------------------------------------------------- logins
if [ "${DOTFILES_SKIP_LOGIN:-0}" = "1" ]; then
  log "Skipping logins (DOTFILES_SKIP_LOGIN=1)"
else
log "GitHub login"
if gh auth status >/dev/null 2>&1; then
  ok "already logged in"
else
  gh auth login --hostname github.com --web --git-protocol https
fi
gh auth setup-git >/dev/null 2>&1 || true
ok "git credential helper set to gh"

log "Claude Code login"
if [ -f "$HOME/.claude/.credentials.json" ]; then
  ok "already logged in"
else
  warn "Starting claude so you can sign in; type /exit when done."
  claude || true
fi
fi

# ---------------------------------------------------------------- done
log "Done"
echo "    Open a new shell (or run: source ~/.bashrc) to pick up PATH and secrets."
