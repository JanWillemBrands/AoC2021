# Context Map (Read This First)

Date: 2026-05-03

Purpose: fast context restore for future chats.

## Canonical Decisions

1. Trivia rules: oracle-first, parser-second (only after equivalence proof).
2. Frankenstein stays parser-level.
3. Schrodinger stays parser-level.
4. Scanner modes stay scanner-level.
5. Use 3-char edge annotations for trivia constraints.
6. Layout-sensitive parsing: two-layer architecture (indent injection + constraint checking). Spatial facts computed lazily from token positions. Parser core untouched.
7. APUS comments are `//`. Never use `#`.
8. Markdown TODO source of truth is `Advent/TODO.md`.

## Canonical Docs

1. Root docs
- `Trivia Oracle.md`
- `Schrodinger Tokens.md`
- `Frankenstein Tokens.md`
- `Layout Sensitive Parsing.md`
- `claude.md`
- `Advent/TODO.md`

2. Wiki docs
- `wiki/notes/trivia_oracle_decisions.md`
- `wiki/notes/swift_trivia_inventory.md`
- `wiki/notes/annotation_spec_trivia.md`
- `wiki/notes/schrodinger_frankenstein_boundary.md`
- `wiki/notes/layout_sensitive_parsing.md`
- `wiki/notes/apus_gotchas.md`

## Quick Query Prompts

Use with `./wiki-search "<query>" 5`.

1. `trivia oracle parser gating equivalence proof`
2. `Swift trivia inventory infix prefix postfix whitespace`
3. `annotation >:< >.< >+< >#< <?>`
4. `Frankenstein Schrodinger boundary`
5. `minimal Swift rule patch try? as? postfix ! ?`
6. `copy newline context sensitive keyword`
7. `indent injection layout Python columnOf`
8. `APUS gotchas comments message blocks`

## Current Implementation Status

1. Design docs complete (trivia, layout, tokens).
2. Inventory documented.
3. Annotation set documented.
4. Layout-sensitive parsing implemented and tested (lazy spatial computation + indent injection).
5. Python grammar: 32 test messages, all parsing.
6. Exclusion sets, Schrödinger tokens, Frankenstein tokens: all implemented and tested.
7. No parser/oracle code changes implemented yet for new trivia checks.
8. Consolidated markdown TODO tracking is active in `Advent/TODO.md`.

## Next Build Steps

1. Define `TriviaBoundaryFacts`.
2. Implement oracle predicates.
3. Wire annotation -> constraint records.
4. Add differential mode (oracle-only vs parser-gated).
5. Promote only proven-local rules.
6. Implement Layer 3 constraint checking (`>:<` `<:>` `>.<` `<.>`).

## Deferred Detection (parser/oracle, not scanner)

Layout injection (Layer 2) deliberately does NOT enforce language-specific constraints. These must be checked later by the parser or oracle:

- **Misaligned dedent**: a dedent to a column that was never an indent level (Python `IndentationError`). The injector pops to the nearest prior level and continues — the grammar or oracle must reject the invalid structure.
- **Mixed tabs/spaces**: `columnOf(_:tabWidth:)` computes column with a fixed tab width. Languages that forbid mixing (Python 3) need a separate check.
- **Semantic indent constraints**: e.g. Haskell's "first token after `where`/`let`/`do` sets the block column" — these are grammar-driven, not scanner-driven.

General principle: Layer 2 injects `>>|`/`|<<` based on spatial facts only. Structural validity is the parser's job. Keep the injection function language-agnostic.
