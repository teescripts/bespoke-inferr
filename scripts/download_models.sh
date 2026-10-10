#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_FILE="${MODELS_FILE:-$SCRIPT_DIR/../assets/sqlcoders.md}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
TEMP_DIR="/tmp/ollama_download"
MAX_RETRIES=3
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

log() { echo "[INFO] $1"; }
warn() { echo "[WARN] $1"; }
err() { echo "[ERROR] $1"; }

if ! curl -s "$OLLAMA_HOST/api/tags" >/dev/null 2>&1; then
    warn "Ollama not running. Starting..."
    ollama serve &>/dev/null &
    sleep 3
fi

get_expected_size() {
    local repo="$1"
    local filename="$2"
    
    local api_url="https://huggingface.co/api/models/$repo"
    local response
    response=$(curl -s "$api_url" 2>/dev/null)
    
    if echo "$response" | grep -q "siblings"; then
        local size
        size=$(echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for sibling in data.get('siblings', []):
        if sibling.get('rfilename') == '$filename':
            print(sibling.get('size', 0))
            break
except: pass
" 2>/dev/null)
        echo "$size"
    else
        echo "0"
    fi
}

verify_download() {
    local file="$1"
    local expected="$2"
    local filename="$3"
    
    if [ ! -f "$file" ]; then
        err "File not found: $file"
        return 1
    fi
    
    local actual
    actual=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    
    if [ "$actual" -lt 1000 ]; then
        err "File too small ($actual bytes) - likely an error page"
        cat "$file" 2>/dev/null
        rm -f "$file"
        return 1
    fi
    
    if [ "$expected" -gt 0 ] && [ "$actual" -ne "$expected" ]; then
        warn "Size mismatch: expected $expected bytes, got $actual bytes"
        warn "Difference: $((actual - expected)) bytes"
        rm -f "$file"
        return 1
    fi
    
    log "Size verified: $(numfmt --to=iec $actual 2>/dev/null || echo "$actual bytes")"
    return 0
}

download_hf() {
    local repo="$1"
    local filename="$2"
    local model_name
    model_name=$(echo "$repo" | sed 's|.*/||')
    
    if ollama show "$model_name" >/dev/null 2>&1; then
        log "Already installed: $model_name"
        return 0
    fi
    
    local output="$TEMP_DIR/$filename"
    
    log "Checking expected size for $repo/$filename..."
    local expected_size
    expected_size=$(get_expected_size "$repo" "$filename")
    
    if [ "$expected_size" -gt 0 ] 2>/dev/null; then
        log "Expected size: $(numfmt --to=iec $expected_size 2>/dev/null || echo "$expected_size bytes")"
    else
        warn "Could not determine expected size from API"
    fi
    
    local attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        log "Download attempt $attempt of $MAX_RETRIES..."
        
        if curl -L --progress-bar \
            "https://huggingface.co/$repo/resolve/main/$filename" \
            -o "$output"; then
            
            if verify_download "$output" "$expected_size" "$filename"; then
                log "Download completed successfully"
                break
            else
                warn "Verification failed, retrying..."
                rm -f "$output"
            fi
        else
            warn "Download failed, retrying..."
            rm -f "$output"
        fi
        
        attempt=$((attempt + 1))
        if [ $attempt -le $MAX_RETRIES ]; then
            log "Waiting 2 seconds before retry..."
            sleep 2
        fi
    done
    
    if [ $attempt -gt $MAX_RETRIES ]; then
        err "Failed to download after $MAX_RETRIES attempts: $repo"
        return 1
    fi
    
    log "Creating Ollama model: $model_name"
    cat > "$TEMP_DIR/Modelfile" << EOF
FROM $output
EOF
    
    if ollama create "$model_name" -f "$TEMP_DIR/Modelfile"; then
        log "Created: $model_name"
        rm -f "$output"
    else
        err "Failed to create: $model_name"
        return 1
    fi
}

echo ""
echo "========================================="
echo "  Ollama Model Downloader"
echo "========================================="
echo ""

count=0
fail=0

while IFS= read -r line; do
    line=$(echo "$line" | sed 's/#.*//' | xargs)
    [ -z "$line" ] && continue
    
    count=$((count + 1))
    echo "--- [$count] $line ---"
    
    if echo "$line" | grep -q "^hf:"; then
        rest=$(echo "$line" | sed 's/^hf://')
        repo=$(echo "$rest" | awk '{print $1}')
        filename=$(echo "$rest" | awk '{print $2}')
        download_hf "$repo" "$filename" || fail=$((fail + 1))
    else
        warn "Unknown format: $line"
        fail=$((fail + 1))
    fi
    echo ""
done < "$MODELS_FILE"

echo "========================================="
echo "  Done: $count processed, $fail failed"
echo "========================================="
ollama list
