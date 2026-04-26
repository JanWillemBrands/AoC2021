# Layout-Sensitive Parsing in APUS

## Problem

Many languages encode syntactic structure through whitespace: Python uses indentation for blocks, Haskell has the offside rule, Go and JavaScript have automatic semicolon insertion, Swift distinguishes prefix/postfix operators by adjacency. A general parser framework needs to handle these without language-specific hacks in the parser core.

## Design Criteria

1. **Parser-agnostic** — The GLL algorithm and its data structures (descriptors, CRF, BSR) must not change. Layout sensitivity is handled entirely outside the parser.
2. **Grammar-driven** — Whether and how layout applies is determined by the grammar file (presence of `>>|`/`|<<` terminals, future annotation syntax), not by code changes.
3. **Lazy and lightweight** — Spatial facts are computed on demand from existing data (token positions in the input string). No additional scanning pass, no auxiliary arrays.
4. **General** — The same mechanism should cover indentation (Python, Haskell), adjacency (Swift operators), and line-break sensitivity (ASI in Go/JS). Language-specific details are parameters, not code.

## Options Considered

### Option A: Adams-style IS-CFG (2013)

Embed column constraints directly into grammar symbols and check them during parsing. Each grammar position carries an indentation predicate; the parser evaluates it at every step.

**Rejected because**: Requires deep modifications to the parser core (violates criterion 1). Column predicates in every grammar symbol add complexity to the grammar representation. The approach is theoretically cleaner but not worth the implementation cost when the parser already handles ambiguity naturally.

### Option B: TeX-style preprocessing

A standalone pass that reads raw characters, tracks indentation, and emits a transformed character stream with explicit block delimiters (like TeX's `\begin`/`\end`). The scanner then tokenizes the transformed stream.

**Rejected because**: Operates below the token level, complicating error recovery and position tracking. The transformation must understand enough about tokenization to avoid injecting delimiters inside strings, comments, or multi-line tokens — essentially reimplementing parts of the scanner.

### Option C: GapChannel + token injection (chosen)

A three-layer architecture where spatial facts are computed lazily from token positions, synthetic tokens are injected pre-parse, and constraint annotations are checked post-parse. The parser runs unchanged on an augmented token stream.

**Chosen because**: Clean separation of concerns. Each layer is independently testable. The parser sees `>>|`/`|<<` as ordinary terminals — no special cases. GLL's ambiguity handling naturally accommodates the additional tokens. Position recovery works because synthetic tokens use zero-length Substrings anchored in the original input.

## Architecture

```
Layer 1:  GapChannel          — computes spatial facts from token positions
Layer 2:  injectLayoutTokens  — injects >>| / |<< tokens pre-parse
Layer 3:  (future)            — checks >:< <:> >.< <.> constraints post-parse
```

### Layer 1: GapChannel

A lazy struct that answers three spatial questions about adjacent tokens:

| Field | Type | Question |
|-------|------|----------|
| `empty` | `Bool` | Are the tokens touching (zero characters between)? |
| `lineBreaks` | `Int` | How many line breaks separate them? |
| `column` | `Int` | What column does the next token start at? |

**Computation**: For `gaps[i]`, examine the input string between the previous token's start and the current token's start. The span starts at the previous token's *start* (not end) so that newlines consumed by visible tokens (e.g. Python's NEWLINE) are still detected.

**Column counting**: Walk backwards from the token's start index to the preceding line break, counting Characters (grapheme clusters) with tab expansion. This matches what language specifications mean by "column."

**`\r\n` handling**: The sequence `\r\n` counts as one line break, not two.

**Lives in**: `Scanner.swift`, alongside `tokens` and `trivia`. Accessed via `scanner.gaps`.

### Layer 2: Token injection

A free function that reads the GapChannel and modifies the token/trivia arrays in place:

```swift
func injectLayoutTokens(
    tokens: inout [Token],
    trivia: inout [[Token]],
    gaps: GapChannel,
    bracketPairs: [(open: String, close: String)]
)
```

**Algorithm**:
- Maintain an indent stack (initially `[0]`) and a bracket depth counter.
- For each token, if a line break occurred and we're outside brackets:
  - Column increased → push indent, emit `>>|`
  - Column decreased → pop indent(s), emit `|<<` for each level
- At end-of-string (`○`), emit `|<<` for each remaining indent level.
- Newline-only tokens (visible NEWLINE terminals) are passed through without triggering indent/dedent, preventing blank lines at column 0 from causing false dedents.

**Synthetic tokens** use zero-length Substrings (`input[idx..<idx]`) so that `token.image.base` remains the original input string. This preserves position recovery for error messages.

**Bracket suppression**: Languages specify which token pairs suspend indent tracking. Python uses `[("(", ")"), ("[", "]"), ("{", "}")]`. A language without bracket exemption passes `[]`.

**Lives in**: `LayoutTokenInjection.swift`. Called from `main.swift` between scanning and parsing, gated on `grammar.symbolToID[">>|"] != nil`.

### Layer 3: Constraint annotations (future)

Four spatial constraint annotations for grammar rules:

| Annotation | Meaning | Gap field |
|------------|---------|-----------|
| `>:<` | Tokens must be adjacent (no gap) | `empty` |
| `<:>` | Tokens must not be adjacent | `!empty` |
| `>.<` | Tokens must be on the same line | `lineBreaks == 0` |
| `<.>` | Tokens must be on different lines | `lineBreaks > 0` |

These would be checked post-parse by filtering the derivation forest. The GLL parser produces all candidate parses; derivations violating spatial constraints are discarded. This is natural for GLL — layout constraints are just another disambiguation mechanism, like Schrodinger exclusion sets.

Not yet implemented. The GapChannel foundation supports it when ready.

## Language Coverage

| Language | Mechanism | GapChannel fields used |
|----------|-----------|------------------------|
| Python | INDENT/DEDENT | `lineBreaks` + `column` |
| Haskell | Offside rule | `lineBreaks` + `column` |
| F#, Nim | Indent blocks | `lineBreaks` + `column` |
| Swift | Operator adjacency | `empty` |
| Go, JS | Automatic semicolons | `lineBreaks` |
| YAML | Block styles | `lineBreaks` + `column` |
| Markdown | Blank-line paragraphs | `lineBreaks` (count > 1) |

## Files

| File | Role |
|------|------|
| `Scanner.swift` | Gap, GapChannel structs; `scanner.gaps` computed property |
| `LayoutTokenInjection.swift` | `injectLayoutTokens()` free function |
| `main.swift` | Wiring: calls injection between scan and parse |
| `*.apus` grammar files | Use `>>|` / `|<<` terminals to define indented blocks |

## References

- Adams, M.D. (2013). "Principled parsing for indentation-sensitive languages." *POPL 2013.* — The IS-CFG approach we considered and deferred.
- Scott, E. and Johnstone, A. — GLL papers (see CLAUDE.md for full references).
- CPython Grammar/python.gram — Reference for Python's INDENT/DEDENT semantics.
