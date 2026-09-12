# This file is the canonical TODO list in this project.

Headline metric is `grep -c 'recorded an issue'` on the whole suite. Do NOT use`grep 'Trees differ'` — it only fires when BOTH trees are built and differ, so it silently omits snippets that produce no tree at all (that mistake hid 33 failures for most of the converter work).

---

## Open work

0. **preserving trivia** needs a round-trip test

1. **wider tests on Swift 6.4** download swift-syntax 6.4, also test all swift-syntax sources files for equivalence.

   BLOCKED on the release, checked Sep 12 2026: **no stable 604.x.y tag exists.** Latest stable is
   603.0.2, which is what we are already resolved to. 604 exists only as prereleases (newest
   `604.0.0-prerelease-2026-06-05`) plus `release/6.4.x` / `release/6.4.0-2` branches. Our
   `upToNextMajorVersion(603.0.1)` requirement will never resolve those — SwiftPM excludes
   prereleases from ranges, so adopting one needs an exact-version or branch pin. Waiting for the
   final tag: the parked groups all turn on what swift-syntax DECIDES to model, and a prerelease
   answer to that can still flip. Re-check with
   `git ls-remote --tags --refs https://github.com/swiftlang/swift-syntax.git | grep 604`.

---

## Method notes

- **Measure parser WORK, not wall clock.** Every parse prints `descriptors:` / `crf size:` /
  `duplicateDescriptors:`. Summing across the suite is deterministic, immune to machine load and to
  laptop sleep, and resolves sub-1% changes wall clock cannot see:
  `grep -o 'descriptors: [0-9]*' run.log | awk -F': ' '{s+=$2} END {print s}'`

- **A timeout is almost always the laptop SLEEPING.** `caffeinate -i` the run. To confirm after the
  fact, compare `IDETestOperationsObserverDebug: N elapsed` (wall) against
  `Test run with … after N seconds` (suspending clock); one large gap between unrelated trivial
  tests is sleep, whereas a real hang lands inside one expensive test. See TESTING.md.

- **A silent `return nil`, or a `find` that quietly misses, is the most expensive bug shape.**
  `find` does NOT descend through nonterminals (`labelName` inside `statementLabel`), and `-`
  TERMINALS need `findTerminal` (`propertyWrapperProjection`, `forceMark`, `dotOperator`). Each
  LOOKED like "not implemented" and was "looked in the wrong place". Add a diagnostic before
  theorising — doing that to `convertInterpolatedStringLiteral` gave the cause in one run.

- **Token kind is POSITION-dependent.** A backtick-escaped name is not an operator (one omission
  bit three separate name maps); `Self` is `keyword(Self)` only as a LEADING `IdentifierType`; a
  type that COULD be an expression is spelled as one (`Void` is a `DeclReferenceExpr`). Probe each
  new name position.

- **What makes attribute arguments expensive is AMBIGUITY, not the rule reuse.** The grammar
  already reuses `functionCallArgumentList` for attribute arguments —
  `attributeArgumentExprClause` (Swift.apus:3148), reached by both general `attribute` rules — and
  that costs nothing: 73s, ambiguity 0. So the `attribute → expression → type → attribute` cycle
  is live today and is NOT the cliff, contrary to what this note used to say.
  What is expensive is reusing it WITHOUT the `>->` guard that excludes the attributes holding a
  narrow rule (`available`, `objc`, `attached`, …): every builtin then has a second,
  expression-shaped reading and nothing prunes it. Measured on `AttributeSyntaxTests`, guard
  removed: descriptors 26,268 → 44,930 (+71%), 2.2s → 8.6s, and 25 residual-ambiguity failures;
  exactly restored on revert. The recorded full-run cliff (85s → not finishing in 10 min) was this
  compounding on bigger inputs. Adding a narrow rule therefore means adding its name to BOTH
  `>->` lists — that is the real cost of a new bespoke attribute.

- **Right-recursive grammar lists sometimes fold LEFT in swift-syntax.** Sibling nested postfix
  `#if` blocks chain (each takes the previous as base); nested arrow returns SPLICE into one flat
  sequence. Read the reference dump before assuming the tree mirrors the rule.

---

## Maintenance Rule

- Add new markdown TODOs here and link back to source context when needed.
- `Advent/codex.md` and `Advent/claude.md` should reference this file instead of maintaining separate TODO lists.
