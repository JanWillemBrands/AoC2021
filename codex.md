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
