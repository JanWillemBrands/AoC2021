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

## The tool

```
@within ( ContextNT )   — prefixes an alternate; makes it a HARD post-parse filter, active only
                          where the alternate's span lies inside a ContextNT yield (BSR span
                          containment). The boundary predicate is written with the existing
                          gate operators, but evaluated post-parse by the Oracle, not the matcher.
```

- **Hard** = it may remove the last surviving derivation → the input becomes a *reject*. This is
  the one property that separates it from `@prefer`/`@avoid` (preferences, which are forbidden
  from emptying the forest by the dead-wood invariant). `@within` is a **faithfulness filter**,
  a deliberately different phase.
- **Context by BSR containment** = the GLL substitute for the inherited `flavor`. A
  `trailingClosures` yield `(…,k,j)` is "in a condition" iff some `conditionExpression` yield
  `(ci,·,cj)` satisfies `ci ≤ k ∧ j ≤ cj`. `conditionExpression` already exists — no new
  nonterminals, no clone.

### Boundary predicate operators (inside an `@within` alternate)

- `>+> ( set )` / `>-> ( set )` after a **nonterminal** = the token following that nonterminal's
  completion must / must not be in `set`. (Existing operators; new anchor = nonterminal
  completion — the previously-deferred "`>+>` at nonterminal completion" task. Evaluated
  post-parse from `input` at the nonterminal's `j`.) This is **disc-3**.
- **disc-1** (no newline between the closure's `{` and its first body token) is folded into the
  `@within` predicate as a newline scan on the closure's own span — no operator, no cloned
  closure rule. (This is why the earlier `condClosureBodyTight` idea is dropped: it was a
  one-rule closure clone to carry disc-1; the filter already owns the span and `input`.)

## Swift.apus surface

Guard-`else` first cut — disc-3 only (all four guard cases are `} else`):

```apus
trailingClosures = @within(conditionExpression) closureExpression >-> ( "else" ) labeledTrailingClosures?
                 | closureExpression labeledTrailingClosures? .        // unscoped (.basic) — unchanged
```

Full version — same alternate; `@within` folds in disc-1 (newline scan) and the full disc-3
allow-set; still no closure clone:

```apus
trailingClosures = @within(conditionExpression) closureExpression >+> ( "{" "where" "," "." "(" "[" "?" "!" ":" "=" "is" "as" ) labeledTrailingClosures?
                 | closureExpression labeledTrailingClosures? .
```

Model in one line: the alternate still *parses* (the trailing-closure reading is produced);
`@within` then removes it in condition context iff the boundary predicate fails — literally
swift-syntax's `withLookahead { atValidTrailingClosure() }`, read off the BSR.

## Engine implementation

1. **ApusParser** — recognise `@within ( identifier )` as an alternate prefix (like `@prefer`);
   store the context name + the following boundary gate on the ALT node. (`>->`/`>+>` after a
   nonterminal reference already parse as gates; they must be *retained*, not applied at match
   time, when the alternate is `@within`.)
2. **GrammarNode** — `withinContextName: String?`, resolved `withinContext: GrammarNode?`, and a
   reference to the boundary gate set/polarity. Anchor node = the nonterminal the gate follows
   (here `closureExpression`).
3. **Grammar** — resolve `withinContextName` → node in finalisation (error if unknown).
4. **Oracle** — a new **faithfulness-filter phase**, run after dead-wood pruning and before (or
   folded with) preference disambiguation, ALLOWED to empty a node's yields:
   - for each `@within` rule: let `C` = set of `withinContext` yields; for each candidate yield
     `y` of the anchor nonterminal with `∃ c ∈ C: c.i ≤ y.i ∧ y.j ≤ c.j` (containment):
     evaluate the boundary predicate at `y` (`disc-3`: next token after `y.j`; `disc-1`: newline
     scan inside `y`). If it fails, remove `y` (and let the re-run dead-wood sweep propagate).
   - re-run dead-wood; if the root loses all yields → reject.

The Oracle already holds `input: String` and `CharPosition = String.Index`, so both
discriminators are pure functions of `input` + span (Oracle.swift:122–138 already scans `input`).

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
1. **guard-`else`** (`>->("else")`, disc-3, no disc-1) — clears `testTrailingClosureInGuard#1–4`.
   Validate: 4 guard rejects flip green; full accept sweep stays at 0 failures.
2. **disc-1 newline scan** folded into `@within` — clears `testTrailingClosureInIfCondition#1`.
3. Broaden disc-3 to the full allow-set (with the same-line qualifier on the operator subset).
