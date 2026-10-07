# Sourced from ~/.bashrc and ~/.zshrc by install.sh. Works in both shells.

# Local binaries (claude, gh helpers, pipx, etc.)
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Secrets stay out of the repo. ~/.secrets is mode 600 and holds
# lines like: export OPENAI_API_KEY=sk-...
[ -f "$HOME/.secrets" ] && . "$HOME/.secrets"

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias gs='git status -sb'
alias gl='git lg'
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tl='tmux ls'

# Keep tmux and git happy with a real editor.
export EDITOR=vim
export VISUAL=vim
