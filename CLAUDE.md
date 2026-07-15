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

## Evidence and convergence protocol

- Never claim a command, build, test, lint, or typecheck succeeded unless
  its exit code was 0 in the current turn.
- Starting a development server does not prove that the production build passes.
- Quote the exact validation command and result in the final response.
- If the same command fails twice with substantially the same output:
  - do not run it again unchanged;
  - inspect the current directory, relevant manifest, and exact error;
  - choose a materially different next action.
- Never state that a file or project is correct solely because it looks plausible.
- Do not declare completion while any known syntax, build, test, or tool error remains.

## Existing-file editing protocol

- Prefer Edit for small changes to existing files.
- Use Write on an existing file only for an intentional complete replacement.
- Before a complete replacement:
  1. Read the full current file.
  2. Identify content that must be preserved.
  3. Write one complete, self-consistent replacement.
- After replacing a file, immediately reread it and check for:
  - duplicate imports;
  - duplicate functions;
  - duplicate configuration keys;
  - multiple default exports;
  - remnants of starter code;
  - imports of deleted files;
  - unbalanced JSX, CSS, brackets, or braces.
- Never merge a replacement implementation with unrelated old file contents.

## Shell-command protocol

- Run project commands from the directory containing the relevant manifest.
- Use the package-manager scripts declared in package.json.
- Prefer `npm run build` over invoking Vite through npx when a build script exists.
- Before running a Node command, read package.json once and identify the exact script.
- Never use `killall`, `pkill`, or broad process termination.
- Capture the PID of processes started during the task and terminate only that PID.