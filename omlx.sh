#!/bin/bash
# omlx.sh - Claude Code → Headroom → omlx
#
# omlx exposes a native Anthropic-compatible endpoint (/v1/messages), so
# `headroom wrap claude` can point its own internal proxy directly at omlx —
# no extra translation hop needed.
#
# Data flow:
#   Claude Code → headroom wrap claude (internal proxy) → ANTHROPIC_TARGET_API_URL → omlx :8100
#
# Two-tier setup: Claude Code's "Sonnet" tier is the primary interactive
# model (reasoning + vision); its "Opus" tier is what Claude Code
# automatically switches to for planning/Task-subagent work — pointing that
# at a leaner, non-reasoning coder model keeps planning fast.
#
# Usage:
#   ./omlx.sh                              # both tiers use their defaults below
#   ./omlx.sh <sonnet-model>                # override sonnet, keep opus default
#   ./omlx.sh <sonnet-model> <opus-model>   # override both

set -euo pipefail

# ── Self-install: make this script runnable from any directory ────────────
# Resolves the real file path even when invoked through a symlink, then
# ensures ~/.local/bin/omlx-claude points at it — idempotent, silent after
# the first run.
_src="${BASH_SOURCE[0]}"
while [[ -h "$_src" ]]; do
    _dir="$(cd -P "$(dirname "$_src")" && pwd)"
    _src="$(readlink "$_src")"
    [[ "$_src" != /* ]] && _src="$_dir/$_src"
done
SELF_PATH="$(cd -P "$(dirname "$_src")" && pwd)/$(basename "$_src")"

LOCAL_BIN="$HOME/.local/bin"
SYMLINK_PATH="$LOCAL_BIN/omlx-claude"
if [[ ! -e "$SYMLINK_PATH" || "$(readlink "$SYMLINK_PATH" 2>/dev/null)" != "$SELF_PATH" ]]; then
    mkdir -p "$LOCAL_BIN"
    ln -sf "$SELF_PATH" "$SYMLINK_PATH"
    echo "  ✓ installed 'omlx-claude' → $SELF_PATH (run it from any directory)"
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        echo "  ⚠️  $LOCAL_BIN is not on your PATH — add this to your shell rc:"
        echo "     export PATH=\"$LOCAL_BIN:\$PATH\""
    fi
fi

OMLX_PORT=8100
OMLX_MODEL_DIR="${OMLX_MODEL_DIR:-$HOME/.lmstudio/models}"
# Sonnet tier: primary interactive model — reasoning + vision (vlm engine).
SONNET_DEFAULT_MODEL="lmstudio-community/Qwen3.6-35B-A3B-MLX-6bit"
# Opus tier: Claude Code's planning/Task-subagent model — fast coder, no
# reasoning/vision (plain llm engine).
OPUS_DEFAULT_MODEL="lmstudio-community/Qwen3-Coder-Next-MLX-6bit"
OMLX_API_KEY="${OMLX_API_KEY:-sk-omlx-test}"
PID_DIR="/tmp/omlx-headroom-pids"
mkdir -p "$PID_DIR"

SONNET_MODEL="${1:-}"
OPUS_MODEL="${2:-}"
OMLX_PID=""
HEADROOM_WRAP_PID=""

# ── Helpers ──────────────────────────────────────────────────────────────────
cleanup() {
    echo -e "\n\033[1;33mShutting down...\033[0m"
    [[ -n "$HEADROOM_WRAP_PID" ]] && kill "$HEADROOM_WRAP_PID" 2>/dev/null && echo "  killed headroom wrap claude"
    [[ -n "$OMLX_PID" ]]           && kill "$OMLX_PID" 2>/dev/null && echo "  killed omlx serve"
    wait 2>/dev/null
    rm -f "$PID_DIR"/*.pid 2>/dev/null || true
    echo "Done."
}
trap cleanup EXIT INT TERM

wait_ready() {
    local url="$1" label="$2" max="${3:-60}"
    for i in $(seq 1 "$max"); do
        if curl -sf "$url" > /dev/null 2>&1; then
            echo "  ✓ $label ready"
            return 0
        fi
        sleep 1
    done
    echo "  ✗ $label timed out after ${max}s"
    return 1
}

discover_model() {
    local preferred="$1"
    if [[ -d "$OMLX_MODEL_DIR/$preferred" ]]; then
        echo "$preferred"
        return
    fi
    if [[ -d "$OMLX_MODEL_DIR" ]]; then
        find "$OMLX_MODEL_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | head -1
    fi
}

# omlx's OpenAI-model-id list only reflects directories present at server
# start; if a model isn't found, trigger a rescan once and retry before
# giving up (handles models added to ~/.lmstudio/models after omlx started).
model_known_to_omlx() {
    local id="$1"
    local bare="${id##*/}"
    curl -s "http://127.0.0.1:$OMLX_PORT/v1/models" | python3 -c "
import json,sys
d = json.load(sys.stdin)
sys.exit(0 if any(m['id'] == '$bare' for m in d['data']) else 1)
" 2>/dev/null
}

ensure_model_known() {
    local id="$1"
    if model_known_to_omlx "$id"; then
        return 0
    fi
    echo "  Model '$id' not yet known to omlx — rescanning model directories ..."
    curl -s -X POST "http://127.0.0.1:$OMLX_PORT/admin/api/reload" \
        -H "x-api-key: $OMLX_API_KEY" >/dev/null 2>&1 || true
    sleep 1
    model_known_to_omlx "$id"
}

echo "═══════════════════════════════════════════════════════════"
echo "  omlx.sh — Claude Code → Headroom → omlx"
echo "═══════════════════════════════════════════════════════════"

if ! command -v omlx &>/dev/null; then
    echo "❌ omlx not found in PATH. Install via: brew install omlx"
    exit 1
fi

# ── Step 1: ensure omlx is running ──────────────────────────────────────────
if curl -sf --max-time 1 "http://127.0.0.1:$OMLX_PORT/health" >/dev/null 2>&1; then
    echo "  ✓ omlx already running on port $OMLX_PORT"
else
    echo "  Starting omlx serve on port $OMLX_PORT (models: $OMLX_MODEL_DIR) ..."
    nohup omlx serve --model-dir "$OMLX_MODEL_DIR" --port "$OMLX_PORT" > "$PID_DIR/omlx.log" 2>&1 &
    OMLX_PID=$!
    echo "$OMLX_PID" > "$PID_DIR/omlx.pid"
    if ! wait_ready "http://127.0.0.1:$OMLX_PORT/health" "omlx"; then
        echo "  ✗ omlx failed to start — see $PID_DIR/omlx.log"
        tail -n 20 "$PID_DIR/omlx.log" 2>/dev/null
        exit 1
    fi
fi

# ── Step 2: pick sonnet + opus models ────────────────────────────────────────
[[ -z "$SONNET_MODEL" ]] && SONNET_MODEL="$(discover_model "$SONNET_DEFAULT_MODEL")"
if [[ -z "$SONNET_MODEL" ]]; then
    echo "❌ No model found in $OMLX_MODEL_DIR"
    exit 1
fi
if [[ -z "$OPUS_MODEL" ]]; then
    if [[ -d "$OMLX_MODEL_DIR/$OPUS_DEFAULT_MODEL" ]]; then
        OPUS_MODEL="$OPUS_DEFAULT_MODEL"
    else
        echo "  ⚠️  Opus default ($OPUS_DEFAULT_MODEL) not found — falling back to sonnet model for opus tier too"
        OPUS_MODEL="$SONNET_MODEL"
    fi
fi

if ! ensure_model_known "$SONNET_MODEL"; then
    echo "❌ Sonnet model '$SONNET_MODEL' not recognized by omlx."
    curl -s "http://127.0.0.1:$OMLX_PORT/v1/models" | python3 -c "import json,sys; [print('   -', m['id']) for m in json.load(sys.stdin)['data']]" 2>/dev/null
    exit 1
fi
if ! ensure_model_known "$OPUS_MODEL"; then
    echo "❌ Opus model '$OPUS_MODEL' not recognized by omlx."
    curl -s "http://127.0.0.1:$OMLX_PORT/v1/models" | python3 -c "import json,sys; [print('   -', m['id']) for m in json.load(sys.stdin)['data']]" 2>/dev/null
    exit 1
fi

echo "  Sonnet (primary, reasoning+vision): $SONNET_MODEL"
echo "  Opus   (planning/Task subagents):   $OPUS_MODEL"

# ── Step 3: launch Claude Code through headroom, straight to omlx ──────────
export ANTHROPIC_TARGET_API_URL="http://127.0.0.1:$OMLX_PORT"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$SONNET_MODEL"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$OPUS_MODEL"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$OPUS_MODEL"
export ANTHROPIC_AUTH_TOKEN="$OMLX_API_KEY"
unset ANTHROPIC_API_KEY

echo ""
echo -e "  \033[1;32m✅ Data flow active:\033[0m"
echo "     Claude Code (sonnet: $SONNET_MODEL)"
echo "       ↓ headroom wrap claude (internal proxy)"
echo "       ↓ ANTHROPIC_TARGET_API_URL=$ANTHROPIC_TARGET_API_URL"
echo "       ↓ omlx serve :$OMLX_PORT"
echo "     Planning/Task subagents auto-switch to opus: $OPUS_MODEL"
echo ""
echo "Press Ctrl+C to stop everything."
echo ""

headroom wrap claude -- --verbose --model "$SONNET_MODEL" \
    --tools "Bash,Edit,Read,Write,Glob,Grep" \
    --disallowedTools "mcp__*" &
HEADROOM_WRAP_PID=$!
echo "$HEADROOM_WRAP_PID" > "$PID_DIR/headroom-wrap.pid"

wait "$HEADROOM_WRAP_PID" 2>/dev/null
HEADROOM_WRAP_PID=""
