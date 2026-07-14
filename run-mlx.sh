#!/bin/bash
# start-omlx-headroom.sh
# Starts oMLX + Headroom proxy for use with Claude Code / Aider

set -euo pipefail

OMLX_PORT=8000
HEADROOM_PORT=8787
PID_DIR="/tmp/omlx-headroom-pids"
mkdir -p "$PID_DIR"

cleanup() {
    echo ""
    echo "🧹 Cleaning up..."
    for pidfile in "$PID_DIR"/*.pid; do
        [ -f "$pidfile" ] && kill $(cat "$pidfile") 2>/dev/null || true
        rm -f "$pidfile"
    done

    pkill -f "omlx serve" 2>/dev/null || true
    pkill -f "headroom proxy.*--port $HEADROOM_PORT" 2>/dev/null || true

    echo "✅ Cleanup complete."
}

trap cleanup EXIT INT TERM

start_omlx() {
    echo "🚀 Starting oMLX server on port $OMLX_PORT..."
    
    # Option 1: Use managed background service (if installed via Homebrew or app)
    # omlx start
    
    # Option 2: Run directly in background (more reliable for scripting)
    nohup omlx serve \
        --model-dir ~/models \
        --port $OMLX_PORT \
        > /tmp/omlx.log 2>&1 &
    
    echo $! > "$PID_DIR/omlx.pid"
    sleep 6
}

start_headroom() {
    echo "🧠 Starting Headroom proxy → oMLX ($OMLX_PORT)..."
    nohup headroom proxy \
        --port $HEADROOM_PORT \
        --target "http://localhost:$OMLX_PORT" \
        > /tmp/headroom-omlx.log 2>&1 &
    
    echo $! > "$PID_DIR/headroom.pid"
    sleep 3
    
    echo "   Headroom dashboard: http://localhost:$HEADROOM_PORT"
}

# === Main ===
cleanup

start_omlx
start_headroom

echo ""
echo "✅ oMLX + Headroom is running"
echo ""
echo "Next step — open a NEW terminal and run:"
echo ""
echo "   headroom wrap claude"
echo ""
echo "   (or for Aider: headroom wrap aider)"
echo ""
echo "Press Ctrl+C here to stop everything cleanly."
echo ""

# Keep script alive
tail -f /dev/null