#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Checking Ollama installation..."
# Detect Ollama; if missing, offer to install (Windows: optional custom path),
# then continue here with the resolved binary path.
OLLAMA_BIN="$(bash "$SCRIPT_DIR/ensure_ollama.sh" || true)"

if [ -z "$OLLAMA_BIN" ] && ! curl -s http://localhost:11434/api/ps >/dev/null 2>&1; then
    echo "ERROR: Ollama is not installed and was not installed — cannot start." >&2
    echo "       See install instructions above or https://ollama.com/download" >&2
    exit 1
fi

if curl -s http://localhost:11434/api/ps >/dev/null 2>&1; then
    echo "Ollama is already running!"
    exit 0
fi

echo "Starting Ollama server..."
"$OLLAMA_BIN" serve &>/dev/null &

echo "Waiting for Ollama to be ready..."
for i in $(seq 1 30); do
    if curl -s http://localhost:11434/api/ps >/dev/null 2>&1; then
        echo "Ollama is ready!"
        exit 0
    fi
    sleep 1
done

echo "Warning: Ollama may still be starting up. The UI should connect shortly."
exit 0
