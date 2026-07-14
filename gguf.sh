#!/bin/bash
# gguf.sh - Claude Code → Headroom → llama.cpp (GGUF + turbo2)
#
# Starts llama-server from the TurboQuant branch with a GGUF model,
# then launches Claude Code through Headroom with the anthropic proxy
# pointing at llama.cpp's OpenAI-compatible API.
#
# Data flow:
#   Claude Code → headroom wrap claude (internal proxy) → ANTHROPIC_TARGET_API_URL → llama-server :8080
#
# Usage:
#   ./gguf.sh                    # auto-discover GGUF from ~/.lmstudio/models or download from HF
#   ./gguf.sh <hf-model>         # HuggingFace selector, e.g. "Qwen/Qwen3.6-35B-A3B-Instruct-GGUF:Q4_K_M"
#   ./gguf.sh <local-path>       # direct path to a .gguf file
#
# ── Configuration ────────────────────────────────────────────────────────────
set -euo pipefail

LLAMA_SERVER="$HOME/ai/bin/turboquant-current/llama-server"
LLAMA_HOST="127.0.0.1"
LLAMA_PORT=8080
LLAMA_CTX=32768
MODEL_DIR="${MODEL_DIR:-$HOME/.lmstudio/models}"
PID_DIR="/tmp/llama-gguf-pids"
mkdir -p "$PID_DIR"

# Default: same family as the MLX model but GGUF + turbo2 instead of turbo3
DEFAULT_HF_MODEL="unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL"
DEFAULT_ALIAS="qwen3.6-35b-a3b"

MODEL="${1:-}"
LLAMA_PID=""
HEADROOM_PID=""

# ── Helpers ──────────────────────────────────────────────────────────────────
cleanup() {
    echo -e "\n\033[1;33mShutting down...\033[0m"
    [[ -n "$HEADROOM_PID" ]] && kill "$HEADROOM_PID" 2>/dev/null && echo "  killed headroom wrap claude"
    [[ -n "$LLAMA_PID" ]]    && kill "$LLAMA_PID" 2>/dev/null    && echo "  killed llama-server"
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

# ── Model resolution ────────────────────────────────────────────────────────
resolve_alias() {
    local name="$1"
    # Extract the filename/repo-bare part for matching
    local bare="${name#*/}"
    bare="${bare%%:*}"

    case "$bare" in
        Qwen3.6-27B*)              echo "qwen3.6-27b" ;;
        Qwen3.6-35B-A3B*)          echo "qwen3.6-35b-a3b" ;;
        Qwen3-VL-30B-A3B*)         echo "qwen3-vl-30b-a3b" ;;
        Qwen3-VL-32B*)             echo "qwen3-vl-32b" ;;
        *)                         echo "${bare%%.*}" ;;
    esac
}

# Build llama-server args. Returns via global HF_REPO, GGUF_PATH, ALIAS.
resolve_model() {
    local input="$1"
    HF_REPO=""
    GGUF_PATH=""
    ALIAS=""

    # ── Local .gguf file ──
    if [[ -f "$input" && "$input" == *.gguf ]]; then
        GGUF_PATH="$input"
        ALIAS=$(resolve_alias "$(basename "$input")")
        echo "  local GGUF: $input → alias $ALIAS"
        return 0
    fi

    # ── Local model dir: check if it matches a known repo prefix ──
    if [[ -d "$MODEL_DIR/$input" ]]; then
        # Look for a GGUF file inside
        local gguf_file
        gguf_file=$(find "$MODEL_DIR/$input" -maxdepth 1 -name "*.gguf" -type f | head -1)
        if [[ -n "$gguf_file" ]]; then
            GGUF_PATH="$gguf_file"
            ALIAS=$(resolve_alias "$(basename "$gguf_file")")
            echo "  found in model dir: $gguf_file → alias $ALIAS"
            return 0
        fi
    fi

    # ── HuggingFace selector: "org/repo[:quant]" — passed straight to --hf-repo,
    # which natively supports the optional ":quant" suffix (e.g. :UD-Q4_K_XL).
    HF_REPO="$input"
    ALIAS=$(resolve_alias "$input")
    echo "  HF model: $HF_REPO → alias $ALIAS"
}

discover_model() {
    # 1. Check model dir for known model folders with GGUF files
    if [[ -d "$MODEL_DIR" ]]; then
        local gguf_file
        gguf_file=$(find "$MODEL_DIR" -maxdepth 2 -name "*.gguf" -type f 2>/dev/null | head -1)
        if [[ -n "$gguf_file" ]]; then
            echo "$gguf_file"
            return 0
        fi
    fi
    # 2. Fall back to default HF selector
    echo "$DEFAULT_HF_MODEL"
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════"
echo "  gguf.sh — Claude Code → Headroom → llama.cpp (GGUF)"
echo "═══════════════════════════════════════════════════════════"

if [[ ! -x "$LLAMA_SERVER" ]]; then
    echo "❌ TurboQuant llama-server not found:"
    echo "   $LLAMA_SERVER"
    echo "   Install from https://github.com/TheTom/llama-cpp-turboquant"
    exit 1
fi

# Pick up a cached HF login token if HF_TOKEN isn't already set, so gated/
# rate-limited repos and commit-hash lookups don't fail with 401s.
if [[ -z "${HF_TOKEN:-}" && -f "$HOME/.cache/huggingface/token" ]]; then
    export HF_TOKEN="$(cat "$HOME/.cache/huggingface/token")"
fi

"$LLAMA_SERVER" --version 2>/dev/null || true

# ── Step 1: resolve model ───────────────────────────────────────────────────
if [[ -z "$MODEL" ]]; then
    MODEL="$(discover_model)"
fi

resolve_model "$MODEL"

if [[ -z "$ALIAS" ]]; then
    echo "❌ Could not resolve model: $MODEL"
    exit 1
fi

echo ""
echo "  Alias: $ALIAS"
echo "  Port:  $LLAMA_PORT"
echo ""

# ── Step 2: ensure llama-server is running ───────────────────────────────────
if curl -sf --max-time 1 "http://${LLAMA_HOST}:${LLAMA_PORT}/health" >/dev/null 2>&1; then
    echo "  ✓ llama-server already running on port $LLAMA_PORT"
else
    echo "  Starting llama-server ..."

    LLAMA_ARGS=(
        -ngl 999
        -c "$LLAMA_CTX"
        --parallel 1
        -b 2048
        -ub 1024
        -fa on
        --jinja
        --cache-type-k q8_0
        --cache-type-v turbo2
        -lv 1
        --host "$LLAMA_HOST"
        --port "$LLAMA_PORT"
    )

    # Model source (local GGUF or HF download; --hf-repo natively supports "repo:quant")
    if [[ -n "$GGUF_PATH" ]]; then
        LLAMA_ARGS+=(-m "$GGUF_PATH" --alias "$ALIAS")
    elif [[ -n "$HF_REPO" ]]; then
        LLAMA_ARGS+=(--hf-repo "$HF_REPO" --alias "$ALIAS")
    fi

    nohup "$LLAMA_SERVER" "${LLAMA_ARGS[@]}" > "$PID_DIR/llama.log" 2>&1 &
    LLAMA_PID=$!
    echo "$LLAMA_PID" > "$PID_DIR/llama.pid"

    if ! wait_ready "http://${LLAMA_HOST}:${LLAMA_PORT}/health" "llama-server"; then
        echo "  ✗ llama-server failed to start — see $PID_DIR/llama.log"
        tail -n 20 "$PID_DIR/llama.log" 2>/dev/null
        exit 1
    fi
fi

# ── Step 3: launch Claude Code through headroom ─────────────────────────────
export ANTHROPIC_TARGET_API_URL="http://${LLAMA_HOST}:${LLAMA_PORT}"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$ALIAS"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$ALIAS"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$ALIAS"
export ANTHROPIC_AUTH_TOKEN="local"
unset ANTHROPIC_API_KEY

echo ""
echo -e "  \033[1;32m✅ Data flow active:\033[0m"
echo "     Claude Code"
echo "       ↓ headroom wrap claude (internal proxy)"
echo "       ↓ ANTHROPIC_TARGET_API_URL=$ANTHROPIC_TARGET_API_URL"
echo "       ↓ llama-server :$LLAMA_PORT  [$ALIAS, turbo2]"
echo ""
echo "Press Ctrl+C to stop everything."
echo ""

headroom wrap claude -- --verbose --model "$ALIAS" \
    --tools "Bash,Edit,Read,Write,Glob,Grep" \
    --disallowedTools "mcp__*" &
HEADROOM_PID=$!
echo "$HEADROOM_PID" > "$PID_DIR/headroom-wrap.pid"

wait "$HEADROOM_PID" 2>/dev/null
HEADROOM_PID=""
