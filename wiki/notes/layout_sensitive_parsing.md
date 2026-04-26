# Layout-Sensitive Parsing

Date: 2026-04-26

## What We Built

Three-layer architecture for handling Python-style INDENT/DEDENT and similar layout rules without touching the parser core.

### Layer 1: GapChannel (Scanner.swift)

Lazy struct. Computes spatial facts between adjacent tokens on demand from their Substring positions in the original input. No caching, no auxiliary arrays.

Three fields:
- `empty` — tokens touching? (for future `>:<` / `<:>`)
- `lineBreaks` — how many lines apart? (for `>>|` / `|<<` and future `>.<` / `<.>`)
- `column` — column on the line (for indent level)

Key design choice: scan from previous token's START (not END) to current token's start. This catches newlines inside visible NEWLINE tokens that would leave zero characters in the inter-token gap.

`\r\n` counts as one line break, not two.

### Layer 2: Indent Injection (LayoutTokenInjection.swift)

Free function `injectLayoutTokens(tokens:trivia:gaps:bracketPairs:)`. Reads GapChannel, injects synthetic `>>|`/`|<<` tokens. Called between scanning and parsing.

Algorithm: indent stack starting at [0]. On each token with a line break before it, compare column to stack top. Push on indent, pop on dedent. At EOS, emit remaining dedents.

Bracket pairs (configurable) suppress indent tracking inside `()`, `[]`, `{}`.

Visible NEWLINE tokens (image is only `\n`/`\r`) are skipped — they sit at column 0 but carry no indentation intent.

### Layer 3: Constraint Checking (future)

`>:<` `<:>` `>.<` `<.>` would be checked post-parse by filtering the derivation forest. GapChannel provides the data. Not implemented yet.

## Why This Design

- Parser core stays untouched — no new code paths in the GLL algorithm
- GapChannel is pure observation — read-only, no mutations
- Works for Python, Haskell, F#, Nim, YAML — anything with column-based structure
- Adams (2013) IS-CFG approach rejected: too invasive, requires parser-level column tracking

## Files

- `Scanner.swift` — Gap, GapChannel structs
- `LayoutTokenInjection.swift` — injectLayoutTokens()
- `main.swift` — wiring (conditional on `>>|` in grammar)
- `Layout Sensitive Parsing.md` — full design document

## Python Grammar Status

`grammars/Python/Python.apus` — 32 test messages, all parsing. Covers expressions, simple statements, compound statements (if/else/elif, for, while, def, class), and indented blocks with blank lines.
