# Layout-Sensitive Parsing

Date: 2026-04-26
Updated: 2026-05-04

## What We Built

Two-layer architecture for handling Python-style INDENT/DEDENT and similar layout rules without touching the parser core.

### Spatial Computation

All spatial facts are computed lazily from token `image.startIndex`/`endIndex` positions in the original input string. No auxiliary data structures — the original `GapChannel` struct was removed in favour of inline computation.

Key utilities in `StringExtensions.swift`:
- `String.columnOf(_:tabWidth:)` — scans forward from line start to index, with tab expansion
- `String.linePosition(of:)` — returns `"L{line}P{position}"` for diagnostics, handles `\n`, `\r`, `\r\n`

Key design choice: line break detection scans from previous token's START (not END) to current token's start. This catches newlines inside visible NEWLINE tokens that would leave zero characters in the inter-token gap.

`\r\n` counts as one line break, not two (the `prevWasCR` guard).

### Layer 1: Indent Injection (LayoutTokenInjection.swift)

Free function `injectLayoutTokens(tokens:trivia:input:tabWidth:bracketPairs:)`. Computes line breaks and columns inline, injects synthetic `>>|`/`|<<` tokens. Called between scanning and parsing.

Algorithm: indent stack starting at [0]. On each token with a line break before it, compare column to stack top. Push on indent, pop on dedent. At EOS, emit remaining dedents.

Bracket pairs (configurable) suppress indent tracking inside `()`, `[]`, `{}`.

Visible NEWLINE tokens (image is only `\n`/`\r`) are skipped — they sit at column 0 but carry no indentation intent.

### Layer 2: Constraint Checking (future)

`>s<` `<s>` `>n<` `<n>` — spatial constraints between adjacent symbols in a grammar sequence. Design direction: model as a new `GrammarNodeKind` (pass-through node in the grammar graph). Checked during parsing, not post-parse.

## Why This Design

- Parser core stays untouched — no new code paths in the GLL algorithm
- All spatial facts derived lazily from token positions — no auxiliary arrays
- Works for Python, Haskell, F#, Nim, YAML — anything with column-based structure
- Adams (2013) IS-CFG approach rejected: too invasive, requires parser-level column tracking

## Files

- `StringExtensions.swift` — `columnOf(_:tabWidth:)`, `linePosition(of:)`
- `LayoutTokenInjection.swift` — `injectLayoutTokens()`
- `main.swift` — wiring (conditional on layout token usage in grammar)
- `Layout Sensitive Parsing.md` — full design document

## Python Grammar Status

`grammars/Python/Python.apus` — 32 test messages, all parsing. Covers expressions, simple statements, compound statements (if/else/elif, for, while, def, class), and indented blocks with blank lines.
