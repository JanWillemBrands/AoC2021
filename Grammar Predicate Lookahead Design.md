# Grammar-Predicate Lookahead

**Status:** design, 2026-08-21. Supersedes the retired `@unless` and the procedural
`@within` filter for the lookahead/lookbehind family. Companion: `Oracle.md`.

## What it is

A single declarative primitive for "commit to this reading **iff** grammar symbol `N`
does / does not derive at this point" — the general form of swift-syntax's ~32
`canParseAsXxx` / `atStartOfXxx` predicate-gated choices. The condition is an ordinary
grammar symbol, evaluated by the parser we already ran; there is no hand-written Swift
predicate.

It fills the gap that extent/associativity annotations cannot reach: `@longest`/`@shortest`
choose an **extent**, `@prefer` chooses among **same-span** alternates, `@left`/`@right`
choose a **pivot**. None can express "pick reading A here *because* `N` can (or cannot)
parse here" — a **conditional** choice. That condition is the payload swift-syntax's
recursive descent carries in its lookahead routines, and it is what this primitive adds.

## The four glyphs

Outer angles give **direction** (`>…>` forward, `<…<` backward); the inner sign gives
**polarity** (`+` positive, `-` negative). The operand is any grammar symbol `N`
(nonterminal or terminal). The annotation is written **inline** in a production; its
position is the anchor `p` (the input position the parser has reached there).

| glyph | reads as | holds iff |
|-------|----------|-----------|
| `>+>(N)` | *N must follow*  | some yield of `N` **starts** at `p` |
| `>->(N)` | *N must not follow* | no yield of `N` starts at `p` |
| `<+<(N)` | *N must precede* | some yield of `N` **ends** at `p` |
| `<-<(N)` | *N must not precede* | no yield of `N` ends at `p` |

## Uniform anchoring

All four share **one anchor `p`**. Direction does not move the anchor — it only selects
which end of the target's yield is compared to `p`:

- **forward** tests the target yield's **start** (`i == p`);
- **backward** tests the target yield's **end** (`j == p`).

Positive asks "does such a yield exist?", negative asks "is there none?". That is the whole
semantics: one position, one existence question over the yield set, two coordinates. There
is no separate scanner-time or terminal-definition anchoring — every case is the same
query at the same `p`.

## Operand shape

`N` is a **single grammar symbol** — a terminal (`"else"`, or a named terminal) or a
nonterminal (`expression`, `declaration`). Not an arbitrary inline fragment: the query path
needs a named, yield-bearing node to look up, and every swift-syntax predicate gates on one
nonterminal or one token anyway. For a composite condition, **name it** — declare
`elseBranch = "else" ifStatement .` and write `>->(elseBranch)` — which keeps the operand a
single symbol, gives it a yield node, and makes it reusable.

Evaluation splits by kind: a **terminal** operand is a lexical peek (is that token at `p` —
cheap, and free of derivation circularity); a **nonterminal** operand is the yield query /
seeded sub-parse below.

## Evaluation

The answer to "does `N` derive at `p`?" is already latent in a general parser that
produced all derivations, so evaluation is a **yield-set query**, not a re-scan:

- **Reachable target (default).** When the main grammar already attempts `N` at `p`, its
  yields are in the BSR. The query is an indexed membership test (`i == p` forward,
  `j == p` backward). For *disambiguation* this is always the case by construction: a
  predicate chooses among readings that compete here, and a reading that competes here was
  parsed here, so it yielded here.
- **Unreachable target (on-demand fallback).** When `N` is *not* otherwise attempted at
  `p`, seed an isolated GLL sub-parse from `(N, p)` — the same mechanism that runs
  `=|`/`=:` lexical sub-parses — collect whether `N` yields, memoise `(N, p) → Bool`,
  discard. The sub-parse honours every parse-time gate natively (it *is* a parse), so there
  is no procedural re-derivation of the condition.

**An empty yield set is ambiguous**, so the choice between the two is *not* "query, then
sub-parse if empty." Empty can mean "`N` was attempted and failed" (a real **false**) OR
"`N` was never attempted here" (the query is **blind**). These are indistinguishable from
the yields alone. The selector is therefore a **static property of the predicate site**:
if `N` is provably attempted at the anchor (the disambiguation case — `N` is a
sibling/reachable reading, so the parser necessarily created descriptors for it at `p`),
the query is authoritative and no sub-parse runs; otherwise the sub-parse is seeded
on demand.

**Invariant.** A predicate's target must be *parsed at `p`* — reachable (queried) or seeded
(sub-parsed). Nothing is deduced by re-scanning the input. A predicate whose target the
grammar never attempts at `p`, and which is not seeded, is a specification error, not a
silent false.

## The terminal operand is the degenerate case

`>->("else")` is just `>->(N)` with `N` a single terminal. The old token-set lookahead is
therefore **subsumed**, not separate: same glyphs, same meaning, evaluated by the same
`i == p` / `j == p` query. A terminal operand may use a cheaper fast path (a direct token
test), but only where it is observationally equal to the query. Tokenisation-sensitive
choices (e.g. regex-vs-divide) ride **multi-scan**: the scanner already emits every viable
lexicalisation, the parser explores them, and the uniform backward query prunes the wrong
one post-parse — no bespoke scanner suppression required.

## Containment (the fifth relation)

Context predicates — "this reading is valid only **inside** an `N`" — are the same idea
with a **containment** relation instead of start/end: some yield of `N` spans
`[a,b]` with `a ≤ i` and `j ≤ b` around the guarded span. This is the honest, declarative
replacement for `@within`'s procedural gates (`conditionExpression`/`trailingClosures` are
real, parsed nonterminals, so their containment yields are already in the BSR). It is a
prefix annotation on the whole production rather than an inline point, because containment
is about the derivation's ancestry, not a position.

## Not this mechanism: layout gates

`<n>` / `>n<` test a **trivia** fact (a line break in the gap), not whether a grammar symbol
derives. They remain a separate primitive. A rule that mixes context and layout (e.g.
"a trailing closure, inside a condition, whose `{` opens tight") decomposes cleanly:
containment predicate for the context, `<n>` gate for the layout — each evaluated by its
proper mechanism, neither re-scanned in the Oracle.

## Why this is good

- **Declarative.** The condition is a grammar symbol evaluated by the real parser. No
  hand-written predicate, no input re-scan — the failure mode that made `@within` a
  procedural costume over Swift.
- **Uniform.** One anchor, four glyphs, one query family; forward/backward differ only by
  `i` vs `j`. The old token-only forms are the terminal special case, so there is nothing
  bespoke left to reconcile.
- **Faithful.** It is exactly swift-syntax's predicate-gated choice ("if `N` parses here,
  route to this reading"), which CFG shape plus extent/pivot/same-span annotations cannot
  express. It maps directly onto the `canParse*`/`atStartOf*` catalogue.
- **Cheap.** The BSR is the memo; for disambiguation the answer is already computed. The
  sub-parse fallback reuses machinery that already exists.

## First customer

`open⏎var foo` — `open` is a contextual keyword (a legal identifier) *and* a modifier, so
Advent finds both "one declaration `open var foo`" and "bare `open` reference + `var foo`".
swift-syntax routes to the declaration because `atStartOfDeclaration` fires. Declaratively:

```apus
statement = >->(declaration) expression .   // an expression-statement, only where a declaration does NOT start here
```

`declaration` is reached at every code-block item, so the query is a plain BSR test — no
sub-parse, no newline hack, no procedural gate. It reproduces swift-syntax's
declaration-first commit exactly.
