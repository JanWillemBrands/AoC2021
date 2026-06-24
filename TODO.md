# Consolidated TODOs

This file is the canonical TODO list across markdown docs in this project.

## Active TODOs

0. **[HIGHEST PRIORITY] LCNP literal lex has no word-boundary guard — keyword `as` over-matches inside identifiers and longer keywords (`associatedtype`, `await`, etc.).** `Descriptor.swift:135-141` `lex(at:terminalID:)` literal arm does pure `hasPrefix` and returns; the comment at `MessageParser.swift:850-851` claims to rely on a guard ("Relies on the lexer's keyword-boundary guard so e.g. literal 'let' doesn't over-match 'letx'") that does not exist. Every `as/in/is/let/var/await/do/if/for/class/...` occurrence inside a longer word currently produces a spurious literal commit (visible in the diagnostic trace for `@abi(associatedtype AssocTy)`: `id=68 '"as"'` followed by `id=6 'rawIdentifier' image='sociatedtype'`), wasting descriptors on every line containing such a prefix and producing misleading parse-failure diagnostics. Per the multi-lex paper (§4.1 lines 2598-2607), the principled fix is **grammar-author-declared suffix property** on the identifier-like terminal (e.g. a `<suffix>` annotation on `rawIdentifier`), from which the lexer derives an "extension char-class" and suppresses any literal whose end-of-match falls inside that class. Language-neutral (PL/1 / Fortran grammars opt out by not declaring the annotation), grammar-derivable (no per-keyword bookkeeping), parametric (works for any identifier-shaped token). Avoid hardcoding "keywords cannot be followed by identifier chars" — that's a Java/Swift policy, not a parser-generator policy.
   Source: Jun 19 2026 investigation; `Descriptor.swift:123-151`; `MessageParser.swift:833-902`; `Multiple Lexicalisation - A Java Based Study.txt` §4.1.

1. Performance: profile `tortureART` and decide optimization priority between speed and memory. Current Xcode Time Profiler result after removing hot-loop trace formatting: parser time is dominated by bookkeeping rather than lexing. Main signals: `MessageParser.call()` is the largest inclusive cost; `addDescriptor`, `addYield`, `continuationViable`, and `cachedLex` spend most time in `Set`/`Dictionary` hashing and mutation. `OnDemandLiteralLexer.lex` itself is small, so scanner regex work is not the bottleneck for this grammar. Candidate experiments: custom `Hashable`/`Equatable` for node-bearing keys using `GrammarNode.number` instead of hashing/comparing `GrammarNode`; evaluate whether `String.Index`-based keys should eventually move to compact integer positions; investigate replacing `[Set<BinarySpan>]` nested value mutation with parser-owned reference buckets to reduce `Array.subscript.modify` / COW overhead. Before final conclusions, confirm the Profile scheme uses Release configuration because `swift_beginAccess` / exclusivity overhead is still visible.
Source: `Advent/claude.md` (previously in "Future Work & TODOs"); Xcode Time Profiler session on `apus grammars/tortureART` 100-b message.

2. `@unless` engine — cascade pruning from body symbol yields to `.N` yields. The rule fires correctly on the last body symbol of the annotated alternate (verified: 2 yields disambiguated on `Array<Array<Int>>`), but the `.N` (nonterminal) yield that summarises the alternate's match still survives because nothing in the existing Oracle removes a `.N` yield when one of its alternates' body yields is pruned. As a result, `DerivationBuilder` continues to enumerate derivations through the surviving `.N` yield (Array<Array<Int>> stays at ~10 derivations instead of dropping to 1). The natural fix — a second `pruneUnproductive` call at the end of `Oracle.disambiguate` — breaks all subsequent message parses (descriptors=0 from message 2 onward). Likely cause: `pruneUnproductive` mutates `nt.yield` in place, and `GrammarNode.clearNodes()` doesn't fully reset state between message parses (known TODO comment in `clearNodes()` flags this). Need either (a) fix `clearNodes` to be exhaustive, then re-enable the second `pruneUnproductive`, or (b) add a targeted "remove .N yields whose alternate-body yields were pruned" hook driven from `UnlessPredicateRule`, or (c) augment `BinarySpan` with an alternate ID so `.N` yields can be filtered alternate-by-alternate.
Source: today's @unless implementation work; `Advent/Structured Lookahead Design.md`; `Advent/Oracle.swift`; `Advent/GrammarNode.swift:303` clearNodes TODO.

3. `@unless` engine — `resolveUnlessTargets` placement. The call must sit *after* `populateBitSets`, not between `assignNameIDs` and the FIRST/FOLLOW fixpoint loop. Iterating `grammar.nonTerminals` at that earlier point breaks FIRST/FOLLOW propagation — even a pure no-op iteration causes all parses to fail. Root cause not yet identified; FIRST/FOLLOW must have an undocumented iteration-order dependency that's stable only when the dictionary hash state is left undisturbed between `assignNameIDs` and the fixpoint loop. Investigate why a single read-only dictionary iteration perturbs subsequent FIRST/FOLLOW iteration order in a way that changes the converged result.
Source: today's @unless implementation work; `Advent/ApusParser.swift` finalisation sequence.

4. Diagnostics: improve failed-parse root-cause reporting for branch-local mismatches that occur before the longest committed prefix. Current Swift macro example (`macro m( )` with mandatory `genericWhereClause`) reports the earlier `parameterClause` non-empty branch mismatch (`found '(' / expected '('`) instead of the later missing `"where"`. Acceptance tests do not catch this because the input is correctly rejected either way; add a focused diagnostic test that asserts the reported farthest/root expected token after nullable continuations and optional skips. Prefer a simple model based on longest committed cursor / viable continuation over scattering mismatch records through CRF replay internals.
Source: Jun 19 2026 diagnostic investigation around `Swift.apus` macro declarations; `MessageParser` failure reporting and nullable `OPT/KLN` skip handling.

5. investigate caching the Swift regex instantiations so that successive use becomes faster.

## Multi-Lex follow-ups (carried forward from `Multi-Lex Adoption Design 2.md`)

6. **LL(1) early-termination re-enable evaluation.** `CallReturnForest.addDecscriptorsForAlternates` carries `let canEarlyTerminate = false && X.isLocallyLL1`. The skeleton + per-node `isLocallyLL1` flag + `verifyLL1` infra are intact; only the `false &&` prefix disables it. Phase F closed without resurrection because the predict-set filter in `tokenMatch` already prunes the worst cases. Evaluate whether enabling early-termination meaningfully reduces descriptors on a tight LL(1)-shape grammar (e.g. APUS self-parse) and decide: delete the dead skeleton or remove the `false &&` and ship. Source: design doc Phase B Step 4, Phase F close.

7. **Post-Phase F annotation review — exclude semantics + measurement.** Two open questions on the per-end LCNP exclusion gate adopted in Phase D Steps 2–3:
   - **Correctness.** "Same end" is a proxy for "same span" — captures classical Schrödinger same-span cases but may not cover every case the head-based gate handled under variable-length regex matches. Multi-match + per-end exclude needs an audit: does "any excluded terminal lexes at *any* end matching this candidate's" still mean what the author wrote `---(…)` to mean?
   - **Effectiveness.** Head-based gate fired once per `testSelect`; LCNP per-end gate iterates `slot.excludeBS` per candidate-terminal per candidate-end. Cache absorbs repeat work but cost profile shifted. Measure with `lexLKH` filter upstream — predict-pruned candidates plus per-end exclude may be cheaper or more expensive depending on grammar shape.
   Source: design doc "Post-Phase F review TODO — exclude semantics and annotations" (~line 840).

8. **Walk every APUS annotation against multi-lex.** Each was designed against the eager scanner's single-committed-token-stream model. For each, answer: still needed and still correct / needed but reformulate / retire?
   - `---(…)` exclude — covered in (6); could it move into terminal regexes via negative lookahead?
   - `<<1/<<2/++1/++2/--1/--2` lookbehind — under LCNP regex is only queried where FIRST reaches `regularExpressionLiteral` (typically expression-start). Instrument a sweep: if zero blocks fire, drop from `Swift.apus`. Consider moving to Oracle as `LookbehindPruneRule` alongside `UnlessPredicateRule`.
   - `>>1(…)` followAhead — Phase F's `lexLKH` (using `cL.followBS`) is the natural replacement. Each `>>1` use needs per-site equivalence proof before deletion.
   - `>s<` / `<s>` / `<n>` / `>n<` boundary annotations — Phase E moved evaluation parser-side using `terminalCommitsByEnd[].rawEnd`. Confirm each existing use survives the substitution; expand to other languages.
   - `@longest` / `@shortest` / `@left` / `@right` Oracle rules — extent comparisons should be confirmed against the CharPosition coordinate model.
   - `@unless(X)` — verify it composes cleanly with per-end LCNP exclude.
   Source: design doc same section as (6).

9. **`---()` full removal — alternative grammar mechanism.** Full retirement of `---()` would require an alternative for the keyword-vs-identifier disambiguation case (e.g. moving the exclusion into terminal regexes via negative lookahead). Deferred until the per-end semantics has proven itself across the full SwiftSyntax 590-case sweep.
   Source: design doc Phase D status (~line 836).

10. **Token.kindID field removal audit.** No parser hot-path consumer remains; `ApusParser` reads `Token.kind` (string) but never `kindID`. Audit any remaining caller (incl. diagnostic / instrumentation code), then delete.
   Source: TODO comment in `Scanner.swift` near `Token`; Phase I close note.

11. **Consolidate `terminalCommitsByStart` + `terminalCommitsByEnd` into one representation.** Likely shape: a single `terminalCommits: [(range: Range<CharPosition>, kindID: Int)]` array plus auxiliary `byStart` / `byEnd` indices built lazily. Cleaner mental model ("commits are source ranges; trivia is the gaps") with same information content. Also exposes "trivia between commits" as a derived property rather than implicit.
   Source: user observation in Phase I; design doc Phase I deferred list.

12. **Parser-level regex CFG via lex-side validator.** Move `plainRegularExpressionLiteral` *back* to a single terminal whose lex implementation runs a CFG acceptor internally (`lex(pos, regexLiteral)`). The grammar stays clean (regex is one terminal again), the `(/E.e).foo(/0)` over-claim is rejected by the lex-side validator, and the operator-overlap workaround (`regexNonOperatorAtom` + `regexAtom = operatorHead | …`) disappears. This is also where the deferred **candidate-validator** primitive lands — LCNP's `lex(pos, t)` is naturally a candidate validator.
   Source: design doc §"Mechanisms that LCNP replaces" item 4 (~line 87).

13. **`GenerateParser.swift` LCNP migration.** The generated standalone parser (currently for LL(1) grammars only) needs to track LCNP changes. Preserve integer terminal IDs and `BitSet` select tests, but emit parser-driven terminal calls rather than assuming a pre-tokenized input stream. Tests for this live in `AdventTests/ParserGeneratorTests.swift`.
   Source: design doc Open Questions §H.

14. **Performance profiling on Swift workloads.** Specific multi-lex measurements needed: descriptor count, BSR yield count, lex-cache hit rate, regex-call distribution per terminal, wall-clock time. Swift regex literals / multi-pound strings / interpolated strings / editor placeholders introduce recognizer calls that may dominate cost. Tie this together with TODO 4 (regex caching).
   Source: design doc Open Questions §C; Phase F close.

15. **Mini-scanner parameterisation for non-Python layout-sensitive grammars.** `computeVirtualLayoutTokens` currently hardcodes Python string/comment delimiters (`"`, `'`, `"""`, `'''`, `#`). When a second layout-sensitive grammar arrives (Haskell offside, F#, YAML), refactor the hardcoded delimiters into parameters; possibly an APUS grammar-level `@layout(strings: ..., lineComment: ...)` annotation.
   Source: Phase I implementation note in `LayoutTokenInjection.swift`.

17. **`balancedToken` ambiguity — Oracle preference order pending.** `balancedToken = identifier | keywordMinusBrackets | literal | operator | attribute .` (Swift.apus:1107). Overlapping alternates: `typealias` matches both `keywordMinusBrackets` and (via `@xxx`) the start of `attribute`; `=` matches `keywordMinusBrackets` and the start of `operator`; `true`/`false`/`nil` match both `keywordMinusBrackets` and `literal`. Every ambiguous token inside an `attributeArgumentClause` produces parallel BSR branches. When parse-tree ambiguity evaluation comes online, annotate `balancedToken` with explicit Oracle preference (likely `keywordMinusBrackets` > `identifier` > `operator` > `attribute` > `literal`, but the spec doesn't mandate an order — confirm with downstream AST consumers). Diagnostic signal: 101 failed parses on the original `@abi(typealias Typealias = @escaping () -> Void)` test was the *failure-path* cost; the *success-path* will show parallel surviving derivations until the Oracle prunes them.
   Source: Jun 19 2026 grammar fix for `@escaping` rejected inside `@abi(...)` (added `attribute` as `balancedToken` alternate).

18. **Review `OPT/KLN` skip viability semantics.** `MessageParser` now uses `continuationViable(continuation:at:)` instead of `testSelect(slot:bracket:)` when offering the nullable skip path for `.OPT` / `.KLN`. This is conceptually consistent with CRF return replay and handles structural continuations like `END`, but the comparison run did not prove an acceptance bug in the old predicate. Open questions: does the broader conservative predicate add descriptors, change ambiguity shape, or mask useful branch-pruning? Add a focused metric/regression sweep before treating this as settled.
   Source: Jun 19 2026 investigation of `macroSignature = parameterClause macroFunctionSignatureResult? .` and failed Swift macro diagnostics.


## Design Note: Swift.apus grammar acceptance policy

Swift.apus matches the **Swift compiler's** semantics, not swift-syntax's permissive parser. swift-syntax intentionally accepts syntactically-shaped-but-semantically-invalid constructs for three reasons:

1. **Better diagnostics.** Parsing `init() -> Int` successfully lets the semantic phase emit *"initializers cannot have an explicit return type"* instead of an opaque *"unexpected token `->`"* parse error.
2. **IDE tooling.** SourceKit / swift-format / refactoring / autocomplete need a syntax tree for partially-invalid mid-edit code; rejection would block those features.
3. **Future evolution.** Encoding shape in the parser and restrictions in semantic checking makes language proposals cheaper to land.

We don't build IDE tooling, so we choose the stricter posture. Concrete decisions taken so far:

- `conformanceRequirement`/`sameTypeRequirement` LHS = `typeIdentifier` (not `type`). swift-syntax accepts `(T) -> () : EqualComparable`; compiler rejects. Test `testWhereClauseWithFunctionType#1` is `disabledReason: "compiler error"`.
- `genericParameter` constraint RHS = `"~"? typeIdentifier | "~"? protocolCompositionType` (not `type`). Rejects `<T: (Int) -> Bool>` etc.
- `typeInheritanceList` modifier = `nonisolatedSpecifier?` (not the full `parameterModifiers?` list). Rejects `extension X: inout Foo {}` etc.
- `initializerDeclaration` rejects return clause. swift-syntax accepts via `parseFunctionSignature`; compiler rejects. Test `testInitializerWithReturnType#2` is `disabledReason: "compiler error"`.

When a future test surfaces a similar swift-syntax-only construct, the protocol is: prefer the compiler's restriction and disable the test with `disabledReason: "compiler error — <swift-syntax-source-of-truth ref>"`.

Source: Jun 21 2026 review of widened grammar acceptance; user preference for compiler-correct grammar over swift-syntax permissive parsing.

## Maintenance Rule

- Add new markdown TODOs here and link back to source context when needed.
- `Advent/codex.md` and `Advent/claude.md` should reference this file instead of maintaining separate TODO lists.
