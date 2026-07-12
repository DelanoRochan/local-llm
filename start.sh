#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
LLAMA_SERVER="$HOME/ai/bin/turboquant-current/llama-server"
LLAMA_HOST="127.0.0.1"
LLAMA_PORT="8080"
LLAMA_CTX=32768

# Default model (HuggingFace GGUF selector, e.g. "Qwen/Qwen3-VL-30B-A3B-Instruct-GGUF:Q4_K_M")
MODEL="${1:-}"

# ── Model → Claude alias mapping ───────────────────────────────────
resolve_alias() {
    local name="$1"
    # Strip the quantization suffix after ':' and the repo prefix before '/'
    local bare="${name#*/}"
    bare="${bare%%:*}"

    case "$bare" in
        Qwen3.6-27B*)              echo "qwen3.6-27b" ;;
        Qwen3-VL-30B-A3B*)         echo "qwen3-vl-30b-a3b" ;;
        Qwen3-VL-32B*)             echo "qwen3-vl-32b" ;;
        *)
            echo "Error: Unsupported model: $name" >&2
            echo "Supported patterns: Qwen3.6-27B, Qwen3-VL-30B-A3B, Qwen3-VL-32B" >&2
            exit 1
            ;;
    esac
}

# ── Process tracking ───────────────────────────────────────────────
LLAMA_PID=""
HEADROOM_PID=""

cleanup() {
    echo "" >&2
    echo "[start.sh] Shutting down..." >&2
    [[ -n "$HEADROOM_PID" ]] && kill "$HEADROOM_PID" 2>/dev/null && echo "  [stop] headroom/claude (PID $HEADROOM_PID)" >&2
    [[ -n "$LLAMA_PID" ]]    && kill "$LLAMA_PID"    2>/dev/null && echo "  [stop] llama-server (PID $LLAMA_PID)" >&2
    wait 2>/dev/null
    echo "[start.sh] Done." >&2
    exit 0
}

trap cleanup SIGINT SIGTERM

# ── Validation ─────────────────────────────────────────────────────
if [[ -z "$MODEL" ]]; then
    echo "Usage: $0 <hf-model>" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  $0 unsloth/Qwen3.6-27B-GGUF:Q5_K_XL" >&2
    echo "  $0 Qwen/Qwen3-VL-30B-A3B-Instruct-GGUF:Q4_K_M" >&2
    exit 1
fi

if [[ ! -x "$LLAMA_SERVER" ]]; then
    echo "Error: llama-server not found or not executable:" >&2
    echo "  $LLAMA_SERVER" >&2
    exit 1
fi

ALIAS=$(resolve_alias "$MODEL")
echo "[start.sh] Model: $MODEL  →  Alias: $ALIAS" >&2

# ── Start llama.cpp server ─────────────────────────────────────────
echo "[start.sh] Starting llama-server ..."
"$LLAMA_SERVER" --version

ARGS=(
    --hf-repo "${MODEL%%:*}"          # repo part before ':'
    --hf-file "${MODEL##*/}"          # filename (with quant suffix)
    --alias "$ALIAS"
    -ngl 999
    -c "$LLAMA_CTX"
    --parallel 1
    -b 2048
    -ub 1024
    -fa on
    --jinja
    --cache-type-k q8_0
    --cache-type-v turbo3
    -lv 1
    --host "$LLAMA_HOST"
    --port "$LLAMA_PORT"
)

"$LLAMA_SERVER" "${ARGS[@]}" &
LLAMA_PID=$!

# Wait for llama to be ready
echo "[start.sh] Waiting for llama-server on ${LLAMA_HOST}:${LLAMA_PORT} ..."
for i in $(seq 1 30); do
    if curl -sf "http://${LLAMA_HOST}:${LLAMA_PORT}/health" >/dev/null 2>&1; then
        echo "[start.sh] llama-server ready (PID $LLAMA_PID)" >&2
        break
    fi
    if ! kill -0 "$LLAMA_PID" 2>/dev/null; then
        echo "[start.sh] llama-server exited unexpectedly!" >&2
        exit 1
    fi
    sleep 1
done

# ── Start Headroom → Claude Code ───────────────────────────────────
export ANTHROPIC_TARGET_API_URL="http://${LLAMA_HOST}:${LLAMA_PORT}"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$ALIAS"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$ALIAS"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$ALIAS"
export ANTHROPIC_AUTH_TOKEN=local
unset ANTHROPIC_API_KEY

echo "[start.sh] Starting headroom/claude with alias $ALIAS ..."
headroom wrap claude -- \
    --model "$ALIAS" \
    --tools "Bash,Edit,Read,Write,Glob,Grep" \
    --disallowedTools "mcp__*" &
HEADROOM_PID=$!

echo "[start.sh] All running — llama($LLAMA_PID) headroom($HEADROOM_PID)" >&2

# ── Foreground wait ────────────────────────────────────────────────
# wait returns when the last background job exits; trap handles cleanup.
wait
