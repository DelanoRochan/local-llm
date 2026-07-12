#!/bin/bash

#unsloth/Qwen3.6-27B-GGUF:UD-Q5_K_XL

export ANTHROPIC_TARGET_API_URL=http://127.0.0.1:8080
export ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3-vl-32b
export ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3-vl-32b
export ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3-vl-32b
export ANTHROPIC_AUTH_TOKEN=local
unset ANTHROPIC_API_KEY

#export HEADROOM_MODE=cache
#export HEADROOM_OUTPUT_SHAPER=1
#  --mode cache \
#  --code-aware \
#  --no-read-lifecycle \
#  --memory \
#  --memory-top-k 4

#headroom wrap claude -- --model qwen3-vl-32b --tools "Bash,Edit,Read,Write,Glob,Grep" --disallowedTools "mcp__*"
#headroom wrap claude -- --verbose --model qwen3-vl-30b-a3b --tools "Bash,Edit,Read,Write,Glob,Grep" --disallowedTools "mcp__*"
headroom wrap claude -- --verbose --model qwen3.6-27b --tools "Bash,Edit,Read,Write,Glob,Grep" --disallowedTools "mcp__*"


