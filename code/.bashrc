#  ~/.bashrc — interactive shell config

# Bail out for non-interactive shells (scp, sftp, etc.)
[[ $- != *i* ]] && return

# Source global definitions (Debian/Ubuntu vs RHEL/CentOS)
[ -f /etc/bash.bashrc ] && . /etc/bash.bashrc
[ -f /etc/bashrc ]      && . /etc/bashrc


# ============================================================
# History
# ============================================================
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoredups:erasedups
HISTTIMEFORMAT='%F %T '
shopt -s histappend


# ============================================================
# Shell behavior
# ============================================================
shopt -s checkwinsize           # re-evaluate LINES/COLUMNS after each command
shopt -s globstar 2>/dev/null   # ** matches recursively
shopt -s nocaseglob             # case-insensitive globbing
shopt -s autocd   2>/dev/null   # bare dirname acts like cd


# ============================================================
# Environment
# ============================================================
export TERM=xterm-256color
export LANG=${LANG:-en_US.UTF-8}
export EDITOR=vim
export VISUAL=vim
export PAGER=less
export LESS='-R -i -j5'

# Prepend to PATH only if not already present
_add_path() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) [ -d "$1" ] && PATH="$1:$PATH" ;;
    esac
}
_add_path "$HOME/.local/bin"
_add_path "$HOME/bin"
unset -f _add_path


# ============================================================
# Prompt:  [HH:MM:SS] user@host:cwd (git-branch)$
# ============================================================
_git_branch() {
    local b
    b=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) \
        || b=$(git rev-parse --short HEAD 2>/dev/null) \
        || return
    printf ' (%s)' "$b"
}

if [ -t 1 ]; then
    PS1='\[\e[2m\][\t]\[\e[0m\] \[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[33m\]$(_git_branch)\[\e[0m\]\$ '
else
    PS1='[\t] \u@\h:\w\$ '
fi


# ============================================================
# Aliases
# ============================================================
# ls — use --color when GNU coreutils is available
if ls --color=auto >/dev/null 2>&1; then
    alias ls='ls --color=auto'
    alias ll='ls -lh --color=auto'
    alias la='ls -lah --color=auto'
else
    alias ll='ls -lh'
    alias la='ls -lah'
fi
alias grep='grep --color=auto'

# Safer file ops
alias cp='cp -i'
alias mv='mv -i'

# tmux
alias ta='tmux attach || tmux new'
alias window='tmux split-window -h; tmux split-window -v; tmux split-window -v; tmux split-window -h'

# Jupyter
alias jn="jupyter notebook --no-browser --ip='*'"

# GPU watcher — prefer nvtop when installed
if command -v nvtop >/dev/null 2>&1; then
    alias ns='nvtop'
else
    alias ns='watch -d -n 3 nvidia-smi'
fi

# Quick edits
alias vimrc='${EDITOR} ~/.vimrc'
alias bashrc='${EDITOR} ~/.bashrc'
alias reload='source ~/.bashrc'


# ============================================================
# Functions
# ============================================================
# Full LaTeX build:  tex main   (no .tex extension)
tex() {
    local f="${1%.tex}"
    pdflatex "$f" && bibtex "$f" && pdflatex "$f" && pdflatex "$f"
}

# Kill all processes holding NVIDIA GPU device files.
# (was an alias — broke because $2 was expanded by bash, not awk.)
gpu-killall() {
    local pids
    pids=$(lsof -t /dev/nvidia* 2>/dev/null | sort -u)
    if [ -z "$pids" ]; then
        echo "no GPU processes"
        return 0
    fi
    echo "killing: $pids"
    kill $pids
}

# mkdir + cd
mkcd() { mkdir -p "$1" && cd "$1"; }

# Universal archive extractor
extract() {
    [ -f "$1" ] || { echo "extract: '$1' not found" >&2; return 1; }
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz)   tar xzf "$1" ;;
        *.tar.xz)         tar xJf "$1" ;;
        *.tar)            tar xf  "$1" ;;
        *.zip)            unzip "$1" ;;
        *.gz)             gunzip "$1" ;;
        *.bz2)            bunzip2 "$1" ;;
        *.rar)            unrar x "$1" ;;
        *.7z)              7z x "$1" ;;
        *) echo "extract: don't know how to handle '$1'" >&2 ;;
    esac
}


# ============================================================
# Completions / integrations
# ============================================================
# bash-completion (Ubuntu/Debian)
if ! shopt -oq posix; then
    [ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion
    [ -f /etc/bash_completion ]                       && . /etc/bash_completion
fi

# fzf — key bindings & fuzzy completion when installed
[ -f ~/.fzf.bash ] && . ~/.fzf.bash


# ============================================================
# Machine-local overrides (not tracked in dotfiles)
# Put per-host JAVA_HOME / CUDA paths / proxy / API keys here.
# ============================================================
[ -f ~/.bashrc.local ] && . ~/.bashrc.local
