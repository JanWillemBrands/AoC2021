# Local Wiki

Minimal local retrieval setup inspired by Karpathy's "personal wiki" workflow.

## What It Does

- Scans project text/code files.
- Splits them into overlapping chunks.
- Builds a local SQLite FTS5 index for fast lookup.
- Lets you query relevant chunks quickly from terminal.

## Included

- `tools/wiki/build_wiki.py` - index builder
- `tools/wiki/query_wiki.py` - query CLI
- `wiki/index.db` - generated index (created when you run build)
- `wiki/notes/` - your distilled notes and decisions

## Quick Start

From repo root:

```bash
python3 tools/wiki/build_wiki.py --root . --db wiki/index.db
python3 tools/wiki/query_wiki.py "parser oracle"
python3 tools/wiki/query_wiki.py "SPPF binarized node"
```

## Suggested Workflow

1. Pull facts from papers into short notes in `wiki/notes/`.
2. Keep design decisions and tradeoffs there (with date + rationale).
3. Query the index before making parser changes.
4. After any material code/design change, update the relevant `wiki/notes/*.md` page in the same change pass.
5. Rebuild index after major edits:

```bash
python3 tools/wiki/build_wiki.py --root . --db wiki/index.db
```

## Context Restore Protocol (For Future Chats)

Start with:

1. `wiki/notes/00_CONTEXT_MAP.md`
2. `wiki/notes/trivia_oracle_decisions.md`
3. `wiki/notes/swift_trivia_inventory.md`
4. `wiki/notes/annotation_spec_trivia.md`
5. `wiki/notes/schrodinger_frankenstein_boundary.md`
6. `wiki/notes/layout_sensitive_parsing.md`
7. `wiki/notes/apus_gotchas.md`

Then query:

```bash
./wiki-search "trivia oracle parser gating equivalence proof" 5
./wiki-search "Swift trivia inventory infix prefix postfix whitespace" 5
./wiki-search "annotation >:< >.< >+< >#< <?>" 5
```

Also read the consolidated task list:

8. `Advent/TODO.md` (canonical markdown TODOs)

## Notes

- Excludes common build/system directories by default (`.git`, `.build`, `DerivedData`, `Products`).
- Includes: `.txt`, `.md`, `.swift`, `.apus`, `.gv`.
- `wiki/notes/` is indexed on purpose for context restore.
- This is lexical retrieval (FTS5), no external embedding dependency required.
