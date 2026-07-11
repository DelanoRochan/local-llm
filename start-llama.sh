#!/bin/bash

llama-server \
  -hf Qwen/Qwen3-VL-32B-Instruct-GGUF:Q4_K_M \
  --alias qwen3-vl-32b \
  -ngl 999 \
  -c 32768 \
  --parallel 1 \
  -fa on \ 
  --jinja \
  --cache-type-k q8_0 \  
  --cache-type-v turbo3 \
  --host 127.0.0.1 \
  --port 8080

