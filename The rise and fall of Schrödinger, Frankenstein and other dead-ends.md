# The rise and fall of Schrödinger, Frankenstein and other dead-ends

A short obituary of mechanisms this project invented, shipped, and later retired or
superseded. Kept so we don't re-invent them. (Absorbs the old `Schrodinger Tokens.md`
and `Frankenstein Tokens.md`.)

The recurring lesson: **most of these existed to fake sub-token granularity or to
patch ambiguity from a remote site. The LCNP / multi-lex rewrite (`CharPosition =
String.Index`, an on-demand parser-driven lexer) and the on-the-term Oracle
annotations made them unnecessary.**

---

## Frankenstein tokens — *dead, fully removed*

**What it was.** A partial-token sentinel (`≋`) plus bit-packed `Int32`
token-index + sub-index positions (stride / negative-position schemes, on-the-fly
remainder), so a single lexed `>>` could be split into `>` `>` to close nested
generics (`Array<Array<Int>>`).

**Why it died.** All that machinery existed only to express a position *inside* a
token when positions were token-indices. LCNP made `CharPosition = String.Index`, so a
split just ends at an ordinary character position — the short `>` at `[p,p+1)`, the
next at `[p+1,p+2)`, both plain positions the descriptor/CRF/BSR keys already handle.

**What replaced it.** Default maximal munch (`@lexicalClass`) + munch-exempt
single-char regex terminals (`closeAngle - />/`, `openAngle - /</`). No sub-token
positions, no sentinel. Zero references remain in the source.

## Schrödinger tokens — *the runtime object is gone; the concept lives on differently*

**What it was.** The eager scanner emitted, at one position, a token carrying a
`.dual` pointer to an alternative reading when two terminals matched the **same span**
(e.g. `if` as keyword vs identifier). The GLL parser explored both.

**Why it declined.** The eager single-committed-token-stream scanner was replaced by
the on-demand LCNP lexer, which simply *returns multiple matches* for a position —
there is no dual-linked token object to carry around.

**What remains.** Only the *concept* of same-span overlap, handled two ways:
a load-time diagnostic (`GrammarDiagnostics.detectSchrödingerConflict`, warns about
overlapping terminals) and the `---(…)` **exclusion** annotation that suppresses the
unwanted reading in context. (Strictly-shorter prefixes are a *different* problem,
solved by maximal munch — see `TODO.md` #0.)

## `@unless(X)` — *dead, retired 2026-07-30*

**What it was.** An alternate-level predicate: prune this alternate when nonterminal
`X` could start where the alternate ends (encoding swift's `canParseAsXxx`). Used 3×
for `@unless(genericArgumentClause)` (`Foo` vs `Foo<Int>`).

**Why it died.** (1) Readability — it pointed at a *remote* target, away from the term
it affected. (2) Its job split cleanly between the two on-the-term annotations:
extent preference is `@longest`'s job, same-span preference is `@prefer`'s. The generic
cases migrated to `@longest genericIdentifier`/`moduleGenericIdentifier`, leaving
`@unless` used by no grammar. Retired; engine scaffolding deleted.

**What replaced it.** `@longest` / `@shortest` (extent), `@prefer` (same-span),
`@avoid` (optional-skip) — all placed **directly on the affected term**.

## Scanner-mode annotations `>>>` / `<<<` / `===` — *two rises, two falls*

Scanner modes are a stack of lexer states (à la ANTLR modes / Flex start conditions):
a terminal can be gated to fire only in a given mode, and can push/pop the stack after
it matches. The point was context-sensitive lexing — most famously **nested multiline
comments** (`/* … /* … */ … */`), where a flat regex can't count depth.

**Rise 1 — bare `>>>` / `<<<` (ungated push/pop).** The first form was just
`>>> "mode"` (push) and `<<<` (pop) hung on a terminal, with mode membership implied.
**Fall 1.** This **conflated the pre-filter with the post-action**: whether a terminal
was *eligible* in the current mode and what it *did* to the stack were tangled
together, so when `multilineCommentText`'s regex won longest-match but its state check
failed there was no fallback → **19 test regressions**, needing try/rollback.

**Rise 2 — gated transitions `===` (the current form).** The fix (2026-04-28) made the
annotation a structured triple `(gate, pop, push)` and cleanly **separated pre-filter
from post-action** — see `apus.md` and `Scanner Mode Design.md`:

| Syntax | Meaning |
|--------|---------|
| `=== "X"` | eligible only in mode X (pre-filter — regex never even runs otherwise) |
| `=== "X" >>> "Y"` | eligible in X, **push** Y after match |
| `=== "X" <<<` | eligible in X, **pop** after match |
| `=== "X" <<< >>> "Y"` | eligible in X, **replace** X with Y |

The gate is checked *before* matching, so the post-action's pop/push is unconditional
(the stack was already verified) — no rollback. `>>>`/`<<<` survive, but only ever as
the post-action half of a `===`-gated triple; the **bare, ungated** forms are gone.
This mechanism is alive and correct, and is how f-string-style mode switching would be
expressed.

**Fall 2 — Swift stopped using scanner modes at all.** For the flagship case (nested
multiline comments), even the gated-transition version — *three* mode terminals +
*six* `===` annotations — was **retired (Jun 13 2026)** in favour of a single recursive
trivia non-terminal that lets the ordinary GLL machinery count the nesting:

```apus
multilineComment =: "/*" { /(?s)(?:[^*\/]|\*(?!\/)|\/(?!\*))+/ | multilineComment } "*/" .
```

Recognised as trivia during `OnDemandLiteralLexer.skipTrivia`. So `Swift.apus` no longer
carries a single scanner-mode annotation. **Lesson:** if the only reason you reach for
a lexer mode is *recursive nesting*, a recursive grammar rule is simpler and needs no
lexer state at all. Modes still earn their keep for genuinely *non-recursive* state
switches (string ↔ interpolation-expression ↔ format-spec), which is why the mechanism
stays.

---

## Shorter obituaries

| Idea | What it was | Why it died / replacement |
|------|-------------|---------------------------|
| **Distance-2 lookahead** `>>2` `++2` `--2` | two-token lookahead/behind | nothing used it; scheme is distance-1 only |
| **Old spellings** `>>1`, `++1`/`--1` | pre-unification lookahead/behind | → `>+> >-> <+< <-<` (see `Structured Lookahead Design.md`) |
| **Start-keyed `@prefer`** | prune any loser sharing start `i` (extent-blind) | broke `a?.b`, multi-arg subscripts → narrowed to strictly same-span; prefer-longer → `@longest` |
| **`@greedy(class)` / `<suffix>`** | opt-in maximal munch | dropped for always-on default munch via `@lexicalClass` |
| **Probe-alphabet / `regexExtenders`** | space-boundary munch heuristic | replaced by running the faithful `@lexicalClass` regex directly |
| **Explicit Unicode-range regex classes** | faithful ident/operator code-point ranges in a Swift `Regex` | Swift `Regex` rejects canonically-decomposable range bounds → `\p{…}` approximation now; interval-table primitive is the endgame (`TODO.md` #8) |
| **`distributedPackedBySlot` dedup** | per-slot descriptor dedup mode | benchmarked identical to the global set → removed |
| **Eager single-token-stream scanner** | commit one token stream up front | → LCNP on-demand, parser-driven multi-lex |

---

*See `Structured Lookahead Design.md` for the surviving lookahead scheme, `Oracle.md`
for the surviving disambiguation annotations, and `TODO.md` #0 for maximal munch.*
