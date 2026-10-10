#!/bin/bash
# ensure_ollama.sh — detect Ollama, offer to install it, resolve its binary.
#
# Called by start_all.sh / start_ollama.sh before starting the server (and can
# be run standalone). After a successful install it re-detects and returns to
# the caller, which continues starting everything as usual.
#
# Contract:
#   stdout : absolute path to the ollama binary (empty when only the running
#            server was detected, i.e. no binary needed/known)
#   stderr : all prompts and messages
#   exit 0 : Ollama usable — server already running, or binary found/installed
#   exit 1 : not installed and not installed in this run (caller continues
#            with a warning, or aborts — its choice)
#
# Install flows:
#   macOS/Linux : official  curl -fsSL https://ollama.com/install.sh | sh
#                 (fixed location — no path selection possible)
#   Windows     : prompts for an install path (default
#                 %LOCALAPPDATA%\Programs\Ollama), then official
#                 install.ps1 with OLLAMA_INSTALL_DIR; falls back to
#                 OllamaSetup.exe /VERYSILENT /DIR=<path>; falls back to
#                 printed manual instructions.
#
# Test seams (also handy in CI / non-interactive runs):
#   OLLAMA_ASSUME_MISSING=1   pretend no ollama is installed
#   OLLAMA_INSTALL_DRY_RUN=1  print install commands instead of running them
#   OLLAMA_ASSUME_TTY=1       allow prompts even without a terminal
#   OLLAMA_FORCE_OS=windows|darwin|linux   override OS detection

set -eu

API_URL="http://127.0.0.1:11434/api/version"

msg() { printf '[ensure-ollama] %s\n' "$*" >&2; }

os_name() {
    if [ -n "${OLLAMA_FORCE_OS:-}" ]; then
        printf '%s\n' "$OLLAMA_FORCE_OS"
        return
    fi
    case "$(uname -s)" in
        Darwin)                    echo darwin ;;
        MINGW*|MSYS*|CYGWIN*|Windows_NT) echo windows ;;
        Linux)                     echo linux ;;
        *)                         echo other ;;
    esac
}

api_up() {
    curl -sf --max-time 2 "$API_URL" >/dev/null 2>&1
}

# Print the ollama binary path (first hit wins). Return 1 when not found.
find_ollama() {
    local c p
    local candidates=()

    # Explicit override: OLLAMA_BIN=/path/to/ollama
    [ -n "${OLLAMA_BIN:-}" ] && candidates+=("$OLLAMA_BIN")

    if p=$(command -v ollama 2>/dev/null); then
        candidates+=("$p")
    fi

    case "$(os_name)" in
        darwin)
            candidates+=(
                /usr/local/bin/ollama
                /opt/homebrew/bin/ollama
                /Applications/Ollama.app/Contents/Resources/ollama
                "$HOME/.local/bin/ollama"
            )
            ;;
        windows)
            # Git Bash/MSYS give Windows paths with backslashes — normalise
            # to forward slashes so test -x works.
            if [ -n "${LOCALAPPDATA:-}" ]; then
                local lad="${LOCALAPPDATA//\\//}"
                candidates+=("$lad/Programs/Ollama/ollama.exe")
            fi
            candidates+=(
                "/c/Program Files/Ollama/ollama.exe"
                "/c/Program Files (x86)/Ollama/ollama.exe"
            )
            ;;
        linux)
            candidates+=(
                /usr/local/bin/ollama
                /usr/bin/ollama
                "$HOME/.local/bin/ollama"
            )
            ;;
    esac

    for c in "${candidates[@]}"; do
        if [ -n "$c" ] && [ -x "$c" ]; then
            printf '%s\n' "$c"
            return 0
        fi
    done
    return 1
}

# ask "Question?" -> 0 = yes, 1 = no (default). Prompts on stderr.
ask() {
    local a=""
    if [ -t 0 ] || [ "${OLLAMA_ASSUME_TTY:-0}" = "1" ]; then
        printf '%s [y/N] ' "$1" >&2
        IFS= read -r a || a=""
    else
        return 1
    fi
    case "$a" in
        y|Y|yes|YES|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

# read_value "Prompt" -> echoes answer ("" on EOF)
read_value() {
    local a=""
    printf '%s' "$1" >&2
    IFS= read -r a || a=""
    printf '%s\n' "$a"
}

instructions() {
    case "$(os_name)" in
        windows)
            cat >&2 <<'EOF'
Manual install (Windows):
  Option A:  winget install Ollama.Ollama
  Option B:  download https://ollama.com/download/OllamaSetup.exe
             custom path:  OllamaSetup.exe /DIR="D:\some\location"
  Option C:  PowerShell (custom path):
             $env:OLLAMA_INSTALL_DIR="D:\Ollama"; iex (irm https://ollama.com/install.ps1)
  Then re-run this script — it will pick up the new installation.
EOF
            ;;
        darwin)
            cat >&2 <<'EOF'
Manual install (macOS):
  curl -fsSL https://ollama.com/install.sh | sh
  (or download the app from https://ollama.com/download)
  Note: the installer may ask for your password to link /usr/local/bin/ollama.
  Then re-run this script — it will pick up the new installation.
EOF
            ;;
        *)
            cat >&2 <<'EOF'
Manual install (Linux):
  curl -fsSL https://ollama.com/install.sh | sh
  (or see https://docs.ollama.com for package-manager installs)
  Then re-run this script — it will pick up the new installation.
EOF
            ;;
    esac
}

install_unix() {
    if ! ask "Ollama is not installed. Install it now?"; then
        msg "Installation declined."
        instructions
        return 1
    fi
    if [ "${OLLAMA_INSTALL_DRY_RUN:-0}" = "1" ]; then
        msg "[dry-run] would run: curl -fsSL https://ollama.com/install.sh | sh"
        return 0
    fi
    msg "Running official installer (may prompt for your password on macOS)..."
    if ! curl -fsSL https://ollama.com/install.sh | sh; then
        msg "Installer failed."
        instructions
        return 1
    fi
    return 0
}

install_windows() {
    if ! ask "Ollama is not installed. Install it now?"; then
        msg "Installation declined."
        instructions
        return 1
    fi

    # Custom install path is only relevant on Windows (macOS/Linux installers
    # use fixed locations). Default = per-user dir, no admin rights needed.
    local default_dir="C:\\Users\\${USERNAME:-$USER}\\AppData\\Local\\Programs\\Ollama"
    [ -n "${LOCALAPPDATA:-}" ] && default_dir="${LOCALAPPDATA}\\Programs\\Ollama"
    local dir
    dir=$(read_value "Install path [$default_dir]: ")
    [ -z "$dir" ] && dir="$default_dir"

    if [ "${OLLAMA_INSTALL_DRY_RUN:-0}" = "1" ]; then
        msg "[dry-run] would run (PowerShell):"
        msg "  \$env:OLLAMA_INSTALL_DIR='$dir'; iex (irm https://ollama.com/install.ps1)"
        msg "[dry-run] fallback would run (Git Bash):"
        msg "  MSYS2_ARG_CONV_EXCL='*' OllamaSetup.exe /VERYSILENT /NORESTART /SUPPRESSMSGBOXES /DIR=\"$dir\""
        return 0
    fi

    # Preferred: official install.ps1 with the chosen directory.
    local ps
    ps=$(command -v powershell.exe 2>/dev/null || command -v powershell 2>/dev/null || true)
    if [ -n "$ps" ]; then
        msg "Installing Ollama to $dir (official install.ps1)..."
        if "$ps" -NoProfile -ExecutionPolicy Bypass -Command \
            "\$env:OLLAMA_INSTALL_DIR='$dir'; iex (irm https://ollama.com/install.ps1)"; then
            return 0
        fi
        msg "install.ps1 failed — trying OllamaSetup.exe directly..."
    fi

    # Fallback: download the setup exe and run it silently with /DIR.
    local setup tmp
    tmp=$(mktemp -d 2>/dev/null || echo /tmp)
    setup="$tmp/OllamaSetup.exe"
    msg "Downloading OllamaSetup.exe (large download)..."
    if curl -fL --progress-bar -o "$setup" "https://ollama.com/download/OllamaSetup.exe"; then
        msg "Running silent installer to $dir..."
        # MSYS2_ARG_CONV_EXCL stops Git Bash rewriting /VERYSILENT into a path.
        if MSYS2_ARG_CONV_EXCL='*' "$setup" //VERYSILENT //NORESTART //SUPPRESSMSGBOXES "//DIR=$dir"; then
            rm -f "$setup"
            return 0
        fi
        rm -f "$setup"
    fi

    msg "Automatic install failed."
    instructions
    return 1
}

main() {
    if [ "${OLLAMA_ASSUME_MISSING:-0}" != "1" ]; then
        if api_up; then
            msg "Ollama server already running at 127.0.0.1:11434."
            printf '\n'
            exit 0
        fi
        if bin=$(find_ollama); then
            msg "Ollama found: $bin"
            printf '%s\n' "$bin"
            exit 0
        fi
    fi

    msg "Ollama does not appear to be installed."

    case "$(os_name)" in
        windows) install_windows || exit 1 ;;
        darwin|linux) install_unix || exit 1 ;;
        *)
            msg "Unsupported OS for automatic install."
            instructions
            exit 1
            ;;
    esac

    # Install attempted — verify and return to the caller.
    if api_up; then
        msg "Ollama server is up."
        printf '\n'
        exit 0
    fi
    if bin=$(find_ollama); then
        msg "Ollama installed: $bin"
        printf '%s\n' "$bin"
        exit 0
    fi

    msg "Install finished but ollama is still not detectable (PATH not refreshed?)."
    instructions
    exit 1
}

main "$@"
