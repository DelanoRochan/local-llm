#!/usr/bin/env bash
set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────
LLAMA_SERVER="$HOME/ai/bin/turboquant-current/llama-server"
LAST_MODEL_FILE=".run-last-model"

# Default to last-used model unless arg provided
MODEL_SPEC="${1:-}"
if [[ -z "$MODEL_SPEC" ]]; then
    if [[ -f "$LAST_MODEL_FILE" ]]; then
        MODEL_SPEC="$(cat "$LAST_MODEL_FILE")"
        echo "No model specified — using last model: $MODEL_SPEC"
    else
        echo "Usage: $0 <owner/repo[:quant_or_file]>"
        echo "  e.g.  $0 unsloth/Qwen3.6-27B-GGUF"
        echo "        $0 Qwen/Qwen3-VL-30B-A3B-Instruct-GGUF:Q4_K_M"
        echo "        $0 Qwen/Qwen3-VL-30B-A3B-Instruct-GGUF:model-f16.gguf"
        exit 1
    fi
fi

if [[ ! -x "$LLAMA_SERVER" ]]; then
    echo "llama-server not found or not executable: $LLAMA_SERVER"
    exit 1
fi

# ── Process cleanup ──────────────────────────────────────────────────────
LLAMA_PID=""
HEADROOM_PID=""

cleanup() {
    echo -e "\n\033[1;33mShutting down...\033[0m"
    [[ -n "$HEADROOM_PID" ]] && kill "$HEADROOM_PID" 2>/dev/null && echo "  killed headroom-claude (PID $HEADROOM_PID)"
    [[ -n "$LLAMA_PID" ]]    && kill "$LLAMA_PID"    2>/dev/null && echo "  killed llama-server (PID $LLAMA_PID)"
    wait 2>/dev/null
    echo "Done."
}
trap cleanup EXIT INT TERM

# ── Parse model spec ────────────────────────────────────────────────────
# Format:  owner/repo[:quant_tag_or_filename]
#   Qwen/Qwen3-VL-30B-A3B-Instruct-GGUF:Q4_K_M   → quant hint (info only, llama picks best)
#   unsloth/Qwen3.6-27B-GGUF:Qwen3.6-27B-Q5_K.gguf → exact file override
HF_REPO="${MODEL_SPEC%%:*}"
QUANT_HINT="${MODEL_SPEC#*:}"
[[ "$QUANT_HINT" == "$MODEL_SPEC" ]] && QUANT_HINT=""

# Derive alias from repo name:
#   Qwen/Qwen3-VL-30B-A3B-Instruct-GGUF → qwen3-vl-30b-a3b
#   unsloth/Qwen3.6-27B-GGUF            → qwen3.6-27b
ALIAS="$(echo "${HF_REPO##*/}" | \
    tr '[:upper:]' '[:lower:]' | \
    sed -E 's/-instruct-gguf$//; s/-instruct$//; s/-[a-z][a-z0-9_]*-gguf$//; s/-gguf$//')"
ALIAS="$(echo "$ALIAS" | sed -E 's/-{2,}/-/g; s/^-//; s/-$//')"

echo -e "\033[1;36m═══════════════════════════════════════════════════════\033[0m"
echo -e "  Model : \033[1;36m$HF_REPO\033[0m"
echo -e "  Quant : \033[1;36m${QUANT_HINT:-auto}\033[0m"
echo -e "  Alias : \033[1;36m$ALIAS\033[0m"
echo -e "\033[1;36m═══════════════════════════════════════════════════════\033[0m"

# Persist for next run
echo "$MODEL_SPEC" > "$LAST_MODEL_FILE"

# ── Build llama-server args ─────────────────────────────────────────────
HF_ARGS=(--hf-repo "$HF_REPO")
# If quant hint looks like a filename (contains dot), pass as --hf-file
if [[ -n "$QUANT_HINT" && "$QUANT_HINT" == *"."* ]]; then
    HF_ARGS+=(--hf-file "$QUANT_HINT")
fi

LLAMA_ARGS=(
    "${HF_ARGS[@]}"
    --alias "$ALIAS"
    -ngl 999
    -c 32768
    --parallel 1
    -b 2048
    -ub 1024
    -fa on
    --jinja
    --cache-type-k q8_0
    --cache-type-v turbo3
    -lv 1
    --host 127.0.0.1
    --port 8080
)

# ── Start llama-server ──────────────────────────────────────────────────
echo ""
echo "Starting llama-server ..."
"$LLAMA_SERVER" "${LLAMA_ARGS[@]}" &
LLAMA_PID=$!

# Wait until the server is ready (up to 60 s)
for i in $(seq 1 60); do
    if curl -sf http://127.0.0.1:8080/health > /dev/null 2>&1; then
        echo "llama-server ready (PID $LLAMA_PID)"
        break
    fi
    if ! kill -0 "$LLAMA_PID" 2>/dev/null; then
        echo "llama-server exited unexpectedly!"
        exit 1
    fi
    [[ $i -eq 60 ]] && { echo "timeout waiting for llama-server"; exit 1; }
    sleep 1
done

# ── Start headroom + claude ─────────────────────────────────────────────
export ANTHROPIC_TARGET_API_URL=http://127.0.0.1:8080
export ANTHROPIC_DEFAULT_OPUS_MODEL="$ALIAS"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$ALIAS"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$ALIAS"
export ANTHROPIC_AUTH_TOKEN=local
unset ANTHROPIC_API_KEY

echo ""
echo "Starting Claude Code via Headroom (PID $HEADROOM_PID) ..."
headroom wrap claude -- --verbose --model "$ALIAS" \
    --tools "Bash,Edit,Read,Write,Glob,Grep" \
    --disallowedTools "mcp__*" &
HEADROOM_PID=$!

# ── Wait for foreground process ─────────────────────────────────────────
wait "$HEADROOM_PID" 2>/dev/null
HEADROOM_PID=""   # already exited, don't kill again
