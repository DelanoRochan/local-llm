#!/bin/bash

#mkdir -p ~/ai/bin ~/ai/models
#cd ~/ai/bin

#curl -L -o turboquant-macos-arm64-metal.tar.gz \
#  https://github.com/TheTom/llama-cpp-turboquant/releases/download/tqp-v0.2.0/turboquant-plus-tqp-v0.2.0-macos-arm64-metal.tar.gz

#tar -xzf turboquant-macos-arm64-metal.tar.gz

# Check names in archive
#find . -maxdepth 3 -type f | grep llama

#brew install git-lfs
#python3 -m pip install -U "huggingface_hub[cli]"
#huggingface-cli login

LLAMA_SERVER="$HOME/ai/bin/turboquant-current/llama-server"

if [[ ! -x "$LLAMA_SERVER" ]]; then
    echo "TurboQuant llama-server not found or not executable:"
    echo "  $LLAMA_SERVER"
    exit 1
fi

#llama-server \
#  -hf Qwen/Qwen3-VL-30B-A3B-Instruct-GGUF:Q4_K_M \
#  --alias qwen3-vl-30b-a3b \
#  -ngl 999 \
#  -c 32768 \
#  --parallel 1 \
#  -b 2048 \
#  -ub 1024 \
#  -fa on \
#  --jinja \
#  --cache-type-k q8_0 \
#  --cache-type-v turbo3 \
#  -lv 1 \
#  --host 127.0.0.1 \
#  --port 8080

#llama-server \
#  -hf unsloth/Qwen3-Coder-Next-GGUF:UD-Q5_K_M \
#  --alias qwen3-coder-next \
#  -ngl 999 \
#  -c 32768 \
#  --parallel 1 \
#  -fa on \
#  --jinja \
# --cache-type-k q8_0 \
# --cache-type-v turbo3 \
# --host 127.0.0.1 \
# --port 8080


#unsloth/Qwen3.6-27B-GGUF:UD-Q5_K_XL
#Qwen/Qwen3-VL-30B-A3B-Instruct-GGUF:Q4_K_M

ARGS=(
    --hf-repo "unsloth/Qwen3.6-27B-GGUF"
    --hf-file "Qwen3.6-27B-UD-Q5_K_XL.gguf"
    --alias "qwen3.6-27b"
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

echo "Using: $LLAMA_SERVER"
"$LLAMA_SERVER" --version

exec "$LLAMA_SERVER" "${ARGS[@]}"
