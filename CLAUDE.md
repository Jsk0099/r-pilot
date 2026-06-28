# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Start the server (runs in the repo you want reviewed — not in this directory)
node server.js

# Collect review scope manually (read-only, no modifications)
node scripts/collect_review_scope.js --base main --role "UI Developer"
node scripts/collect_review_scope.js --base develop --role "Backend Developer"
node scripts/collect_review_scope.js --base main --extensions ".ts,.tsx" --extensions-only

# Budget flags for large branches
node scripts/collect_review_scope.js --base main --role "UI Developer" --no-prescan --no-diffs --max-files 25
```

Environment variables:
- `rpilot_PORT` — HTTP port (default `3922`)
- `rpilot_CHUNK_THRESHOLD` — max diff bytes per Claude call (default `80000`)

## Architecture

Review Pilot is a single-process Node.js HTTP server (`server.js`) that wraps the Claude Code CLI binary. It has no build step and no framework — raw `http.createServer`.

```
server.js                   — HTTP server, routing, chunking orchestration
lib/
  claude-client.js          — spawns Claude binary, streams NDJSON → SSE
  logger.js                 — per-session NDJSON log files under logs/
scripts/
  collect_review_scope.js   — deterministic git scope collector (read-only)
ui/index.html               — browser UI (vanilla HTML/JS, no bundler)
r-pilot/SKILL.md            — the system prompt injected into every review
```

### Request flow

1. Browser POSTs to `/review` with `{ base, role, extraExtensions, ... }`.
2. `server.js` spawns `scripts/collect_review_scope.js` via `child_process.spawn`. The script runs `git` commands and returns a JSON payload with changed files, filtered by role/extension, with pre-scanned findings and trimmed diffs.
3. `server.js` optionally splits that payload into chunks (`buildScopeChunks`) when total diff bytes exceed `CHUNK_DIFF_THRESHOLD`.
4. Each chunk is sent to Claude via `lib/claude-client.js → runClaude()`, which spawns the `@anthropic-ai/claude-code` native binary with `--permission-mode bypassPermissions`. The prompt is fed over stdin (not a CLI arg) to avoid Windows command-line length limits. Continuation chunks reuse the same Claude session via `--resume <sessionId>`.
5. Claude's `stream-json` NDJSON output is forwarded to the browser as SSE events: `step`, `scope`, `chunk`, `result`, `log`, `done`, `error`.
6. After Claude returns a review report, the browser POSTs to `/approve` with the session ID and approval text. This resumes the same Claude session so the AI applies only the approved fixes.
7. `/kill` aborts all live Claude processes and exits the server. `/shutdown` exits cleanly.

### Two claude-client files

| File | Purpose |
|---|---|
| `lib/claude-client.js` | Production layer: SSE streaming, `bypassPermissions`, `DISALLOWED_TOOLS`, stdin prompt delivery, abort support, pino-compatible logging. Used by `server.js`. |
| `claude-client/claude-client.js` | Standalone utility: one-shot `askClaude(prompt)` returning a Promise. No SSE, no permission flags, no abort. Useful for scripts and tests. |

### Permission model

`lib/claude-client.js` always passes `--permission-mode bypassPermissions` and a hardcoded `DISALLOWED_TOOLS` list that blocks all destructive git operations (`commit`, `push`, `merge`, `reset`, `clean`, `rm -rf`, etc.). Claude can read and edit files but cannot commit or push without the user acting outside rpilot.

### System prompt

`r-pilot/SKILL.md` (frontmatter stripped) is read once at startup and injected as `--append-system-prompt` on the first chunk of every review. Continuation chunks (`chunkIndex > 0`) skip re-sending it to save tokens — it's already in the conversation history.

### Large-file handling

`scripts/collect_review_scope.js` splits very large individual file diffs into `diff_chunks`. After the main chunked review completes, `server.js` runs a file merge pass (`processFileMergePass`) that sends remaining diff parts and asks Claude to consolidate findings per file.

### Logging

`lib/logger.js` writes NDJSON to `logs/<branch-slug>.log` (e.g. `logs/main.log`). Each review session creates a fresh file; if a file already exists a numeric suffix is appended (`main-2.log`). The browser can also write entries via POST `/client-log`.
