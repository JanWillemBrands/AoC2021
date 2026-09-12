# This file is the canonical TODO list in this project.

Status Sep 11 2026, full suite: **8 issues, all `trees match`, all one family (item 1).**
accepts 0 · residual ambiguity 0 · wrongly-accepted 0 · `.lookupFailed` 0 · crashes 0 ·
`.unhandled` 5.

Headline metric is `grep -c 'recorded an issue'` on the whole suite. Do NOT use
`grep 'Trees differ'` — it only fires when BOTH trees are built and differ, so it silently omits
snippets that produce no tree at all (that mistake hid 33 failures for most of the converter work).

---

## Open work

1. **Types in expression position — the last 8 failures, and they are ONE question.**
   `testInverseTypes#2/#3/#5/#7/#8`, `testCompositionTypeExpr#8`, `testNonisolatedSpecifier#4/#13`.
   In each, a type-only construct sits where an expression is also viable and we pick by SPAN
   rather than by context:

   - `[any P & Q]` → SequenceExpr instead of one `TypeExpr(SomeOrAnyType(CompositionType))`
   - `X<~Copyable>()`, `X<P & ~Copyable>()` → the `<`…`>` read as comparison operators instead of
     `GenericSpecializationExpr`
   - `~Copyable` / nonisolated forms → type spliced into a sequence

   Evidence they are one problem, not three: `@longest` on `primaryExpression = boxedProtocolType`
   fixed the plain `any P & Q` case and did NOT fix the array-element case. That is the signature of
   a span-based remedy applied to a context-based problem. Expect one coherent treatment (a
   commit/lookahead primitive, or `@cannotParse` in the other direction) to close all 8; resist
   patching them individually.

2. **Five remaining `.unhandled` records.** Not all cause tree failures, but each is a real gap:
   `abiVariableDeclaration` and `abiSubscriptDeclaration` (testABIAttribute#19/#7 — the bodyless
   ABI-only decl forms); `genericWhereClause` in `declHeadModifiers` (testForeachAsync2#1);
   `convertType` flattening an unrecognised `type` to `IdentifierType`; and a multiline
   interpolation whose head contains a comment holding `"""` (testMultilineString46#1).

3. **Enum-case placement — needs a NEW primitive; do not retry the obvious fix.**
   `declaration = @confinedTo(memberDeclaration) enumCaseDeclaration` already rejects top-level
   `case`. `case` still parses in struct/class/extension bodies (testEnum12/13/14).

   **`@confinedTo(enumMember)` does NOT work — probed Sep 8 2026 and reverted.** It correctly
   rejects those three, but WRONGLY ACCEPTS `enum E { struct S { case X } }`, because
   `ContainmentRule` is pure interval containment (`$0.i <= span.i && span.j <= $0.j`) and the
   enclosing `enumMember` yield for `struct S { … }` contains the inner `case` span. Net trade was
   3 working parses lost for a rule that still has a hole.

   **Cheap fix that would work: co-initial containment.** `enumMember → memberDeclaration →
   declaration → enumCaseDeclaration` is a chain of CO-INITIAL spans, so "directly a member of an
   enum" is exactly "some `enumMember` yield BEGINS where I begin" — `$0.i == span.i && span.j <=
   $0.j`. One flag on `ContainmentRule` plus apus syntax (`@directlyIn(N)`). Stays
   path-independent, so it drops into `prune(_ yields:)` unchanged, and is reusable for any
   "directly a member/element of X" rule.

   **Full scope-awareness is a DESIGN change, and BSR access is not the obstacle.** Containment
   runs while the forest is still ambiguous, and "correctly scoped" is a property of a DERIVATION,
   not of a span: one span may be reached by several parent chains, valid on one and invalid on
   another. `prune(_ yields: inout Set<BinarySpan>)` can only remove a span for ALL derivations, so
   a path-dependent predicate is ill-typed against the interface — it would need pruning of BSR
   ELEMENTS (span + parent slot), touching every `DisambiguationRule`, the two-phase pipeline and
   the span-keyed `@prefer`/`@longest`. Almost certainly what the retired procedural `@within`
   filter was avoiding.

4. **Model static string-literal BODIES in the grammar.**
   `multilineStringLiteral` / `extendedMultilineStringLiteral` are single `@builder` terminals
   matching delimiters AND body as one token, so the converter recomputes every segment boundary,
   escape rule and indentation strip from raw text. Both string bugs of Sep 6 came from that. The
   INTERPOLATED forms already show the shape to copy (Head/Part/Tail), and that path has never had
   this class of bug. Raw strings with interpolation (`\#(…)` inside `#"…"#`) are also one token
   and cannot be segmented at all — same fix.

   Trade-off: the escape/continuation/indentation rules move into `Swift.apus` where they are
   declarative and testable, but the indentation rule is CONTEXTUAL (depends on the closing
   delimiter's column) — which a CFG expresses badly, and which `REJECTS.md` §C2 Group D already
   lists as unenforced for that reason. Schedule as its own piece with a full A/B, not folded into
   tree work.

5. **DISABLED fixtures (≈199 `disabledReason` occurrences) — audit as one pass.**
   Only the last group is work:

   - **≈126 feature-gated**: `"underscore attribute"` (89), `"experimental feature"` (37). Bulk
     categories applied wholesale; re-check whether the corpus pin still justifies them.
   - **≈35 compiler-invalid**: swift-syntax parses permissively, `swiftc` rejects — empty
     case/default bodies (14), inline `where` in a generic parameter clause (8), deprecated
     `: class`, `case foo()`, bodyless subscripts, bare types as statements, keyword macro names,
     `\()`, misplaced `static`. We follow the COMPILER, so these are correctly disabled.
   - **≈8 deliberate divergence**: regex-body bracket balancing (7 — our
     `plainRegularExpressionLiteral` is a balanced CFG by design; swift-syntax uses a sub-lexer we
     do not replicate) and the leading-combining-char identifier (Unicode TR31).
   - **REAL backlog, 2 items**: `read`/`modify` `@_spi` `Keyword` cases (unconstructible outside
     swift-syntax — `testCoroutineAccessors#1` is disabled for this, and disabling skips all four
     of its tests, so the count understates the gap by one); and the regex-after-`?` case blocked
     by `conditionalOperator`'s `<s>` spacing policy.

   Re-probe the first three groups at the next swift-syntax bump, not one at a time.

6. **Bespoke attribute-argument grammars — the remaining ones only.**
   Done: `@abi`, `@available`, `@isolated`, `@attached`/`@freestanding`, `@convention`, `@objc`,
   `@specialized`, `@differentiable`, `@backDeployed`, `@lifetime`, `@derivative`/`@transpose`.
   Still token soup: CUSTOM attributes with expression arguments (`@Argument(help:)`, `@inline`),
   which reach `attributeArgumentClause`. The grammar's own note says swift dispatches on the
   attribute NAME — known attributes get soup, unknown ones an expression list — so the fix is to
   route NON-builtin names to `attributeArgumentExprClause`.

   **Measured constraint: do NOT reuse `functionCallArgumentList`.** It closes an
   `attribute → expression → type → attribute` cycle and is a performance cliff — the full run went
   from 85s to NOT FINISHING in 10 minutes; reverting restored 85s and the identical label set.
   Write a narrow rule per attribute. Two useful facts found on the way: several attributes have NO
   dedicated swift-syntax node (arguments surface as plain `.argumentList`, so the existing
   `convertArgumentList` suffices), and each narrow rule initially OVER-rejects a form nobody
   enumerated — caught only by the accepts corpus, never by the tree diff. Budget a widening round
   per attribute.

---

## Settled — do not redo

- **LL(1) early termination stays OFF; `isLocallyLL1` is REMOVED.** Enabling it broke 103 valid
  parses (issues 55 → 226) and saved 0.45% of descriptors. Unsound because the multi-lex guard
  never detected two DISTINCT regex sources co-matching, while `testSelect` answers true when ANY
  terminal in an alternate's FIRST matches. Removal verified byte-identical (3,773 parses,
  1,762,627 descriptors, 391,163 CRF). `subtreeIsLL1` and the FIRST/FOLLOW detection `verifyLL1`
  reports are KEPT.

- **What `verifyLL1` reliably means.** Only: no terminal ID appears in two alternates' FIRST sets
  (or in FIRST and FOLLOW when nullable) — a statement about SYMBOLS. It does NOT imply prediction
  determinism under lex-on-demand, because distinct IDs co-match the same characters, `testSelect`
  asks a per-position question, and the lexer returns a SET of differing-length matches. Nothing in
  the parser consumes it; it feeds `LL1DetectionTests`, `main`'s report and the `ambiguous` set.

- **`@cannotParse(N)` is the sound negative predicate; `>->( nonterminal )` was not.** `>->` over a
  nonterminal silently did nothing — measured: substituting a nonterminal for a literal list took
  ambiguity 0 → 89 and wrongly-accepted 0 → 9 while the tree-diff label set stayed BYTE-IDENTICAL.
  (That last part is the warning: an invariant check watching labels alone would have called it
  clean.) `@cannotParse` replaced it and fixed the greedy key-path commit — `\Foo.method<Int>()` is
  now rejected via `@cannotParse(keyPathExpression)` on the generic-member `explicitMemberExpression`
  alternate. An unparenthesized key-path is a POSTFIX ISLAND; `(\Foo).method<Int>()` still parses,
  because at `(` a key-path cannot start (fixtures `probeParenKeyPathPostfix/Member`).

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

- **Right-recursive grammar lists sometimes fold LEFT in swift-syntax.** Sibling nested postfix
  `#if` blocks chain (each takes the previous as base); nested arrow returns SPLICE into one flat
  sequence. Read the reference dump before assuming the tree mirrors the rule.

---

## Maintenance Rule

- Add new markdown TODOs here and link back to source context when needed.
- `Advent/codex.md` and `Advent/claude.md` should reference this file instead of maintaining separate TODO lists.
