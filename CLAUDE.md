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

## File-reading protocol

- When exact file contents are needed, call Read once.
- If Read returns "Unchanged since last read" without the file contents:
  - Do not call Read on that file again.
  - Immediately use Bash with `cat -n -- "<path>"` to obtain the contents.
- Treat "Unchanged since last read" as a cache status, not as file content.
- Never claim a file is unavailable after a successful Read or Bash result.
- Never reread the same unchanged file repeatedly.
- After reading multiple related files, retain a concise working-set summary containing:
  - file path
  - responsibility
  - important functions or variables
  - relationships to the other files
- Before editing, ensure the exact current contents are present in the active context.

## Session-state protocol

Use `.claude/session-state.md` as concise working memory.

Update it after completing a major exploration or implementation phase with:

- current objective
- architecture discovered
- files inspected and their roles
- decisions made
- modifications completed
- test results
- unresolved issues
- next concrete action

Keep it under 150 lines.

Read it once at the beginning of a resumed session or after context compaction.
Do not repeatedly read it during every tool call.

## Local LLM architecture

- `start-llama.sh` starts llama.cpp on `127.0.0.1:8080`.
- `start-headroom-claude.sh` starts Claude Code through Headroom.
- Headroom proxies Anthropic requests to the llama.cpp server.
- The llama.cpp model alias is `qwen3-vl-30b-a3b`.
- Stop all child processes cleanly when the orchestrating script exits.
