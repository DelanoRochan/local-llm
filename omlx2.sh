#!/bin/bash
# omlx2.sh - Cursor (OpenAI API) → Cloudflare Tunnel → Headroom → omlx
#
# Exposes a local omlx model to Cursor's "Override OpenAI Base URL" setting
# over a public HTTPS URL, with Headroom's optimization proxy sitting in
# front of omlx (omlx already speaks native OpenAI protocol at
# /v1/chat/completions, so Headroom just needs --openai-api-url passthrough).
#
# Data flow:
#   Cursor → Cloudflare quick tunnel (https://*.trycloudflare.com)
#          → headroom proxy :8787 (OpenAI passthrough)
#          → omlx serve :8100
#
# Usage:
#   ./omlx2.sh                 # uses MODEL below
#   ./omlx2.sh <model-id>       # explicit model id, must match an omlx-loaded model

set -euo pipefail

OMLX_PORT=8100
OMLX_MODEL_DIR="${OMLX_MODEL_DIR:-$HOME/.lmstudio/models}"
HEADROOM_PROXY_PORT=8787
OMLX_API_KEY="${OMLX_API_KEY:-sk-omlx-test}"
PID_DIR="/tmp/omlx2-pids"
mkdir -p "$PID_DIR"

# Single-model assumption for now — change this to switch models.
MODEL="${1:-Qwen3.6-35B-A3B-MTP-Holo3-Qwopus-Coder-qx64y-hi-mlx}"

OMLX_PID=""
HEADROOM_PROXY_PID=""
CLOUDFLARED_PID=""

# ── Helpers ──────────────────────────────────────────────────────────────────
cleanup() {
    echo -e "\n\033[1;33mShutting down...\033[0m"
    [[ -n "$CLOUDFLARED_PID" ]]    && kill "$CLOUDFLARED_PID" 2>/dev/null && echo "  killed cloudflared"
    [[ -n "$HEADROOM_PROXY_PID" ]] && kill "$HEADROOM_PROXY_PID" 2>/dev/null && echo "  killed headroom proxy"
    [[ -n "$OMLX_PID" ]]           && kill "$OMLX_PID" 2>/dev/null && echo "  killed omlx serve"
    wait 2>/dev/null
    rm -f "$PID_DIR"/*.pid 2>/dev/null || true
    echo "Done."
}
trap cleanup EXIT INT TERM

wait_ready() {
    local url="$1" label="$2" max="${3:-60}"
    for i in $(seq 1 "$max"); do
        if curl -sf --max-time 2 "$url" > /dev/null 2>&1; then
            echo "  ✓ $label ready"
            return 0
        fi
        sleep 1
    done
    echo "  ✗ $label timed out after ${max}s"
    return 1
}

wait_for_tunnel_url() {
    local log="$1" max="${2:-30}"
    for i in $(seq 1 "$max"); do
        local url
        url=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$log" 2>/dev/null | head -1)
        if [[ -n "$url" ]]; then
            echo "$url"
            return 0
        fi
        sleep 1
    done
    return 1
}

echo "═══════════════════════════════════════════════════════════"
echo "  omlx2.sh — Cursor → Cloudflare Tunnel → Headroom → omlx"
echo "═══════════════════════════════════════════════════════════"

if ! command -v omlx &>/dev/null; then
    echo "❌ omlx not found in PATH. Install via: brew install omlx"
    exit 1
fi
if ! command -v cloudflared &>/dev/null; then
    echo "❌ cloudflared not found in PATH. Install via: brew install cloudflared"
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

# ── Step 2: start headroom proxy in front of omlx (OpenAI passthrough) ─────
echo "  Starting headroom proxy (OpenAI passthrough, :$HEADROOM_PROXY_PORT → omlx :$OMLX_PORT) ..."
nohup headroom proxy \
    --port "$HEADROOM_PROXY_PORT" \
    --openai-api-url "http://127.0.0.1:$OMLX_PORT" \
    > "$PID_DIR/headroom-proxy.log" 2>&1 &
HEADROOM_PROXY_PID=$!
echo "$HEADROOM_PROXY_PID" > "$PID_DIR/headroom-proxy.pid"

if ! wait_ready "http://127.0.0.1:$HEADROOM_PROXY_PORT/health" "headroom proxy" 30; then
    echo "  ✗ headroom proxy failed to start — see $PID_DIR/headroom-proxy.log"
    tail -n 30 "$PID_DIR/headroom-proxy.log" 2>/dev/null
    exit 1
fi

# Sanity check: make sure the model responds through the proxy before exposing it.
echo "  Verifying model '$MODEL' responds through the proxy ..."
CHECK_HTTP=$(curl -s -o "$PID_DIR/sanity-check.json" -w "%{http_code}" "http://127.0.0.1:$HEADROOM_PROXY_PORT/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OMLX_API_KEY" \
    -d "{\"model\":\"$MODEL\",\"max_tokens\":5,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}")
if [[ "$CHECK_HTTP" != "200" ]]; then
    echo "  ✗ Model check failed (HTTP $CHECK_HTTP):"
    cat "$PID_DIR/sanity-check.json" 2>/dev/null
    echo ""
    echo "  Available models:"
    curl -s "http://127.0.0.1:$OMLX_PORT/v1/models" | python3 -c "import json,sys; [print('   -', m['id']) for m in json.load(sys.stdin)['data']]" 2>/dev/null
    exit 1
fi
echo "  ✓ model responded"

# ── Step 3: start Cloudflare quick tunnel ───────────────────────────────────
echo "  Starting Cloudflare quick tunnel → :$HEADROOM_PROXY_PORT ..."
nohup cloudflared tunnel --url "http://127.0.0.1:$HEADROOM_PROXY_PORT" > "$PID_DIR/cloudflared.log" 2>&1 &
CLOUDFLARED_PID=$!
echo "$CLOUDFLARED_PID" > "$PID_DIR/cloudflared.pid"

TUNNEL_URL="$(wait_for_tunnel_url "$PID_DIR/cloudflared.log" 30 || true)"
if [[ -z "$TUNNEL_URL" ]]; then
    echo "  ✗ Could not get tunnel URL — see $PID_DIR/cloudflared.log"
    tail -n 30 "$PID_DIR/cloudflared.log" 2>/dev/null
    exit 1
fi
echo "  ✓ tunnel ready"

echo ""
echo -e "  \033[1;32m✅ Public OpenAI-compatible endpoint active:\033[0m"
echo "     Cursor"
echo "       ↓ $TUNNEL_URL  (Cloudflare quick tunnel)"
echo "       ↓ headroom proxy :$HEADROOM_PROXY_PORT (OpenAI passthrough)"
echo "       ↓ omlx serve :$OMLX_PORT  [$MODEL]"
echo ""
echo -e "  \033[1;36mConfigure in Cursor (Settings → Models → OpenAI):\033[0m"
echo "     Base URL:  $TUNNEL_URL/v1"
echo "     API Key:   $OMLX_API_KEY  (any non-empty value works)"
echo "     Model:     $MODEL"
echo ""
echo "  ⚠️  trycloudflare.com quick tunnels are ephemeral — this URL changes"
echo "     every time you run this script. For a stable URL, set up a named"
echo "     Cloudflare Tunnel (cloudflared tunnel create) instead."
echo ""
echo "Press Ctrl+C to stop everything."
echo ""

wait "$CLOUDFLARED_PID" 2>/dev/null
CLOUDFLARED_PID=""
