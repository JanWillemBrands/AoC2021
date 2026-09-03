# Consolidated TODOs

This file is the canonical TODO list in this project.

1. **Performance**: profile `tortureART` and decide optimization priority between speed and memory. Current Xcode Time Profiler result after removing hot-loop trace formatting: parser time is dominated by bookkeeping rather than lexing. Main signals: `MessageParser.call()` is the largest inclusive cost; `addDescriptor`, `addYield`, `continuationViable`, and `cachedLex` spend most time in `Set`/`Dictionary` hashing and mutation. `OnDemandLiteralLexer.lex` itself is small, so scanner regex work is not the bottleneck for this grammar. Candidate experiments: custom `Hashable`/`Equatable` for node-bearing keys using `GrammarNode.number` instead of hashing/comparing `GrammarNode`; evaluate whether `String.Index`-based keys should eventually move to compact integer positions; investigate replacing `[Set<BinarySpan>]` nested value mutation with parser-owned reference buckets to reduce `Array.subscript.modify` / COW overhead. Before final conclusions, confirm the Profile scheme uses Release configuration because `swift_beginAccess` / exclusivity overhead is still visible.
Source: `Advent/claude.md` (previously in "Future Work & TODOs"); Xcode Time Profiler session on `apus grammars/tortureART` 100-b message.

4. **Diagnostics**: improve failed-parse root-cause reporting for branch-local mismatches that occur before the longest committed prefix. Current Swift macro example (`macro m( )` with mandatory `genericWhereClause`) reports the earlier `parameterClause` non-empty branch mismatch (`found '(' / expected '('`) instead of the later missing `"where"`. Acceptance tests do not catch this because the input is correctly rejected either way; add a focused diagnostic test that asserts the reported farthest/root expected token after nullable continuations and optional skips. Prefer a simple model based on longest committed cursor / viable continuation over scattering mismatch records through CRF replay internals.
Source: Jun 19 2026 diagnostic investigation around `Swift.apus` macro declarations; `MessageParser` failure reporting and nullable `OPT/KLN` skip handling.

6. **LL(1) early-termination re-enable evaluation.** `CallReturnForest.addDecscriptorsForAlternates` carries `let canEarlyTerminate = false && X.isLocallyLL1`. The skeleton + per-node `isLocallyLL1` flag + `verifyLL1` infra are intact; only the `false &&` prefix disables it. Phase F closed without resurrection because the predict-set filter in `tokenMatch` already prunes the worst cases. Evaluate whether enabling early-termination meaningfully reduces descriptors on a tight LL(1)-shape grammar (e.g. APUS self-parse) and decide: delete the dead skeleton or remove the `false &&` and ship. Source: design doc Phase B Step 4, Phase F close.

7. **Post-Phase F annotation review — exclude semantics + measurement.** Two open questions on the per-end LCNP exclusion gate adopted in Phase D Steps 2–3:
   - **Correctness.** "Same end" is a proxy for "same span" — captures classical Schrödinger same-span cases but may not cover every case the head-based gate handled under variable-length regex matches. Multi-match + per-end exclude needs an audit: does "any excluded terminal lexes at *any* end matching this candidate's" still mean what the author wrote `---(…)` to mean?
   - **Effectiveness.** Head-based gate fired once per `testSelect`; LCNP per-end gate iterates `slot.excludeBS` per candidate-terminal per candidate-end. Cache absorbs repeat work but cost profile shifted. Measure with `lexLKH` filter upstream — predict-pruned candidates plus per-end exclude may be cheaper or more expensive depending on grammar shape.
   Source: design doc "Post-Phase F review TODO — exclude semantics and annotations" (~line 840).

8. **Walk every APUS annotation against multi-lex and GrammarNode type.** Each was designed against the eager scanner's single-committed-token-stream model. For each, answer: still needed and still correct / needed but reformulate / retire?  Update apus.apus to correctly represent all.  Double-check complementarity of @prefer / @avoid both allowed at each position?  Both only working or equal length spans?  Why only equal spans?.
   Source: design doc same section as (6).

10. **Token.kindID field removal audit.** No parser hot-path consumer remains; `ApusParser` reads `Token.kind` (string) but never `kindID`. Audit any remaining caller (incl. diagnostic / instrumentation code), then delete.
   Source: TODO comment in `Scanner.swift` near `Token`; Phase I close note.

11. **Consolidate `terminalCommitsByStart` + `terminalCommitsByEnd` into one representation.** Likely shape: a single `terminalCommits: [(range: Range<CharPosition>, kindID: Int)]` array plus auxiliary `byStart` / `byEnd` indices built lazily. Cleaner mental model ("commits are source ranges; trivia is the gaps") with same information content. Also exposes "trivia between commits" as a derived property rather than implicit. Done, but why do we have both:
```swift
struct TerminalCommit {
```
    let terminalID: Int
    let triviaStart: CharPosition
    let start: CharPosition
    let end: CharPosition
    let triviaEnd: CharPosition
}
and
```swift
struct LexMatch: Hashable {
```
    let terminalID: Int
    let start: CharPosition
    let end: CharPosition
    let triviaEnd: CharPosition
}
   Source: user observation in Phase I; design doc Phase I deferred list.

13. **`GenerateParser.swift` LCNP migration.** The generated standalone parser (currently for LL(1) grammars only) needs to track LCNP changes. Preserve integer terminal IDs and `BitSet` select tests, but emit parser-driven terminal calls rather than assuming a pre-tokenized input stream. Tests for this live in `AdventTests/ParserGeneratorTests.swift`.
   Source: design doc Open Questions §H.

14. **Performance profiling on Swift workloads.** Specific multi-lex measurements needed: descriptor count, BSR yield count, lex-cache hit rate, regex-call distribution per terminal, wall-clock time. Swift regex literals / multi-pound strings / interpolated strings / editor placeholders introduce recognizer calls that may dominate cost. Tie this together with TODO 4 (regex caching).
   Source: design doc Open Questions §C; Phase F close.

15. **Mini-scanner parameterisation for non-Python layout-sensitive grammars.** `computeVirtualLayoutTokens` currently hardcodes Python string/comment delimiters (`"`, `'`, `"""`, `'''`, `#`). When a second layout-sensitive grammar arrives (Haskell offside, F#, YAML), refactor the hardcoded delimiters into parameters; possibly an APUS grammar-level `@layout(strings: ..., lineComment: ...)` annotation.
   Source: Phase I implementation note in `LayoutTokenInjection.swift`.

18. **Review `OPT/KLN` skip viability semantics.** `MessageParser` now uses `continuationViable(continuation:at:)` instead of `testSelect(slot:bracket:)` when offering the nullable skip path for `.OPT` / `.KLN`. This is conceptually consistent with CRF return replay and handles structural continuations like `END`, but the comparison run did not prove an acceptance bug in the old predicate. Open questions: does the broader conservative predicate add descriptors, change ambiguity shape, or mask useful branch-pruning? Add a focused metric/regression sweep before treating this as settled.
   Source: Jun 19 2026 investigation of `macroSignature = parameterClause macroFunctionSignatureResult? .` and failed Swift macro diagnostics.

1. **Review the wisdom of the following exception**: ****Exception (deliberate, Jul 6 2026): enum-case placement is left PERMISSIVE. `declaration = enumCaseDeclaration` is kept (not in TSPL), so `case` parses in any member block — struct/class/extension/top-level — matching swift-syntax's *parser* (testEnum12/13/14 use plain `assertParse`, no diagnostics; the compiler rejects them only in Sema). The stricter alternative (drop `declaration = enumCaseDeclaration`, list `enumCaseDeclaration` directly in `enumMember`, disable testEnum12/13/14) is equally unambiguous and more compiler-correct, but was NOT taken — the enum *ambiguity* fix (merging the two enum styles + single `case` parse path) is independent of this, and we chose not to reject three parses over a purely-semantic rule. Note: enum cases genuinely CANNOT be added via extension in Swift — it's a Sema error, not a parse error. When a future test surfaces a similar swift-syntax-only construct, the protocol is: prefer the compiler's restriction and disable the test (for swift-syntax only) with `disabledReason: "compiler error — <swift-syntax-source-of-truth ref>"`.
Source: Jun 21 2026 review of widened grammar acceptance; user preference for compiler-correct grammar over swift-syntax permissive parsing.

19. **Investigate eliminating the `-` vs `=` production distinction — make terminal/nonterminal LHS choice automatic.** Today the grammar author must pick `LHS - …` (terminal) vs `LHS = …` (nonterminal), and the difference is load-bearing in subtle ways: a terminal commits under its own name (so it can be referenced by lookbehind/exclusion/`>->` operand lists that match against *committed terminals*), whereas a nonterminal with a single anonymous-regex RHS commits under a generated name and is invisible to those lists. This bit us with `decimalLiteral = /…/` (nonterminal) vs `decimalLiteral - /…/` (terminal): `regexOpenSlash`'s `<-<` operand-ender list named `decimalLiteral`, but the number committed under a generated name, so the `@splitBefore` operator split wasn't suppressed after a number (`1/^/3` → spurious `/^`+`/3`, testForwardSlashRegex11#1). Investigate inferring terminal-vs-nonterminal automatically (e.g. an LHS whose RHS is a single regex/literal with no nonterminal references is a terminal) so the author can't get it wrong, or unify so any named LHS is referenceable by the lookbehind/exclusion machinery regardless of `-`/`=`.
Source: Aug 22 2026 root-cause of the last residual ambiguity (testForwardSlashRegex11#1); `Swift.apus` `decimalLiteral` fix.

20. **Source AST terminal text from tiled spans, not the commit log.** `SwiftSyntaxGenerator.collectTerminalText` and `MessageParser.terminalImage(startingAt:)` read the commit log, which is a SUPERSET of the accepted derivation — it holds terminals from derivations that later died. On `1.5` the scanner commits the float `1.5` at the `1` *and* `.5` at the `.`, so naive concatenation produced `1.5.5`. The cursor/overlap skip landed Sep 2 2026 is a patch, not a cure: `terminalImage` still resolves multiple commits at one start by taking the LONGEST (`MessageParser.swift:265`), a maximal-munch guess that hands back dead-derivation text anywhere the accepted parse committed the SHORTER token. `tileBody` already knows the exact terminal spans, so the converter should read text from the tiled span instead of scanning `commitsByStart` positionally. Related to TODO 11 (commit-index consolidation).
Source: Sep 2 2026 Phase 1 tree-fidelity work; `GenerateSwiftSyntaxAST.swift`.

21. **DONE (Sep 3 2026) — `flattenInfixExpression` dropped assignment / ternary right-hand sides.** Fixed by `flattenExpression`, which splices a nested `expression`'s elements into the parent flat sequence instead of nesting a `SequenceExpr`. See `SwiftSyntax Mapping.md` § Phase 2.

22. **DONE (Sep 3 2026) — residual tiled-text walk failures are now ZERO.** Root cause was not a missing tiling: boundary assertions (`>s<`, `<s>`, `>n<`, `<n>`) sit in an alternate's body as zero-width `.B` symbols. They never commit, so `terminalContent` found no image and the whole walk failed — which is why the fallbacks clustered on regex literals, attributed function types and `~` types, all annotation-heavy rules. A zero-width span contributes no text, so `tiledText` now returns success with no output when `from == to`. Corpus-wide fallbacks went 119 → 0, and `collectTerminalText` is exact everywhere; the positional `scanTerminalText` fallback remains only as an unreachable safety net with a diagnostic. Found by instrumenting the failure reason rather than guessing — the diagnostic named `>n<` (B) directly.

23. **DONE (Sep 3 2026) — Scott's punt is closed: nullable `A A` no longer loses its parse, and the two ε-readings stay distinct.**
   `S = A A . A = "a" | "" .` on `"a"` went `(rawMatch: true, postMatch: false, pruned: 12, isUnambiguous: true)`
   → `(postMatch: true, isUnambiguous: false)`. TWO independent ε blind-spots, both in the dead-wood
   passes, found with `APUS_TRACE_ORACLE=1` after splitting the phase-1 log into its two components
   (that split is kept — it is what localised this):

   1. **`pruneUnproductive` validated ε alternates but never MARKED them.** `visitAlternates`
      filters EPS out of the body (`filter { $0.kind != .EPS }`) because ε consumes nothing, then
      accepts the alternate on `from == to` — without inserting anything into `reachable`. The
      sweep at the end deletes every yield not in `reachable`, so the EPS nodes' `(i,k,k)` yields
      were swept away. Fixed by marking each EPS symbol of a validated empty alternate at `(from, from)`.

   2. **`hasEmptyAlt` only recognised a SYNTACTICALLY empty body.** An alternate spelled `""` is not
      `body.isEmpty` — its body holds an EPS node — so `A = "a" | ""` was never recorded as nullable.
      The completion `(A,i,i)` therefore fell past the `hasEmptyAlt` fast path into `lastSymSpans`,
      which needed the very EPS yields defect 1 had just deleted. Fixed with
      `body.allSatisfy { $0.kind == .EPS }`.

   Defect 1 deleted the support, defect 2 turned the missing support into a cascade — which is why
   the trace showed `pruneUnproductive (-3)` still ALIVE, then `pruneUnsupported (-6)` GONE.
   Verified: full suite unchanged at 1233 differing labels, accepts 0, ambiguity 0, no wrongly
   accepted rejects.

   **The invariant is now enforced.** `logRootStatus` asserts, at EVERY phase boundary, that the
   root's full-span yield still exists: past `disambiguate()`'s entry guard "rawMatch" holds by
   construction, so the assertion is exactly "postMatch must still hold". Per-phase rather than
   once at the end, so a violation names the responsible pass. Verified silent across the whole
   corpus (0 fires). Every `postMatch` assertion in the test suite expects `true`, so nothing
   legitimately relies on over-pruning.

24. **`@shortest` extent does not resolve when a variable-length prefix MOVES the bracket's start.**
   Repro (`AdventTests/OracleDisambiguationTests.swift`, `EpsilonAndAvoidModel.shortestTwoOptionalsSecond`):
   ```
   grammar:  x - /x/ .  S = [ x ] @shortest [ x ] .
   message:  "x"
   observed: (rawMatch: true, postMatch: true, pruned: 1, isUnambiguous: false)
   expected: isUnambiguous == true  — @shortest on the second OPT should force it empty
   ```
   The sibling case **passes**: `shortestTwoOptionalsFirst` (`S = @shortest [ x ] [ x ] .`, `@shortest`
   on the FIRST optional, whose start is fixed at the origin) resolves correctly. So the extent rule
   works for a fixed start and fails once a variable-length prefix can move the start — only 1 yield
   is pruned and the ambiguity survives.

   The intended mechanism already exists: the comment above these two tests claims "extent compares
   interval length (not just the end), and the OPT reads its own prunable yields so the kill
   propagates along the sequence". For the moved-start case one of those two halves is not firing —
   either the length comparison is still keyed on the end position, or the kill does not propagate
   back through the preceding `[ x ]`. **That comment is now false for the second case and should be
   corrected when this is fixed.** Narrower and lower-risk than TODO 23; no soundness implication,
   the parse survives, it just stays ambiguous.
   Source: red at HEAD since `95d69f8` / `73a5c6c` (node-level `@shortest`/`@longest` + length extent).

25. **The `expression` / `conditionExpression` rule families are duplicated, and the copies have already drifted apart twice.**
   `conditionExpression` exists ONLY to forbid assignment (assignment returns `Void`, so it is not a
   condition). Every other difference between the two families is drift. Measured diff of the
   alternates (Sep 3 2026):

   | alternate | `infixExpression` | `conditionInfixExpression` |
   |---|---|---|
   | `<s> infixOperator <s> …` | yes | yes |
   | `typeCastingOperator` | yes | yes |
   | tight infix | `>s< ( >->(regex) postfixOperatorToken \| dotOperator \| "&" ) >s< …` | `>s< infixOperator >s< …` |
   | ternary | `conditionalOperator expression` | FIXED — was `conditionalOperator tryOperator? awaitOperator? expression` |
   | `arrowExpr`, `assignmentOperator` | yes | absent (deliberate) |

   - **Ternary: FIXED Sep 3 2026.** The repeated `tryOperator? awaitOperator?` let `try` attach two
     ways to the ternary's FALSE branch (`conditionalOperator` holds the then-branch internally).
     `if c ? f() : try g() { }`, the `await` form and the both-branches form were all ambiguous
     pivots; `if c ? try f() : g() { }` was fine, which is why nothing caught it. The identical fix
     had been applied to `infixExpression` and never mirrored. Guarded by `ConditionInfixParityTests`.
   - **Tight infix: STILL DIVERGENT, consequence UNDEMONSTRATED.** `infixExpression` carries the
     regex gate `>->( regularExpressionLiteral )` and the `postfixOperatorToken | dotOperator | "&"`
     operator split; `conditionInfixExpression` has neither, just `infixOperator`. Parity probes for
     `a & b`, `a&b`, `a/b/c`, `a...b`, `x!.y` all pass in BOTH positions, so no behavioural
     difference has been shown — the divergence is textual so far. Do not "fix" it without a failing
     case first; add rows to `infixParityCases` when one is found.

   **The duplication is the real defect.** Two families that must be kept in sync, and the sync has
   failed twice already: once in the grammar (above) and once in `GenerateSwiftSyntaxAST`, which
   looked only for `infixExpressions` and silently dropped `x > 0` from `if let x = y, x > 0`.
   Proposed factoring: a shared `commonInfixExpression` included by both, with `infixExpression`
   adding the assignment and arrow alternates. These are the hottest rules in the grammar and carry
   the `@longest`/`@prefer` annotations, so this needs its own ambiguity A/B — NOT a drive-by.

   **`@excludedFrom(condition)` is NOT a substitute — checked Sep 3 2026.** The obvious collapse is
   to delete the whole condition family and write
   `infixExpression = @excludedFrom(condition) assignmentOperator expression .`, letting one
   annotation express the single sanctioned difference. It does not work: `ContainmentRule`
   (Oracle.swift) is pure SPAN containment — it prunes a reading whose span lies inside any yield of
   the container (`$0.i <= span.i && span.j <= $0.j`) — not an ancestor walk, and it knows nothing
   about scope boundaries. An assignment inside a CLOSURE inside a condition is lexically contained
   in the `condition` span, so it would be pruned despite being legal Swift:
   `if xs.contains(where: { c in count = 1; return true }) { g() }`.

   The duplication handles that for free: a closure body re-enters via
   `statements → statement → expression`, the UNRESTRICTED family, so the restriction stops at the
   scope boundary automatically. Any factoring must preserve this; the case is pinned by
   `ConditionInfixParityTests.assignmentInClosureInsideCondition`.

   This generalises: containment predicates express "nowhere inside X", but most language rules of
   this shape mean "nowhere inside X, until a new scope begins". Reach for a separate nonterminal
   whenever the restriction should reset at a scope boundary, and for `@confinedTo`/`@excludedFrom`
   only when it genuinely applies to the whole span.
   Source: Sep 3 2026 AST work; `ConditionInfixParityTests`.

26. **`matchPattern = @prefer expressionPattern` prevents the grammar from expressing binding-vs-match context.**
   In `case let y`, swift-syntax emits `IdentifierPattern` — the name is BOUND. In a plain match
   position the same spelling is an `ExpressionPattern` — the value is COMPARED. Our grammar cannot
   say this: `@prefer expressionPattern` prunes the identifierPattern alternate before any consumer
   sees it, so `GenerateSwiftSyntaxAST.convertMatchPattern` carries a `binding: Bool` flag and
   re-applies the distinction after the fact.

   The grammar already has the right idiom for exactly this shape of problem: `bindingSubpattern`
   (`= wildcardPattern | identifierPattern | tupleBindingPattern`) was introduced so tuple binding
   elements get an annotation-free sub-pattern, and its comment notes the structural split "removes
   the spurious typed reading WITHOUT an @prefer". The analogous move here is a `bindingMatchPattern`
   used by `valueBindingPattern`'s operand, which would let the converter's `binding` flag go away
   and would match the project's standing preference for structural fixes over `@prefer`.

   Riskier than it looks: `@prefer` is load-bearing in pattern position, and a value binding can
   contain enum-case, tuple and optional patterns, so the new nonterminal is not a two-line split.
   Needs its own ambiguity A/B.
   Source: Sep 3 2026 AST work; `Phase3BranchTests` `switch-bind` / `switch-where`.

## Maintenance Rule

- Add new markdown TODOs here and link back to source context when needed.
- `Advent/codex.md` and `Advent/claude.md` should reference this file instead of maintaining separate TODO lists.
