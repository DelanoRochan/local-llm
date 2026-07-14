#!/bin/bash
# begin.sh - Cross-platform LLM backend + Headroom switcher
set -euo pipefail

BACKEND=${1:-llama-turbo}
AGENT=${AGENT:-${2:-}}

MODEL_PATH=${MODEL_PATH:-/path/to/your/model.gguf}
HEADROOM_PORT=8787
BACKEND_PORT=8080
PID_DIR="/tmp/llm-switch-pids"
mkdir -p "$PID_DIR"

cleanup() {
    echo ""
    echo "🧹 Cleaning up..."
    for pidfile in "$PID_DIR"/*.pid; do
        [ -f "$pidfile" ] && kill $(cat "$pidfile") 2>/dev/null || true
        rm -f "$pidfile"
    done

    pkill -f "llama-server.*--port $BACKEND_PORT" 2>/dev/null || true
    pkill -f "mlx_lm.server.*--port $BACKEND_PORT" 2>/dev/null || true
    pkill -f "vllm serve.*--port $BACKEND_PORT" 2>/dev/null || true
    pkill -f "headroom proxy.*--port $HEADROOM_PORT" 2>/dev/null || true

    echo "✅ Clean shutdown complete."
}

trap cleanup EXIT INT TERM

start_llama_turbo() {
    echo "🚀 Starting llama.cpp + TurboQuant..."
    nohup ./llama-server \
        -m "$MODEL_PATH" \
        --port $BACKEND_PORT \
        --cache-type-k q8_0 --cache-type-v turbo3 \
        -ngl 99 -c 32768 -fa on \
        > /tmp/llama-turbo.log 2>&1 &
    echo $! > "$PID_DIR/llama.pid"
    sleep 4
}

start_headroom() {
    echo "🧠 Starting Headroom proxy..."
    nohup headroom proxy --port $HEADROOM_PORT --target "http://localhost:$BACKEND_PORT" \
        > /tmp/headroom.log 2>&1 &
    echo $! > "$PID_DIR/headroom.pid"
    sleep 3
    echo "   Dashboard → http://localhost:$HEADROOM_PORT"
}

launch_agent_instructions() {
    if [ -z "$AGENT" ]; then
        echo ""
        echo "🤖 No agent auto-started. Open another terminal to run your agent."
        return
    fi

    case "$AGENT" in
        aider)
            echo ""
            echo "🤖 Aider is ready. In a new terminal, run one of these:"
            echo ""
            echo "   Best option:"
            echo "   headroom wrap aider"
            echo ""
            echo "   Manual option:"
            echo "   aider --openai-api-base http://localhost:$HEADROOM_PORT/v1 --api-key fake"
            ;;
        claude)
            echo ""
            echo "🤖 Claude Code:"
            echo "   headroom wrap claude"
            ;;
        *)
            echo "Unknown agent: $AGENT"
            ;;
    esac
}

# === Start services ===
cleanup   # clean any leftovers from previous runs

case "$BACKEND" in
    llama-turbo) start_llama_turbo ;;
    *) echo "❌ Unknown backend: $BACKEND"; exit 1 ;;
esac

start_headroom
launch_agent_instructions

echo ""
echo "✅ Backend '$BACKEND' + Headroom running"
echo "   Backend:  http://localhost:$BACKEND_PORT"
echo "   Headroom: http://localhost:$HEADROOM_PORT"
echo ""
echo "   Press Ctrl+C to stop everything cleanly."
echo ""

# === Keep script running (works on Linux + macOS) ===
tail -f /dev/null