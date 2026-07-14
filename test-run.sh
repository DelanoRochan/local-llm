#!/bin/bash
# test-run.sh - Unified test runner: llama/cpp or omlx backend → Headroom → Claude Code
# Full data flow with RTK proxy, single script.
#
# Data flow (llama mode):
#   Claude Code → headroom wrap claude → ANTHROPIC_TARGET_API_URL → llama-server (GGUF)
#
# Data flow (omlx mode):
#   Claude Code → headroom wrap claude → ANTHROPIC_TARGET_API_URL → headroom proxy (Anthropic→OpenAI) → omlx (already running)
#
# Usage:
#   ./test-run.sh llama [repo]            # llama.cpp + TurboQuant (default)
#   ./test-run.sh omlx [model-id]         # omlx backend via headroom proxy
#                                         # model-id optional; auto-discovered from ~/.lmstudio/models

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────
BACKEND="${1:-llama}"
HF_REPO="${2:-unsloth/Qwen3.6-27B-GGUF}"
LLAMA_PORT=8080
HEADROOM_PROXY_PORT=8787
OMLX_PORT=8100
PID_DIR="/tmp/test-run-pids"
mkdir -p "$PID_DIR"

LLAMA_SERVER="${LLAMA_SERVER:-$HOME/ai/bin/turboquant-current/llama-server}"

LLAMA_PID=""
HEADROOM_WRAP_PID=""
HEADROOM_PROXY_PID=""
OMLX_PID=""

# ── Helpers ──────────────────────────────────────────────────────────────────
cleanup() {
    echo -e "\n\033[1;33mShutting down...\033[0m"
    [[ -n "$OMLX_PID" ]]      && kill "$OMLX_PID" 2>/dev/null && echo "  killed omlx"
    [[ -n "$HEADROOM_PROXY_PID" ]] && kill "$HEADROOM_PROXY_PID" 2>/dev/null && echo "  killed headroom proxy"
    [[ -n "$HEADROOM_WRAP_PID" ]]   && kill "$HEADROOM_WRAP_PID" 2>/dev/null && echo "  killed headroom wrap claude"
    [[ -n "$LLAMA_PID" ]]             && kill "$LLAMA_PID" 2>/dev/null && echo "  killed llama-server"
    wait 2>/dev/null

    rm -f "$PID_DIR"/*.pid 2>/dev/null || true
    echo "Done."
}
trap cleanup EXIT INT TERM

save_pid() { echo "$1" > "$PID_DIR/$2.pid"; }

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

derive_alias() {
    echo "${HF_REPO##*/}" | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/-instruct-gguf$//; s/-instruct$//; s/-[a-z][a-z0-9_]*-gguf$//; s/-gguf$//' \
        | sed -E 's/-{2,}/-/g; s/^-//; s/-$//'
}

OMLX_DEFAULT_MODEL="lmstudio-community/Qwen3.6-35B-A3B-MLX-6bit"

discover_omlx_model() {
    local dir="${1:-$HOME/.lmstudio/models}"
    local preferred="$OMLX_DEFAULT_MODEL"
    # prefer the known good default if present
    if [[ -d "$dir/$preferred" ]]; then
        echo "$preferred"
        return
    fi
    # otherwise fall back to first subdirectory found
    if [[ -d "$dir" ]]; then
        find "$dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | head -1
    fi
}

# ── LLAMA mode ───────────────────────────────────────────────────────────────
start_llama() {
    echo -e "\n\033[1;36m════════════════════════════════════════════════════════╕\033[0m"
    echo -e "  \033[1;36mLLAMA mode\033[0m  —  Model: \033[1;36m$HF_REPO\033[0m"
    echo -e "  \033[1;36m═══════════════════════════════════════════════════════\033[0m"
    echo -e "  \033[1;36m╘═══════════════════════════════════════════════════════╝\033[0m"

    ALIAS="$(derive_alias "$HF_REPO")"

    if [[ ! -x "$LLAMA_SERVER" ]]; then
        echo "❌ llama-server not found: $LLAMA_SERVER"
        exit 1
    fi

    HF_ARGS=(--hf-repo "$HF_REPO")
    QUANT_HINT="${HF_REPO#*:}"
    [[ "$QUANT_HINT" == "$HF_REPO" ]] && QUANT_HINT=""
    if [[ -n "$QUANT_HINT" && "$QUANT_HINT" == *"."* ]]; then
        HF_ARGS+=(--hf-file "$QUANT_HINT")
    fi

    echo "  Starting llama-server (alias: $ALIAS) ..."
    "$LLAMA_SERVER" \
        "${HF_ARGS[@]}" \
        --alias "$ALIAS" \
        -ngl 999 \
        -c 32768 \
        --parallel 1 \
        -b 2048 \
        -ub 1024 \
        -fa on \
        --jinja \
        --cache-type-k q8_0 \
        --cache-type-v turbo3 \
        -lv 1 \
        --host 127.0.0.1 \
        --port "$LLAMA_PORT" &
    LLAMA_PID=$!
    save_pid "$LLAMA_PID" llama

    wait_ready "http://127.0.0.1:$LLAMA_PORT/health" "llama-server"
}

# ── OMLX mode ────────────────────────────────────────────────────────────────
start_omlx() {
    echo -e "\n\033[1;36m════════════════════════════════════════════════════════╕\033[0m"
    echo -e "  \033[1;36mOMLX mode\033[0m  —  omlx serve → headroom proxy → headroom wrap claude"
    echo -e "  \033[1;36m═══════════════════════════════════════════════════════\033[0m"
    echo -e "  \033[1;36m╘═══════════════════════════════════════════════════════╝\033[0m"

    if ! command -v omlx &>/dev/null; then
        echo "❌ omlx not found in PATH. Install via: brew install omlx"
        exit 1
    fi

    echo "  Starting omlx serve on port $OMLX_PORT (models: ~/.lmstudio/models) ..."
    nohup omlx serve --model-dir ~/.lmstudio/models --port "$OMLX_PORT" > "$PID_DIR/omlx.log" 2>&1 &
    OMLX_PID=$!
    save_pid "$OMLX_PID" omlx
    sleep 6
}

start_headroom_proxy() {
    echo "  Starting headroom proxy (Anthropic→OpenAI, omlx :$OMLX_PORT → proxy :$HEADROOM_PROXY_PORT) ..."
    # omlx speaks OpenAI-compatible API; route via headroom's anyllm/openai backend.
    # omlx's ~/.omlx/settings.json has skip_api_key_verification=true, so any key works.
    OPENAI_API_KEY="${OPENAI_API_KEY:-sk-omlx-test}" \
    nohup headroom proxy \
        --port "$HEADROOM_PROXY_PORT" \
        --backend anyllm \
        --anyllm-provider openai \
        --openai-api-url "http://127.0.0.1:$OMLX_PORT" \
        > "$PID_DIR/headroom-proxy.log" 2>&1 &
    HEADROOM_PROXY_PID=$!
    save_pid "$HEADROOM_PROXY_PID" headroom-proxy
    sleep 3

    if ! kill -0 "$HEADROOM_PROXY_PID" 2>/dev/null; then
        echo "  ✗ headroom proxy failed to start — see $PID_DIR/headroom-proxy.log"
        tail -n 20 "$PID_DIR/headroom-proxy.log" 2>/dev/null
        exit 1
    fi
    echo "  ✓ headroom proxy started"
}

# ── Headroom wrap claude (common to both modes) ──────────────────────────────
start_headroom_claude() {
    ALIAS="${ALIAS:-qwen3.6-27b}"

    export ANTHROPIC_DEFAULT_OPUS_MODEL="$ALIAS"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$ALIAS"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$ALIAS"
    export ANTHROPIC_AUTH_TOKEN=local
    unset ANTHROPIC_API_KEY

    if [[ "$BACKEND" == "omlx" ]]; then
        # We already have our own headroom proxy running on $HEADROOM_PROXY_PORT
        # (anyllm/openai → omlx). Tell `wrap` to reuse it instead of spawning its
        # own nested proxy with the default 'anthropic' backend, which would try
        # to speak raw Anthropic protocol to our proxy and fail auth (401).
        echo ""
        echo "  Starting Claude Code via headroom wrap (reusing proxy :$HEADROOM_PROXY_PORT) ..."
        headroom wrap claude --no-proxy -p "$HEADROOM_PROXY_PORT" -- --verbose --model "$ALIAS" \
            --tools "Bash,Edit,Read,Write,Glob,Grep" \
            --disallowedTools "mcp__*" &
    else
        # llama mode: no separate proxy running; let wrap spawn its own internal
        # proxy pointed directly at llama-server.
        UPSTREAM_URL="${UPSTREAM_URL:-http://127.0.0.1:$LLAMA_PORT}"
        echo ""
        echo "  Starting Claude Code via headroom wrap (upstream: $UPSTREAM_URL) ..."
        export ANTHROPIC_TARGET_API_URL="$UPSTREAM_URL"
        headroom wrap claude -- --verbose --model "$ALIAS" \
            --tools "Bash,Edit,Read,Write,Glob,Grep" \
            --disallowedTools "mcp__*" &
    fi
    HEADROOM_WRAP_PID=$!
    save_pid "$HEADROOM_WRAP_PID" headroom-wrap

    echo ""
    echo -e "  \033[1;32m✅ Full data flow active:\033[0m"
    echo "     Claude Code"
    if [[ "$BACKEND" == "omlx" ]]; then
        echo "       ↓ ANTHROPIC_BASE_URL → headroom proxy :$HEADROOM_PROXY_PORT (anyllm/openai)"
        echo "       ↓ omlx serve :$OMLX_PORT  [$ALIAS]"
    else
        echo "       ↓ headroom wrap claude (internal RTK proxy)"
        echo "       ↓ ANTHROPIC_TARGET_API_URL=$UPSTREAM_URL"
        echo "       ↓ llama-server :$LLAMA_PORT  [$HF_REPO]"
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════"
echo "  test-run.sh — $BACKEND mode"
echo "═══════════════════════════════════════════════════════════"

case "$BACKEND" in
    llama)
        start_llama
        UPSTREAM_URL="http://127.0.0.1:$LLAMA_PORT"
        ALIAS="$(derive_alias "$HF_REPO")"
        start_headroom_claude
        ;;
    omlx)
        # assume omlx already running on $OMLX_PORT (OpenAI-compatible)
        # headroom wrap claude speaks Anthropic → needs headroom proxy to translate to OpenAI for omlx
        echo "  ✓ assuming omlx running on port $OMLX_PORT"
        start_headroom_proxy
        UPSTREAM_URL="http://127.0.0.1:$HEADROOM_PROXY_PORT"
        # use 2nd CLI arg as explicit model, else auto-discover from ~/.lmstudio/models
        if [[ -n "${2:-}" ]]; then
            ALIAS="$2"
        else
            ALIAS="$(discover_omlx_model)"
            [[ -z "$ALIAS" ]] && ALIAS="omlx"
        fi
        start_headroom_claude
        ;;
    *)
        echo "Usage: $0 [llama|omlx] [model-or-repo]"
        echo "  llama  — llama.cpp with GGUF (default)"
        echo "  omlx   — omlx backend via headroom proxy (model id optional; auto-discovered)"
        exit 1
        ;;
esac

echo ""
echo "Press Ctrl+C to stop everything."
echo ""

# Wait for headroom wrap (foreground — keeps script alive)
wait "$HEADROOM_WRAP_PID" 2>/dev/null
HEADROOM_WRAP_PID=""
