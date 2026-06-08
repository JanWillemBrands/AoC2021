# Multi-Lex (LCNP) Adoption Design

Plan to adopt Scott & Johnstone's **LCNP** (lex-call-no-precompute) parser-driven lexer interaction (SLE 2019, *Multiple Lexicalisation — A Java Based Study*, in-tree at `articles/raw/Multiple Lexicalisation - A Java Based Study.txt`) as the unifying replacement for APUS's accumulated lexer-level disambiguation machinery: Schrödinger duals, Frankenstein `~~~`, `<<1`/`<<2` regex lookbehind, `---()` exclusion sets, and the parser-level regex CFG that Codex sketched today.

This is a *design* doc — no code yet. Independent review (Codex) is requested before any implementation. Numbers and quotes throughout cite the paper for verifiability.

## Motivation

APUS has accumulated five disambiguation mechanisms in front of the GLL parser:

| Mechanism | Solves | In-tree doc |
|---|---|---|
| Schrödinger duals + `---()` exclusion | Keyword/identifier overlap, "this dual is suppressed in this rule" | `Advent/Schrodinger Tokens.md` |
| Frankenstein `~~~` | `>>` / `==` / `&&` partial-token splits where multi-char scanner tokens need to be parser-split | `Advent/Frankenstein Tokens.md` |
| `<<1` / `<<2` (`++1` / `--1` / `++2` / `--2`) | Regex-vs-division and similar position-gated tokenisation | `Advent/Regex Lookbehind Design.md` |
| `>>1(...)` parse-time lookahead | Swift's `isGenericTypeDisambiguatingToken` follow-set commit | `Advent/Structured Lookahead Design.md` |
| Parser-level regex CFG (Codex's recent fix) | `(/E.e).foo(/0)` over-claim; balanced delimiters inside regex body | `Advent/Regex CFG Discussion.md` |

Today's debugging of `Array<Array<Int>>` ambiguity, the regex CFG roll-out, and the discovery that 10 of 47 Swift cases still fail at the *scanner* layer (categories B and E — invalid-hex inside regex, editor placeholders) made it clear these five mechanisms are all attacking facets of the same problem: **the lexer is making longest-match commitments before the parser has the context to validate them.**

LCNP collapses all five into one uniform interface and matches the published GLL state of the art (Scott & Johnstone 2019). The cost is a structural refactor — character-position addressing throughout the BSR/CRF/Oracle stack — but the design is well-defined in the paper with measured Java numbers (Life.java parses in <0.099s with 3×10⁷⁵⁸ indexed lexicalisations under no disambiguation).

## The LCNP Design (Paper Summary)

### Core API

The parser calls the lexer on demand, per requested terminal:

```
lex(u, t) = { j  |  u[0..j) ∈ language(t) }
```

For each character position `i` and each terminal `t` predicted by the grammar at that point, `lex(i, t)` returns the **set of valid end indices** at which `t` matches. Empty set means the terminal doesn't match here.

A second variant is exposed for lookahead-aware lexing:

```
lexLKH(t, i, β, X) = lex(i, t) ∩ { j  |  valid(j, predict(β, X)) }
```

where `predict(β, X) = first(β) ∪ (follow(X) if β nullable)` — i.e. the parser's local follow set is passed to the lexer to prune impossible matches. APUS already computes these sets (used in `continuationViable` and `testSelect`) so the data is available; the API hook is new.

### Position model

**Character positions throughout.** Token-position addressing disappears. BSRs are `(slot, i, k, j)` where i/k/j are character indices into the input string. From the paper:

> *"An indexed token string is a sequence of pairs of the form (t, h) where t is a token and h is an integer."* (l. 829-830)

Sharing in the BSR is dramatic when many lexicalisations coexist:

> *"so (t, 2) appears at positions 0 and 1 and so it is only considered twice even though it appears four times in the ITSs"* (l. 2019-2021)

For the canonical `aaab` example with `lexFull()` returning 11 indexed lexicalisations, the **BSR has 14 elements covering all 10 valid ITSs** (l. 1891-1894). Per the paper:

> *"our implementation does parse Life.java in under 0.099 seconds"* (l. 2531) — across 3×10⁷⁵⁸ non-disambiguated indexed lexicalisations.

### Descriptor forking on terminal match

The descriptor processing loop fans out when a terminal is consumed:

> *"If β = xγ where x is a terminal then lex(c_I, x) is called. For each k ∈ lex(c_I, x) there is a lexeme in the pattern of x between positions c_I and j = c_I + k... For each j ∈ J a descriptor (X ::= αx·γ, c_U, j) is created"* (l. 1328-1335)

That is: one descriptor per valid end-position. The CRF dedup (same `(slot, position)` clusters) keeps this tractable.

### What LCNP says about Schrödinger tokens

Scott explicitly compares (l. 2851-2856) and concludes LCNP **subsumes** Schrödinger tokens for same-span ambiguity (`if` as keyword/identifier — `lex(pos, "if")` and `lex(pos, identifier)` both return the same end-pos; parser disambiguates by which terminal a slot needs). LCNP additionally handles **different-span** alternatives (`--` as one token vs `-` `-` as two) that Schrödinger duals cannot express because they fuse at a fixed span. From the paper:

> *"a Schrodinger token is returned. When the parser reaches that token it decides... but only one token string is actually parsed, so this is not multi-parsing."* (l. 2851-2856)

### Complexity

> *"worst case cubic in the length of the underlying character string"* (l. 898-899)

Same asymptotic class as token-level GLL. Empirical measurements (Table 4): LCNP/NoD on Life.java records `|U|=48187` descriptors and `|ϒ|=15719` BSR yields, compared to character-level SGLLJ's `|U|=303585` and SPPF 114923 nodes. LCNP is **~6× fewer descriptors and ~7× fewer output nodes** than scannerless character-level GLL — the parser-driven lexer is structurally cheaper than the parser-as-lexer.

## Mapping to APUS — What Collapses, What Stays

### Mechanisms that LCNP replaces

1. **Schrödinger duals + `---("if" "let" …)` exclusion.** Same-span ambiguity (keyword vs identifier) is handled by parser-side terminal selection. The `Token.dual` chain, `propagateExcludeSets()`, and `excludeBS` checks in `tokenMatch()` / `testSelect()` become dead code.

2. **Frankenstein `~~~` partial-token-match sentinel.** Different-extent alternatives (`>>` as one token vs `>` `>` as two) are first-class in LCNP — `lex(i, ">>")` returns `i+2`, `lex(i, ">")` returns `i+1`, both at the same position. The Frankenstein `≋` sentinel, `Grammar.frankensteinID`, the partial-match prefix-split code in `tokenMatch()` lines 295-310 and 328-335, and `cI.charOffset` (the only character-level coordinate currently in `TokenPosition`) all retire. Today's char-level operator grammar in `Swift.apus` (which sidestepped Frankenstein by tokenising `>` as a single char) also becomes redundant.

3. **`<<1` / `<<2` regex lookbehind annotations (`++1`/`--1`/`++2`/`--2`).** Position-gated tokenisation — "this terminal only matches after certain previous tokens" — collapses to "`lex(pos, terminal)` returns no end-positions where the grammar context wouldn't consume this terminal anyway". The grammar-derived `predict` set passed to `lexLKH` does the gating work that `<<1` did, but driven by the grammar's actual follow set rather than a manually maintained deny list. `LookbehindSpec`, `LookbehindRule`, `LookbehindLine`, and the `lookbehindAllows` check in `Scanner.swift:308-332` retire.

4. **Parser-level regex CFG (today's `plainRegularExpressionLiteral = "/" >s< regexBody >s< "/" .`).** Under LCNP the regex is *back* in the lexer as `lex(pos, regexLiteral)`, where the implementation can run a CFG acceptor internally and only return an end-pos if the body parses. The grammar stays clean (regex is a single terminal again), the `(/E.e).foo(/0)` over-claim is rejected by the lex-side validator, and the operator-overlap workaround (`regexNonOperatorAtom` + `regexAtom = operatorHead | …`) disappears. This is also where the deferred **candidate-validator** primitive lands — LCNP's `lex(pos, t)` is naturally a candidate validator.

5. **`>>1(...)` parse-time follow-set commit.** Already obsolete with LCNP: the equivalent rule is encoded via `lexLKH`'s use of `predict(β, X)` — the lexer only returns end-positions consistent with what the parser's next-symbol expectations allow.

### Mechanisms that LCNP does NOT replace

1. **`@unless(X)` parser-level alternate selection (Structured Lookahead Design).** LCNP is a lexer interface. Grammar-level ambiguity — same token kinds parseable under multiple productions, e.g. `Array<Array<Int>>` as generic vs comparison-chain — stays.

2. **`@longest` / `@shortest` / `@left` / `@right` Oracle rules.** Post-parse disambiguation over the BSR is independent of how tokens were produced.

3. **Scanner modes (gated transitions `=== "X" >>> "Y"`).** Stateful lexer dispatch (nested comments, f-string interpolations, raw-string custom delimiters) needs a state argument LCNP's pure `lex(pos, t)` doesn't include. See Open Questions §A.

4. **Layout-sensitive parsing** (`LayoutTokenInjection.swift`). Indentation-derived tokens still need synthesis from whitespace context; LCNP doesn't address.

## APUS-Shaped Lex API

Proposed Swift signature:

```swift
struct Lexeme {
    let kind: String          // Token.kind
    let end: String.Index     // character end position
}

protocol LCNPLexer {
    /// Return all valid end positions at which `terminal` matches starting at `pos`.
    /// Empty result means the terminal doesn't match here.
    func lex(at pos: String.Index, for terminal: String) -> [String.Index]

    /// Same as `lex`, but additionally filtered against `predict` — only return
    /// end positions whose next token's kind is in the predict set.
    /// Pure optimisation; the parser would otherwise discard the same descriptors.
    func lexLKH(at pos: String.Index, for terminal: String, predict: BitSet) -> [String.Index]
}
```

The default implementation can be a thin wrapper around the existing `TokenPattern` regex matching, returning `[match.endIndex]` or `[]`. Schrödinger handling falls out for free — different terminal queries at the same position can each return the same end-pos.

For multi-char operator splits (`>>` example):
- `lex(pos, ">>")` returns `[pos+2]` when the next 2 chars are `>>`
- `lex(pos, ">")` returns `[pos+1]` when the next 1 char is `>`
- Both queries at the same position can succeed simultaneously
- The parser explores both via descriptor forking

For regex with body validation:
- `lex(pos, plainRegularExpressionLiteral)` runs an internal regex-body acceptor
- Returns `[endPosOfValidBody+1]` (after the closing `/`) only when the body parses
- For `(/E.e).foo(/0)` the body acceptor rejects unbalanced `)`, returns `[]`
- For `^^/0xG/` the body acceptor accepts `0xG` as raw character content, returns `[endOfRegex]`

For keywords vs identifiers:
- `lex(pos, "if")` returns `[pos+2]` when chars at pos..pos+2 are `if` AND not followed by an identifier-continuation char (so `iffy` won't match `if`)
- `lex(pos, identifier)` returns `[pos+N]` where N is the identifier length — including `if` if the parser doesn't predict `"if"`
- The current `---("if" …)` exclusion sets become unnecessary — the grammar's predict set already encodes "this slot wants `"if"`, not `identifier`"

## Phased Rollout

Big-bang migration is too risky. The paper's design supports a clean phase-by-phase migration with parallel new and old code paths.

### Phase 0 — Capture the baseline

Before touching code: run the full SwiftSyntax 590-case sweep and the 47-message embedded test bed under today's grammar. Record per-case pass/fail and per-message derivation counts. This is the regression contract LCNP must meet.

### Phase A — Character positions in BSR, existing scanner pre-produces tokens

The smallest separable structural change. Replace `TokenPosition` (currently `(tokenIndex, charOffset)`) with `CharPosition` (a `String.Index`). The pre-scan still produces a token stream, but BSR yields, CRF clusters, and descriptors all carry character indices.

Touch list (estimated):
- `BinarySubtreeRepresentation.swift` — `BinarySpan` field types
- `Descriptor.swift` — position field type
- `CallReturnForest.swift` — `ParsePosition` key type
- `MessageParser.swift` — every `cI` / `cU` / `i` / `k` / `j` site
- `Oracle.swift` — `pruneUnproductive` reachability walk
- `DerivationBuilder` and `SPPFExtractor` — character extents in tree spans
- `GenerateDerivationDiagram.swift` — diagram labels
- Test infrastructure (`parseMatches`, `parseLanguageMessage`) — return-value comparisons that today rely on `TokenPosition`

Yields under this model still come from the pre-scanned token stream (one lexeme per source span). Schrödinger duals still encode same-span alternatives via the existing `Token.dual` chain. Nothing about disambiguation changes — only the positional addressing.

**Validation:** all 590 SwiftSyntax cases plus 47 embedded messages produce identical pass/fail outcomes. Derivation counts may differ trivially (character vs token-extent sharing in the BSR) but the ambiguity profile is unchanged.

### Phase B — Replace pre-scan with on-demand `lex(pos, terminal)`

The actual LCNP integration. The scanner no longer produces a `[Token]` array up front. Instead, the parser invokes `lex(pos, currentLabel.name)` whenever a `.T`/`.TI`/`.C` slot needs to consume a terminal. Multiple results fork into multiple descriptors.

Touch list:
- `Scanner.swift` — refactor from "produce all tokens" to "answer lex queries on demand". The existing regex/literal partitioning and `apply` logic stays; the orchestration changes.
- `MessageParser.swift:tokenMatch()` — return `[TokenPosition]` instead of `TokenPosition?`. Caller in the descriptor loop forks descriptors.
- `Scanner.swift:lookbehindAllows` retires.
- `Token.dual` chain becomes unused (each lex query independently returns the relevant end-positions).
- Frankenstein-related code in `tokenMatch` retires.
- Test infrastructure — `Scanner(fromString:patterns:)` becomes `LCNPScanner(input:patterns:)`, same surface but on-demand.

**Validation:** all 590 + 47 cases pass with the same ambiguity profile as Phase A, *plus* the 10 currently-failing scanner-content cases (categories B and E from today's run) should now parse.

### Phase C — Retire dead machinery

Remove:
- `Token.dual`, all Schrödinger plumbing
- `Grammar.frankensteinID`, `≋` sentinel handling
- `Grammar.propagateExcludeSets`, `GrammarNode.exclude` / `excludeBS`
- `LookbehindSpec`, `LookbehindRule`, `LookbehindLine`, `Scanner.lookbehindAllows`
- The regex-CFG productions in `Swift.apus` (revert to single `plainRegularExpressionLiteral` terminal, now backed by a lex-side CFG acceptor)
- The `>>1(...)` annotation field on `GrammarNode` and the `followAheadBS` check in `tokenMatch` (subsumed by `lexLKH`)

**Validation:** full sweep, plus the test bed for `Array<Array<Int>>` derivation count (still ambiguous at grammar level, controlled by `@unless`).

### Phase D — Apply `lexLKH` predict-set lookahead

Pure optimisation. Replace `lex(pos, terminal)` with `lexLKH(pos, terminal, predict)` where `predict` is the BitSet `cL.firstBS ∪ (followBS if nullable)` (already computed). Measures: descriptor count reduction, BSR yield count reduction, wall-clock improvement.

### Phase E — Stateful scanner modes (gated transitions) integration

Out-of-scope for Phases A–D. Either:
- Carry the mode in the LCNP API: `lex(pos, terminal, mode) -> Set<(endPos, newMode)>`
- Encode mode in the grammar (nested comments, f-strings as CFG rules)

See Open Questions §A.

## Open Questions

### §A — Scanner modes (gated transitions)

Today's `=== "X" [<<<] [>>> "Y"]` triples on terminals carry the lexer's modal state. LCNP's `lex(pos, t)` is stateless. Two paths:

1. **Stateful LCNP**: extend the API to `lex(pos, t, mode) -> Set<(endPos, modeAfter)>`. Parser threads the mode through descriptors. Cost: descriptor key grows; mode-state coverage in dedup.
2. **Grammar-encoded modes**: rewrite mode-using terminals as CFG productions (already partially done for multiline comments). Some cases are awkward — f-string interpolation with nested expressions, raw-string custom-pound delimiters.

Hybrid is likely: keep mode in the lex API for cases where the grammar can't carry it (raw-string `#`-count), grammar-encode the rest.

### §B — Whitespace and trivia

The paper defers (l. 624-625). APUS has `>s<`/`<s>` boundary annotations that gate based on inter-token whitespace. With character positions, these become character-adjacency checks (`prev.end == this.start`). Trivia (comments, action terminals) stays parallel to lexemes — probably as a separate `Scanner.trivia[]` field indexed by character position.

### §C — Performance on Swift workloads

Scott measures Life.java in <0.1s — but Java has clean token boundaries. Swift's regex literals, multi-pound string literals, and interpolated strings introduce content-validating lex calls that may dominate cost. Profile early.

### §D — `lexLKH` and grammar's existing `firstBS`/`followBS`

Should `lexLKH` filter by `firstBS(cL.seq)` (the immediate next-symbol predict set) or by a deeper lookahead? Paper uses single-step predict. Open whether multi-step would help Swift.

### §E — Memoisation of lex results

`lex(pos, t)` is pure given the input. Memoise by `(pos, terminalID)` → `Set<endPos>`? Cache hits are common when the parser revisits a position with the same terminal expectation. Cost: memory. Likely win.

### §F — Migration of `Token.image` and `Token.kindID`

Today's parser carries `Token.image: Substring` and `Token.kindID: Int` per token. Under LCNP, "tokens" become lex results — `(start, end, terminalID)` triples. Where does the textual content go? Probably: the input string is the source of truth, lex results carry start/end indices, callers slice when needed.

### §G — Test infrastructure

`parseMatches(grammar, message)` returns `Bool`. Under LCNP, the same semantics — just different internal addressing. Probably no API change needed, but every assertion that today compares `TokenPosition` values needs to compare `String.Index` values.

### §H — Generated parser code (`GenerateParser.swift`)

The generated standalone parser (currently for LL(1) grammars only) needs to track LCNP changes. Generation may need a Phase F to emit LCNP-shaped code.

## What This Does Not Address

- **Parser-level ambiguity** (`Array<Array<Int>>`, all `canParseAsXxx` decisions) — addressed by `@unless` (Structured Lookahead Design).
- **`@unless` cascade bug** (TODO 5 in `Advent/TODO.md`) — orthogonal; LCNP doesn't touch the Oracle's dead-wood propagation.
- **Performance on long inputs** generally — `pruneUnproductive` is already O(n²) per call; LCNP doesn't fix that.

## Per-File Change Inventory

Phase A (positions):
| File | Change | Size |
|---|---|---|
| `BinarySubtreeRepresentation.swift` | `BinarySpan` field types | small |
| `Descriptor.swift` | position field type | small |
| `CallReturnForest.swift` | `ParsePosition` key type | small |
| `MessageParser.swift` | replace `cI`/`cU` mechanics | medium |
| `Oracle.swift` | `pruneUnproductive`, `endPositions` | medium |
| `GenerateDerivationDiagram.swift` | label generation | small |
| `SPPFExtractor.swift` | character extents | small |
| `AdventTests/TestInfrastructure.swift` | helpers | small |

Phase B (LCNP):
| File | Change | Size |
|---|---|---|
| `Scanner.swift` | API: pre-scan → on-demand `lex` | **large** |
| `MessageParser.swift:tokenMatch` | return `[CharPosition]`, fork descriptors | medium |
| `Token` / `Lexeme` types | restructure | small |
| All `.apus` grammars | minor cleanups (Frankenstein `~~~` removal, lookbehind annotation removal) | small per file |
| `Swift.apus` | regex CFG → regex terminal with lex-side acceptor | medium |
| `Advent/Frankenstein Tokens.md`, `Advent/Schrodinger Tokens.md`, `Advent/Regex Lookbehind Design.md` | mark superseded, link to this doc | small |

Phase C (retire):
| File | Change |
|---|---|
| `Token.swift` | drop `dual` chain |
| `Scanner.swift` | drop `lookbehindAllows`, `LookbehindSpec`, etc. |
| `Grammar.swift` | drop `frankensteinID`, `propagateExcludeSets` |
| `GrammarNode.swift` | drop `exclude`/`excludeBS`/`followAheadBS` fields |
| `ApusParser.swift` | drop `~~~`, `---()`, `++N/--N` and `>>1` parsing |

Total estimated effort: **2–4 weeks of focused work**, dominated by Phase B's scanner-API redesign and Phase A's BSR position-model migration. Phases C–E are smaller cleanups and optimisations.

## References

In-tree:
- Scott & Johnstone, *Multiple Lexicalisation — A Java Based Study*, SLE 2019 — `articles/raw/Multiple Lexicalisation - A Java Based Study.txt`
- Scott & Johnstone, *GLL Syntax Analysers for EBNF Grammars*, SLE 2016 — `articles/raw/GLL Syntax Analysers For EBNF Grammars.txt`
- Afroozeh, *Practical General Top-Down Parsers*, PhD 2018 — `articles/raw/Practical general top-down parsers.txt`

Project docs (will be superseded or cross-referenced):
- `Advent/Schrodinger Tokens.md`
- `Advent/Frankenstein Tokens.md`
- `Advent/Regex Lookbehind Design.md`
- `Advent/Structured Lookahead Design.md`
- `Advent/Regex CFG Discussion.md`
- `Advent/Scanner Mode Design.md`

External (cited in paper):
- Aycock & Horspool — Schrödinger token approach
- Visser — SDF/SGLR scannerless GLR (compared as related work)
- Ford — PEG (compared as related work)

## Adoption Decision

Recommended: proceed with Phase 0 (capture baseline) immediately. Defer Phase A start until independent review (Codex) of this doc is complete. The structural cost is real, but five accumulating mechanisms collapsing into one principled interface — backed by Scott & Johnstone's measured implementation — is a positive ratio.
