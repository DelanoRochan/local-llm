# local-llm
Personal research on optimal parameters and stack for local LLM on Apple Macbook Pro M3+ series.

## Agents that support LLM on localhost
I'm using Cursor as main IDE:
- [ ] Cline VSCode extension
- [ ] Claude Code in terminal
- [ ] Cursor Agent (partial, all traffic goes through cursor servers, hence needs a reverse proxy to localhost)

## Ideal token pipeline
- [ ] llama.cpp (GGUF vs MLX) > ollama > LM studio
- [ ] Consider using a fork of llama.cpp that supports *TurboQuant*
- [ ] use Headroom for context / token compression

## Example

```bash
export ANTHROPIC_TARGET_API_URL=http://127.0.0.1:8080
export ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3-vl-32b
export ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3-vl-32b
export ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3-vl-32b
export ANTHROPIC_AUTH_TOKEN=local
unset ANTHROPIC_API_KEY

headroom wrap claude -- --model qwen3-vl-32b
```

```bash
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
```

Parameters:
- [ ] --cache-type-v (turbo4, 3, 2)
- [ ] --parallel (1, 2, ...)
- [ ] --cache-type-k q8_0 (5, 4, ...)
