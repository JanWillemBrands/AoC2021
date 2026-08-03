# Schrodinger Tokens (Caveman Notes)

> **Superseded (2026-07-30).** The runtime dual-linked Schrödinger *token* is gone —
> LCNP/multi-lex returns multiple matches per position instead. The concept now lives
> only as the `detectSchrödingerConflict` load-time diagnostic + the `---(…)` exclusion.
> See *The rise and fall of Schrödinger, Frankenstein and other dead-ends.md*. Below is
> the original design, kept for history.

## Problem

Scanner does longest match.
Sometimes tie.

Same text, same length, different token kinds.

Example:

- `if` can be keyword
- `if` can be identifier-ish token

If scanner keeps only one, parser loses real paths.

## Core Rule

Keep all equal-length winners.

One token head, then dual chain:

- head
- `dual`
- `dual`

So parser sees all lexical possibilities at same position.

## In Code

`Token` has:

- `kind`
- `dual`

Parser functions walk duals:

- `tokenMatch()`
- `testSelect()`
- `followCheck()`

## `---` Annotation

`---(...)` says: in this grammar context, suppress specific head-token dual paths.

Goal:

- keep completeness globally
- prune obvious bad branch locally

This becomes `exclude` on grammar nodes.

## Why Not Oracle

If dual options removed before parser:

- missing BSR
- missing CRF
- oracle cannot revive dead paths

Oracle can only rank/filter what parser already built.

## Relation To Frankenstein

- Schrodinger: same span, many kinds
- Frankenstein: one token split into sub-positions

Different problem.
Both parser-level mechanisms.

## Bottom Line

- Keep duals in scanner output.
- Walk duals in parser.
- Use `---` to cut bad local branches.
- Do not move this mechanism to oracle.

See also: `Trivia Oracle.md` section "Exhaustive Swift Trivia Inventory (For This Project)".

## Implemented Learnings (April 2026)

- **Not every keyword/identifier issue is a Schrödinger-token problem.**  
  Example: `.public` failing in Swift grammar was mainly a use-site grammar context issue.
- **Use-site and declaration-site identifier rules must stay separate.**  
  Declaration names (for example `enumCaseName`) stay strict (`identifier`), while member/use sites can allow `softIdentifier`.
- **`implicitMemberExpression` should accept soft identifiers.**  
  This enables context-sensitive member references such as `.public` without weakening declaration grammar globally.
