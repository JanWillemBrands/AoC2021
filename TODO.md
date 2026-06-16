# Consolidated TODOs

This file is the canonical TODO list across markdown docs in this project.

## Active TODOs

1. Performance: profile `tortureART` and decide optimization priority between speed and memory.
Source: `Advent/claude.md` (previously in "Future Work & TODOs").

2. `@unless` engine — cascade pruning from body symbol yields to `.N` yields. The rule fires correctly on the last body symbol of the annotated alternate (verified: 2 yields disambiguated on `Array<Array<Int>>`), but the `.N` (nonterminal) yield that summarises the alternate's match still survives because nothing in the existing Oracle removes a `.N` yield when one of its alternates' body yields is pruned. As a result, `DerivationBuilder` continues to enumerate derivations through the surviving `.N` yield (Array<Array<Int>> stays at ~10 derivations instead of dropping to 1). The natural fix — a second `pruneUnproductive` call at the end of `Oracle.disambiguate` — breaks all subsequent message parses (descriptors=0 from message 2 onward). Likely cause: `pruneUnproductive` mutates `nt.yield` in place, and `GrammarNode.clearNodes()` doesn't fully reset state between message parses (known TODO comment in `clearNodes()` flags this). Need either (a) fix `clearNodes` to be exhaustive, then re-enable the second `pruneUnproductive`, or (b) add a targeted "remove .N yields whose alternate-body yields were pruned" hook driven from `UnlessPredicateRule`, or (c) augment `BinarySpan` with an alternate ID so `.N` yields can be filtered alternate-by-alternate.
Source: today's @unless implementation work; `Advent/Structured Lookahead Design.md`; `Advent/Oracle.swift`; `Advent/GrammarNode.swift:303` clearNodes TODO.

3. `@unless` engine — `resolveUnlessTargets` placement. The call must sit *after* `populateBitSets`, not between `assignNameIDs` and the FIRST/FOLLOW fixpoint loop. Iterating `grammar.nonTerminals` at that earlier point breaks FIRST/FOLLOW propagation — even a pure no-op iteration causes all parses to fail. Root cause not yet identified; FIRST/FOLLOW must have an undocumented iteration-order dependency that's stable only when the dictionary hash state is left undisturbed between `assignNameIDs` and the fixpoint loop. Investigate why a single read-only dictionary iteration perturbs subsequent FIRST/FOLLOW iteration order in a way that changes the converged result.
Source: today's @unless implementation work; `Advent/ApusParser.swift` finalisation sequence.

4. investigate caching the Swift regex instantiations so that successive use becomes faster.

## Multi-Lex follow-ups (carried forward from `Multi-Lex Adoption Design 2.md`)

5. **LL(1) early-termination re-enable evaluation.** `CallReturnForest.addDecscriptorsForAlternates` carries `let canEarlyTerminate = false && X.isLocallyLL1`. The skeleton + per-node `isLocallyLL1` flag + `verifyLL1` infra are intact; only the `false &&` prefix disables it. Phase F closed without resurrection because the predict-set filter in `tokenMatch` already prunes the worst cases. Evaluate whether enabling early-termination meaningfully reduces descriptors on a tight LL(1)-shape grammar (e.g. APUS self-parse) and decide: delete the dead skeleton or remove the `false &&` and ship. Source: design doc Phase B Step 4, Phase F close.

6. **Post-Phase F annotation review — exclude semantics + measurement.** Two open questions on the per-end LCNP exclusion gate adopted in Phase D Steps 2–3:
   - **Correctness.** "Same end" is a proxy for "same span" — captures classical Schrödinger same-span cases but may not cover every case the head-based gate handled under variable-length regex matches. Multi-match + per-end exclude needs an audit: does "any excluded terminal lexes at *any* end matching this candidate's" still mean what the author wrote `---(…)` to mean?
   - **Effectiveness.** Head-based gate fired once per `testSelect`; LCNP per-end gate iterates `slot.excludeBS` per candidate-terminal per candidate-end. Cache absorbs repeat work but cost profile shifted. Measure with `lexLKH` filter upstream — predict-pruned candidates plus per-end exclude may be cheaper or more expensive depending on grammar shape.
   Source: design doc "Post-Phase F review TODO — exclude semantics and annotations" (~line 840).

7. **Walk every APUS annotation against multi-lex.** Each was designed against the eager scanner's single-committed-token-stream model. For each, answer: still needed and still correct / needed but reformulate / retire?
   - `---(…)` exclude — covered in (6); could it move into terminal regexes via negative lookahead?
   - `<<1/<<2/++1/++2/--1/--2` lookbehind — under LCNP regex is only queried where FIRST reaches `regularExpressionLiteral` (typically expression-start). Instrument a sweep: if zero blocks fire, drop from `Swift.apus`. Consider moving to Oracle as `LookbehindPruneRule` alongside `UnlessPredicateRule`.
   - `>>1(…)` followAhead — Phase F's `lexLKH` (using `cL.followBS`) is the natural replacement. Each `>>1` use needs per-site equivalence proof before deletion.
   - `>s<` / `<s>` / `<n>` / `>n<` boundary annotations — Phase E moved evaluation parser-side using `terminalCommitsByEnd[].rawEnd`. Confirm each existing use survives the substitution; expand to other languages.
   - `@longest` / `@shortest` / `@left` / `@right` Oracle rules — extent comparisons should be confirmed against the CharPosition coordinate model.
   - `@unless(X)` — verify it composes cleanly with per-end LCNP exclude.
   Source: design doc same section as (6).

8. **`---()` full removal — alternative grammar mechanism.** Full retirement of `---()` would require an alternative for the keyword-vs-identifier disambiguation case (e.g. moving the exclusion into terminal regexes via negative lookahead). Deferred until the per-end semantics has proven itself across the full SwiftSyntax 590-case sweep.
   Source: design doc Phase D status (~line 836).

9. **Token.kindID field removal audit.** No parser hot-path consumer remains; `ApusParser` reads `Token.kind` (string) but never `kindID`. Audit any remaining caller (incl. diagnostic / instrumentation code), then delete.
   Source: TODO comment in `Scanner.swift` near `Token`; Phase I close note.

10. **Consolidate `terminalCommitsByStart` + `terminalCommitsByEnd` into one representation.** Likely shape: a single `terminalCommits: [(range: Range<CharPosition>, kindID: Int)]` array plus auxiliary `byStart` / `byEnd` indices built lazily. Cleaner mental model ("commits are source ranges; trivia is the gaps") with same information content. Also exposes "trivia between commits" as a derived property rather than implicit.
   Source: user observation in Phase I; design doc Phase I deferred list.

11. **Parser-level regex CFG via lex-side validator.** Move `plainRegularExpressionLiteral` *back* to a single terminal whose lex implementation runs a CFG acceptor internally (`lex(pos, regexLiteral)`). The grammar stays clean (regex is one terminal again), the `(/E.e).foo(/0)` over-claim is rejected by the lex-side validator, and the operator-overlap workaround (`regexNonOperatorAtom` + `regexAtom = operatorHead | …`) disappears. This is also where the deferred **candidate-validator** primitive lands — LCNP's `lex(pos, t)` is naturally a candidate validator.
   Source: design doc §"Mechanisms that LCNP replaces" item 4 (~line 87).

12. **`GenerateParser.swift` LCNP migration.** The generated standalone parser (currently for LL(1) grammars only) needs to track LCNP changes. Preserve integer terminal IDs and `BitSet` select tests, but emit parser-driven terminal calls rather than assuming a pre-tokenized input stream. Tests for this live in `AdventTests/ParserGeneratorTests.swift`.
   Source: design doc Open Questions §H.

13. **Performance profiling on Swift workloads.** Specific multi-lex measurements needed: descriptor count, BSR yield count, lex-cache hit rate, regex-call distribution per terminal, wall-clock time. Swift regex literals / multi-pound strings / interpolated strings / editor placeholders introduce recognizer calls that may dominate cost. Tie this together with TODO 4 (regex caching).
   Source: design doc Open Questions §C; Phase F close.

14. **Mini-scanner parameterisation for non-Python layout-sensitive grammars.** `computeVirtualLayoutTokens` currently hardcodes Python string/comment delimiters (`"`, `'`, `"""`, `'''`, `#`). When a second layout-sensitive grammar arrives (Haskell offside, F#, YAML), refactor the hardcoded delimiters into parameters; possibly an APUS grammar-level `@layout(strings: ..., lineComment: ...)` annotation.
   Source: Phase I implementation note in `LayoutTokenInjection.swift`.

## Maintenance Rule

- Add new markdown TODOs here and link back to source context when needed.
- `Advent/codex.md` and `Advent/claude.md` should reference this file instead of maintaining separate TODO lists.
