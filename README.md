# local-llm
Personal research on optimal stack and LLM parameters for running a local agent on Apple Macbook Pro M3+ series.

## Goals
- [ ] Use as daily driver for fullstack coding
- [ ] Use with image input, OCR should work great (screen grab UI or error)
- [ ] Can find its way through a complex codebase
- [ ] Great tool calling (bash, curl, cat, etc.)
- [ ] Streaming output?

## Experiment 1: oMLX + headroom + claude code


## Experiment 2: llama.cpp w/ Turboquant + headroom + claude code



## Agents that support LLM on localhost
I'm using Cursor as main IDE with Claude Code and using headroom with `headroom wrap claude` to achieve token compression.

Other options:
- [ ] Cline VSCode extension
- [ ] Cursor Agent (partial, all traffic goes through cursor servers, hence needs a reverse proxy to localhost)

## Ideal token pipeline
- [ ] llama.cpp (GGUF vs MLX) > ollama > LM studio
- [ ] Consider using a fork of llama.cpp that supports *TurboQuant*
- [ ] use Headroom for context / token compression

## Prompt for having multiple models (one general, one great at coding)
"You are a coding expert. You have access to two local models: Model A (Qwen3.6-35B-A3B — strong vision + general) and Model B (Qwen3-Coder-Next — specialized coding). For tasks involving screenshots or UI, prefer Model A. For pure complex algorithms or large refactors, use Model B. Always explain which model you're routing to and why."



## Learnings
- CLAUDE.md is essential
- Limit available tools to e.g. "Bash,Edit,Read,Write,Glob,Grep"
- Agent choice is essential
- 


MLX/GGUF <-> Headroom (token compression) <-> Claude Code


GGUF: (llama.cpp)
- Qwen3.6-27B-Q4_K_M.gguf
- unsloth/Qwen3.6-27B-GGUF:UD-Q5_K_XL
(    --hf-repo "unsloth/Qwen3.6-27B-GGUF"
    --hf-file "Qwen3.6-27B-UD-Q5_K_XL.gguf"
)

MLX: (LMStudio)
- unsloth/Qwen3.6-27B-UD-MLX-6bit
- unsloth/Qwen3.6-27B-UD-MLX-4bit

## Different Agent?
- Claude Code alternative since it was leaked? Open Claude?

omlx instead of lmstudio?



## What is optimal use of claude code with local llms?

## CLAUDE.md

```bash
➜  local-llm git:(main) ✗ claude --version
2.1.207 (Claude Code)
➜  local-llm git:(main) ✗ 
```

```markdown
# Project instructions

## Response style

- Be concise and direct.
- Use tools immediately instead of narrating what you intend to do.
- Do not repeatedly say that you will inspect, search, or read something.
- Do not reread unchanged files.
- When a tool returns file contents, analyze those contents directly.
- Do not infer file contents from filenames.
- Keep normal final responses under five concise bullets unless more detail is requested.
- Avoid repeating information already established in the conversation.

## Tool behavior

- Use Bash when current system information is requested, such as date, time, processes, files, or environment variables.
- Prefer targeted searches over broad repository scans.
- Read the smallest set of files necessary to answer the question.
- When analyzing scripts, refer to the actual variables and commands found in them.
- After editing shell scripts, run `bash -n <script>` to check syntax.
- Do not make destructive changes without explicit approval.

## Local LLM architecture

- `start-llama.sh` starts llama.cpp on `127.0.0.1:8080`.
- `start-headroom-claude.sh` starts Claude Code through Headroom.
- Headroom proxies Anthropic requests to the llama.cpp server.
- The llama.cpp model alias is `qwen3-vl-30b-a3b`.
- Stop all child processes cleanly when the orchestrating script exits.
```

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
