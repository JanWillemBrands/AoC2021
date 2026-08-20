# `@within` — a hard, context-scoped post-parse filter

**Status:** design + guard-`else` prototype (B2 discriminator 3). 2026-08-20.
**Companion:** `REJECTS.md` §B2, `ambiguity resolution.md`, `Structured Lookahead Design.md`
(the "Oracle Filter / Post-Parse Predicate" extension candidate this realises).

## Problem it solves

Swift's trailing-closure-in-condition rule (`atValidTrailingClosure(flavor:)`,
`SwiftParser/Expressions.swift:2263`) is an **inherited attribute**: the parser threads
`ExprFlavor.stmtCondition` down the recursive-descent call stack, and at each `{` decides
"trailing closure vs statement body". A GLL parser has **no inherited attributes** — the
grammar is context-free, so "am I inside a condition?" is not available at the
`trailingClosures` rule. The two escapes are:

1. **Structural** — clone the whole `prefixExpression → postfixExpression → functionCallExpression
   → trailingClosures` chain into a condition-flavored copy, making flavor part of nonterminal
   identity. Faithful but ~12 duplicated rules, and it bakes the attribute into grammar text —
   the opposite of Advent's "read the answer off the finished BSR" philosophy.
2. **Post-parse** — parse permissively (both readings produced), then apply a filter that
   reconstructs the context from the BSR and removes the reading swift-syntax wouldn't have
   taken. This is what `@within` does.

A global gate is **not** an option: `foo {⏎ bar⏎}` is a valid single trailing-closure call at
statement level (`.basic` flavor skips the check), and Advent also has a competing two-statement
reading — so any newline/follow gate applied everywhere changes accepted parses. The constraint
is inherently condition-scoped.

## What swift-syntax actually checks (measured)

Attachment points differ by flavor:
- **paren-call** (`f(x){}`) and **subscript** (`a[i]{}`) trailing closures are gated
  `if case .basic = flavor` (Expressions.swift:866, :910) — in `.stmtCondition` they are never
  attached (the `{` is always the body; this is why `if f() { }` just works).
- **bare** trailing closures (`f {}`, `a.b {}`) reach `atValidTrailingClosure` with the real
  flavor (Expressions.swift:937). All B2 failures are bare trailing closures in a condition.

For a bare trailing closure in `.stmtCondition`, `atValidTrailingClosure` returns true iff:
- **disc-1** the token after the closure's `{` is on the **same line** as `{`
  (`!self.peek().isAtStartOfLine`); else it's the body.
- **disc-3** the token after the closure's matching `}` is in the follow true-set:
  `{`, `where`, `,` (any line), or `[ ( . is as ?(post) ?(infix) ! : = postfixOp binaryOp`
  (same line only). `else` and newline-led operators are NOT in the set → refuse.
  (Plus two early outs: not a get/set accessor, not a `case`-led switch body.)

## The tool — a filter production in the same APUS language

```
@within ( Ctx ) [ @within ( Ctx2 ) … ]  LHS = rhs .
```

A production carrying one-or-more `@within(Ctx)` prefixes is a **filter production**: it does NOT
contribute to the parse (its alternates are never registered on the nonterminal — no double-parse).
Post-parse, the Oracle prunes derivations of the *base* `LHS` that lie inside **all** of the
`Ctx…` extents (BSR span-containment) and violate a gate declared in `rhs`.

- **Hard** = it may remove the last surviving derivation → the input becomes a *reject*. This is
  what separates it from `@prefer`/`@avoid` (preferences, forbidden from emptying the forest by
  the dead-wood invariant). A filter production is a **faithfulness filter** (the SDF/Rascal
  *reject*/*follow-restriction* lineage; see CC-2002).
- **Context by BSR containment** = the GLL substitute for the inherited `flavor`. Stacked
  `@within(A) @within(B)` = conjunction (inside A *and* B) — e.g. a closure that is `⊂ trailingClosures`
  *and* `⊂ conditionExpression` is a trailing-closure-in-a-condition, excluding argument closures.
  `conditionExpression`/`trailingClosures` already exist — no new nonterminals, no clone.
- **Declarative** = the constraints are ordinary APUS gates in `rhs`; there is no disc-1/disc-3
  logic in Swift. The gate *is* the predicate.

### Gate shapes read off the filter `rhs`

- **`>-> ( set )` / `>+> ( set )` on a body symbol S** → the source word following S's completion
  must-not / must be in `set` (disc-3). Anchor = the base `LHS`'s own body symbol named S.
- **`<n>` / `>n<` immediately after a `"{"` literal** → no line break between `{` and the first
  body token (disc-1) — the same computation as the `>n<` boundary gate (`lexer.triviaSkipEnd` +
  line-break-in-trivia). Anchor = the base `LHS` node. Self-guards on `input[i] == "{"`.

## Swift.apus surface (implemented)

```apus
// base parse grammar — unchanged
trailingClosures  = closureExpression labeledTrailingClosures? .
closureExpression = "{" closureSignature? statements? "}" .

// post-parse filters (do NOT parse; prune trailing-closure derivations in a condition that
// violate atValidTrailingClosure, .stmtCondition)
//   disc-3: inside a condition, a trailing closure's `}` may not be followed by `else` (guard)
@within(conditionExpression) trailingClosures = closureExpression >-> ( "else" ) labeledTrailingClosures? .
//   disc-1: a trailing closure (⊂ trailingClosures AND ⊂ conditionExpression — excludes argument
//   closures) must open tight: no newline between `{` and its first body token
@within(conditionExpression) @within(trailingClosures) closureExpression = "{" <n> closureSignature? statements? "}" .
```

Model in one line: the base grammar still *parses* (the trailing-closure reading is produced); the
filter then removes it in condition context iff a declared gate fails — literally swift-syntax's
`withLookahead { atValidTrailingClosure() }`, read off the BSR.

## Engine implementation (as built)

1. **ApusParser** (`production()`) — a production may carry leading `@within(NT)` (repeatable);
   collected into a context list. Such a production is routed to `grammar.filters` and its
   alternates are **never** registered on the nonterminal (so it doesn't parse). `>->`/`>+>` and
   `<n>` inside the filter `rhs` parse into the usual node fields/`.B` nodes.
2. **Grammar** — `struct FilterProduction { lhsName; contextNames; rhs }`, collected in `filters`.
3. **Oracle** (`registerFilter`) — resolve the contexts and the base `LHS`; walk the filter `rhs`
   for the two gate shapes above and register a `WithinRule` keyed on the corresponding **base**
   node (the parse produced its yields), so pruning cascades through the existing second dead-wood
   sweep exactly like a `PreferRule` on a body symbol. `WithinRule.prune` keeps a yield only if it
   lies inside every context (conjunction) and passes the gate; a removal that empties the root →
   reject.

The Oracle holds `input: String` (`CharPosition = String.Index`) and the engine's
`lexer.triviaSkipEnd`, so both gates use the same trivia/line-break notion as the boundary gates.

## Why not the alternatives (recap)
- **Clone the chain:** heavy, and hard-codes flavor into grammar text.
- **Parse-time completion-lookahead only:** disc-3 is expressible, but the gate still needs a
  condition-scoped *instance* to sit on → still a clone. Post-parse containment is what removes
  the clone.
- **Preference (`@prefer`/`@avoid`) / plain Oracle prune:** cannot reject — the target reading is
  often the only complete derivation, and the dead-wood invariant protects it. Hence a *hard*
  filter.

## Generality

`@within` + BSR-containment context + hard filter is not Swift-specific. It is the home for other
"valid only when the parsed shape/context is X" rejects (`REJECTS.md`: C5 duplicate access
modifiers, C6 accessor-combination, C12 `@available` string-kind) — each a post-parse predicate
on a node's subtree/neighbourhood. B2 is the first, most-motivated instance.

## Increments
1. ✅ **guard-`else`** (disc-3) — `testTrailingClosureInGuard#1–4` reject.
2. ✅ **disc-1 newline** — `testTrailingClosureInIfCondition#1` rejects. Whole B2 cluster closed.
   Full sweep: reject **79 → 62**, accept **0** failures, no new failures (filter-grammar form is
   behavior-identical to the earlier alternate-prefix cut).
3. (later) broaden disc-3 to the full allow-set (with the same-line qualifier on the operator
   subset) if a test needs it — none currently do.

## Status: implemented via the filter-grammar form (2026-08-20)
`@within` is a production-level, stackable filter prefix; filter productions live in
`grammar.filters` and are compiled to `WithinRule`s by `Oracle.registerFilter`. Reusable for the
shape/context rejects on the frontier (REJECTS.md C5/C6/C12) — those want plain reject productions
(no `@within`) or single-`@within`, in the same filter-grammar.
