#!/bin/bash

export ANTHROPIC_TARGET_API_URL=http://127.0.0.1:8080
export ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3-vl-32b
export ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3-vl-32b
export ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3-vl-32b
export ANTHROPIC_AUTH_TOKEN=local
unset ANTHROPIC_API_KEY

headroom wrap claude -- --model qwen3-vl-32b --tools "Bash,Edit,Read,Write,Glob,Grep" --disallowedTools "mcp__*"
