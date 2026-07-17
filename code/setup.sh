#!/bin/bash
# Usage: bash setup.sh   (or: source setup.sh)
# Works no matter where you invoke it from.
# Fault-tolerant: keep going even if individual steps fail.

# Resolve the directory this script lives in, so all source paths are absolute.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Detect package manager for installing vim / tmux / neovim
PM=""
PM_INSTALL=""
SUDO=""
[ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
if command -v apt-get >/dev/null 2>&1; then
    PM="apt-get"; PM_INSTALL="$SUDO apt-get install -y"
    $SUDO apt-get update -y >/dev/null 2>&1 || true
elif command -v dnf >/dev/null 2>&1; then
    PM="dnf"; PM_INSTALL="$SUDO dnf install -y"
elif command -v yum >/dev/null 2>&1; then
    PM="yum"; PM_INSTALL="$SUDO yum install -y"
elif command -v brew >/dev/null 2>&1; then
    PM="brew"; PM_INSTALL="brew install"
elif command -v pacman >/dev/null 2>&1; then
    PM="pacman"; PM_INSTALL="$SUDO pacman -S --noconfirm"
fi

ensure_pkg () {
    local cmd="$1" pkg="${2:-$1}"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    if [ -z "$PM_INSTALL" ]; then
        echo "[setup] '$cmd' missing and no known package manager; skip." >&2
        return 1
    fi
    echo "[setup] installing $pkg via $PM ..."
    $PM_INSTALL "$pkg" || echo "[setup] failed to install $pkg (continuing)" >&2
}

# Detect arch suffix used by neovim / tree-sitter release artifacts
case "$(uname -m)" in
    x86_64|amd64) NVIM_ARCH="x86_64"; TS_ARCH="x64" ;;
    aarch64|arm64) NVIM_ARCH="arm64";  TS_ARCH="arm64" ;;
    *) NVIM_ARCH=""; TS_ARCH="" ;;
esac

# Install latest Neovim from prebuilt tarball.
# (apt's neovim on Ubuntu 22.04 is 0.6, too old for lazy.nvim / vim.uv.)
install_nvim_tarball () {
    if [ -z "$NVIM_ARCH" ]; then
        echo "[setup] unknown arch for nvim tarball; skip" >&2
        return 1
    fi
    local url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz"
    local tmp
    tmp=$(mktemp -d) || return 1
    echo "[setup] downloading nvim from $url"
    if ! curl -fsSL -o "$tmp/nvim.tar.gz" "$url"; then
        echo "[setup] nvim download failed (continuing)" >&2
        rm -rf "$tmp"; return 1
    fi
    tar -C "$tmp" -xzf "$tmp/nvim.tar.gz" || {
        echo "[setup] nvim extract failed (continuing)" >&2
        rm -rf "$tmp"; return 1
    }
    local dir
    dir=$(find "$tmp" -maxdepth 1 -type d -name 'nvim-linux-*' | head -1)
    $SUDO rm -rf /opt/nvim
    $SUDO mv "$dir" /opt/nvim
    $SUDO ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
    rm -rf "$tmp"
    hash -r 2>/dev/null || true
}

# Install tree-sitter CLI (needed by nvim-treesitter for some parsers).
# npm's tree-sitter-cli needs newer glibc; use the GitHub prebuilt binary instead.
install_tree_sitter () {
    if command -v tree-sitter >/dev/null 2>&1; then return 0; fi
    if [ -z "$TS_ARCH" ]; then
        echo "[setup] unknown arch for tree-sitter; skip" >&2
        return 1
    fi
    local ver="v0.22.6"
    local url="https://github.com/tree-sitter/tree-sitter/releases/download/${ver}/tree-sitter-linux-${TS_ARCH}.gz"
    local tmp
    tmp=$(mktemp -d) || return 1
    echo "[setup] downloading tree-sitter from $url"
    if ! curl -fsSL -o "$tmp/ts.gz" "$url"; then
        echo "[setup] tree-sitter download failed (continuing)" >&2
        rm -rf "$tmp"; return 1
    fi
    gunzip -f "$tmp/ts.gz" || { rm -rf "$tmp"; return 1; }
    $SUDO install -m 0755 "$tmp/ts" /usr/local/bin/tree-sitter
    rm -rf "$tmp"
}

# Need vim / tmux from apt (or equivalent); nvim handled separately below.
ensure_pkg vim
ensure_pkg tmux
ensure_pkg unzip
ensure_pkg git
ensure_pkg curl

# Install GitHub CLI (gh). Package name differs from the command on some PMs;
# apt/yum need the official repo, so fall back to the upstream installer there.
install_gh () {
    if command -v gh >/dev/null 2>&1; then return 0; fi
    case "$PM" in
        brew|dnf|pacman)
            ensure_pkg gh ;;
        apt-get)
            echo "[setup] installing gh via official apt repo ..."
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                | $SUDO dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null \
                && $SUDO chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
                && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                    | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
                && $SUDO apt-get update -y >/dev/null 2>&1 \
                && $SUDO apt-get install -y gh \
                || echo "[setup] gh install failed (continuing)" >&2 ;;
        yum)
            $SUDO yum install -y 'dnf-command(config-manager)' >/dev/null 2>&1
            $SUDO yum config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo >/dev/null 2>&1 \
                && $SUDO yum install -y gh \
                || echo "[setup] gh install failed (continuing)" >&2 ;;
        *)
            echo "[setup] no known way to install gh on this system; skip" >&2 ;;
    esac
}
install_gh

# Install Neovim only if missing or too old (<0.10).
need_nvim_install=1
if command -v nvim >/dev/null 2>&1; then
    cur_ver=$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    cur_major=${cur_ver%.*}; cur_minor=${cur_ver#*.}
    if [ "${cur_major:-0}" -gt 0 ] || [ "${cur_minor:-0}" -ge 10 ]; then
        need_nvim_install=0
    fi
fi
[ "$need_nvim_install" = 1 ] && install_nvim_tarball

install_tree_sitter

# Setup ssh
mkdir -p ~/.ssh
cp "$SCRIPT_DIR/.ssh/authorized_keys" ~/.ssh/authorized_keys 2>/dev/null || \
    echo "[setup] skip ssh keys (source missing)" >&2
chmod 700 ~/.ssh
[ -f ~/.ssh/authorized_keys ] && chmod 600 ~/.ssh/authorized_keys

# Setup tmux
cp "$SCRIPT_DIR/.tmux.conf" ~/.tmux.conf 2>/dev/null || \
    echo "[setup] skip .tmux.conf (source missing)" >&2

# Setup bash
cp "$SCRIPT_DIR/.bashrc" ~/.bashrc 2>/dev/null || \
    echo "[setup] skip .bashrc (source missing)" >&2
source ~/.bashrc 2>/dev/null || true

# Setup Git
git config --global credential.helper store        # remember username/password
git config --global core.editor "vim"
git config --global core.autocrlf input    # Linux/Mac: keep LF in repo, never CRLF in working tree
git config --global user.name "Beibin Li"
git config --global user.email beibin79@gmail.com

# Setup Vim and vim-plug
cp "$SCRIPT_DIR/.vimrc" ~/.vimrc 2>/dev/null || \
    echo "[setup] skip .vimrc (source missing)" >&2
if [ ! -f ~/.vim/autoload/plug.vim ]; then
    mkdir -p ~/.vim/autoload
    curl -fLo ~/.vim/autoload/plug.vim \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
        || echo "[setup] vim-plug download failed (continuing)" >&2
fi
# Run non-interactively: stdin from /dev/null auto-dismisses vim's
# "Press ENTER or type command to continue" pager prompts so it never blocks.
command -v vim >/dev/null 2>&1 && (vim +'PlugInstall --sync' +qa </dev/null >/dev/null 2>&1 || true)

# Setup Neovim (lazy.nvim-based config from nvim.zip)
mkdir -p ~/.config
if [ -f "$SCRIPT_DIR/nvim.zip" ]; then
    if [ -d ~/.config/nvim ]; then
        mv ~/.config/nvim ~/.config/nvim.bak.$(date +%s) 2>/dev/null || true
    fi
    unzip -q "$SCRIPT_DIR/nvim.zip" -d ~/.config/ \
        || echo "[setup] nvim.zip extract failed (continuing)" >&2
    if command -v nvim >/dev/null 2>&1; then
        nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
    fi
else
    echo "[setup] skip nvim config (nvim.zip missing)" >&2
fi

# Setup uv (fast Python package manager)
if command -v pip >/dev/null 2>&1; then
    pip install uv || echo "[setup] uv install failed (continuing)" >&2
elif command -v pip3 >/dev/null 2>&1; then
    pip3 install uv || echo "[setup] uv install failed (continuing)" >&2
else
    echo "[setup] skip uv (pip missing)" >&2
fi

# Setup Claude Code (network call — tolerate failures)
if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://claude.ai/install.sh | bash \
        || echo "[setup] Claude Code install failed (continuing)" >&2
fi

# Setup OpenAI Codex (requires Node/npm)
if command -v npm >/dev/null 2>&1; then
    npm i -g @openai/codex \
        || echo "[setup] Codex install failed (continuing)" >&2
fi

# Setup Jupyter Notebook password
# jupyter notebook password

echo "[setup] done."
