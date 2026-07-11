#!/bin/bash

# start.sh - Combined launcher for llama and headroom-claude

# Check if tmux is available for better output management
if command -v tmux > /dev/null 2>&1; then
    echo "Using tmux for output management..."

    # Create a new tmux session with two panes
    tmux new-session -d -s local_llm_session -n "llama" "bash -c 'echo "\n--- LLAMA SERVER OUTPUT ---\n"; cd /Users/delano.keuter/development/local-llm; bash start-llama.sh; echo "\n--- LLAMA SERVER ENDED ---\n"'"

    # Split the pane horizontally and run headroom-claude in the second pane
    tmux split-window -h -t local_llm_session:0 "bash -c 'echo "\n--- HEADROOM-CLAUSE OUTPUT ---\n"; cd /Users/delano.keuter/development/local-llm; bash start-headroom-claude.sh; echo "\n--- HEADROOM-CLAUSE ENDED ---\n"'"

    # Attach to the session
    tmux -2 attach-session -t local_llm_session

    # Clean up when detached
    trap "tmux kill-session -t local_llm_session" EXIT

    # Exit with status from the last command
    exit 0

# Fallback: if tmux is not available, run both in background
else
    echo "tmux not found. Running both processes in background..."

    # Start llama server in background
    echo "Starting llama server..."
    cd /Users/delano.keuter/development/local-llm && bash start-llama.sh &
    LLAMA_PID=$!

    # Start headroom-claude in background
    echo "Starting headroom-claude..."
    cd /Users/delano.keuter/development/local-llm && bash start-headroom-claude.sh &
    HEADROOM_PID=$!

    # Print PIDs for reference
    echo "Llama server PID: $LLAMA_PID"
    echo "Headroom-claude PID: $HEADROOM_PID"

    # Wait for both processes to complete (or Ctrl+C to interrupt)
    wait $LLAMA_PID $HEADROOM_PID

    # Clean up
    echo "Both processes have completed."
    exit 0
fi