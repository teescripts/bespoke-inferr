#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Checking Ollama installation..."
# Detect Ollama; if missing, offer to install (Windows: optional custom path).
# Resolves to the binary path on stdout; we return here and continue either way.
OLLAMA_BIN="$(bash "$SCRIPT_DIR/ensure_ollama.sh" || true)"

if [ -n "$OLLAMA_BIN" ] || curl -s http://localhost:11434/api/ps >/dev/null 2>&1; then
    if ! curl -s http://localhost:11434/api/ps >/dev/null 2>&1; then
        echo "Starting Ollama server..."
        "$OLLAMA_BIN" serve &>/dev/null &

        echo "Waiting for Ollama to be ready..."
        for i in $(seq 1 30); do
            if curl -s http://localhost:11434/api/ps >/dev/null 2>&1; then
                echo "Ollama is ready!"
                break
            fi
            sleep 1
        done
    fi
else
    echo "WARNING: Ollama is not installed and was not installed — the UI will start but cannot talk to Ollama." >&2
    echo "         Re-run this script after installing, or see: https://ollama.com/download" >&2
fi

echo "Starting Python HTTP server on port 8080..."
cd "$SCRIPT_DIR/.."
python3 scripts/server.py &>/dev/null &

echo "Server starting at http://localhost:8080"
echo "Open your browser and navigate to http://localhost:8080"
