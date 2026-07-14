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
# Usage:
#   ./omlx.sh                 # auto-discover model from ~/.lmstudio/models
#   ./omlx.sh <model-id>       # use an explicit model id

set -euo pipefail

OMLX_PORT=8100
OMLX_MODEL_DIR="${OMLX_MODEL_DIR:-$HOME/.lmstudio/models}"
OMLX_DEFAULT_MODEL="lmstudio-community/Qwen3.6-35B-A3B-MLX-6bit"
OMLX_API_KEY="${OMLX_API_KEY:-sk-omlx-test}"
PID_DIR="/tmp/omlx-headroom-pids"
mkdir -p "$PID_DIR"

MODEL="${1:-}"
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
    if [[ -d "$OMLX_MODEL_DIR/$OMLX_DEFAULT_MODEL" ]]; then
        echo "$OMLX_DEFAULT_MODEL"
        return
    fi
    if [[ -d "$OMLX_MODEL_DIR" ]]; then
        find "$OMLX_MODEL_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | head -1
    fi
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

# ── Step 2: pick a model ─────────────────────────────────────────────────────
[[ -z "$MODEL" ]] && MODEL="$(discover_model)"
if [[ -z "$MODEL" ]]; then
    echo "❌ No model found in $OMLX_MODEL_DIR"
    exit 1
fi
echo "  Model: $MODEL"

# ── Step 3: launch Claude Code through headroom, straight to omlx ──────────
export ANTHROPIC_TARGET_API_URL="http://127.0.0.1:$OMLX_PORT"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$MODEL"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$MODEL"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$MODEL"
export ANTHROPIC_AUTH_TOKEN="$OMLX_API_KEY"
unset ANTHROPIC_API_KEY

echo ""
echo -e "  \033[1;32m✅ Data flow active:\033[0m"
echo "     Claude Code"
echo "       ↓ headroom wrap claude (internal proxy)"
echo "       ↓ ANTHROPIC_TARGET_API_URL=$ANTHROPIC_TARGET_API_URL"
echo "       ↓ omlx serve :$OMLX_PORT  [$MODEL]"
echo ""
echo "Press Ctrl+C to stop everything."
echo ""

headroom wrap claude -- --verbose --model "$MODEL" \
    --tools "Bash,Edit,Read,Write,Glob,Grep" \
    --disallowedTools "mcp__*" &
HEADROOM_WRAP_PID=$!
echo "$HEADROOM_WRAP_PID" > "$PID_DIR/headroom-wrap.pid"

wait "$HEADROOM_WRAP_PID" 2>/dev/null
HEADROOM_WRAP_PID=""
