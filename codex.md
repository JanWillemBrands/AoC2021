# Codex Local Instructions

- If a common tool is missing (example: `pdftotext`), ask the user first whether they want it installed.
- While a long-running install is in progress, provide periodic progress updates (or at minimum a brief "I'm alive" status).

## Local Wiki Retrieval

- Build or refresh index with `./wiki-build`.
- Query with `./wiki-search "your query"` (optional second arg is top N, example: `./wiki-search "parser oracle" 12`).
- Backing scripts:
  - `tools/wiki/build_wiki.py`
  - `tools/wiki/query_wiki.py`
- Backing data:
  - `wiki/index.db`
  - `wiki/notes/`
- Keep wiki synchronized with code/docs changes:
  - After any material parser, grammar, scanner, test, or design-doc change, update the relevant `wiki/notes/*.md` page in the same work pass.
  - If no existing note fits, create a new note and add it to `wiki/notes/00_CONTEXT_MAP.md`.
  - Rebuild the index after wiki note updates (`./wiki-build`).

## TODO Source Of Truth

- Read `Advent/TODO.md` for consolidated markdown TODOs.
- Add new markdown TODO items there instead of duplicating lists across assistant notes.

## Response Latency Learnings (May 2026)

- Default to fast mode unless the user asks otherwise: minimal reads, targeted edits, no full build/test by default.
- If a command takes longer than about 90 seconds, stop and switch to a lighter strategy instead of waiting indefinitely.
- For local shell commands, prefer short timeouts/yield windows and report rejection/failure immediately instead of appearing stuck.
- When a command is blocked or interrupted, report that status clearly and continue with a fallback path.
- If the user asks for periodic status, send brief progress updates at least once per minute until the task completes.
- For zsh-pasted scripts, prevent history-expansion issues by using `set +H` and quoted heredocs (`<<'EOF'`).
- Keep structural reorganization commits separate from parser/feature changes so rollback and review stay manageable.
