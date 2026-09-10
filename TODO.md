# This file is the canonical TODO list in this project.
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
     regex gate `@cannotParse( regularExpressionLiteral )` and the `postfixOperatorToken | dotOperator | "&"`
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

27. **Bespoke attribute-argument grammars — NARROW ones only.**
   Most attributes still take `attributeArgumentClause = >s< "(" balancedTokens? ")"` — token soup
   with no structure to convert, so `convertAttribute` records `.unhandled` rather than guessing.
   `@abi`, `@available`, `@isolated`, `@attached`/`@freestanding` and now `@convention` have real
   argument grammars; the rest do not.

   **Measured constraint: do NOT reuse `functionCallArgumentList`.** Routing attribute arguments
   through the general expression grammar closes an
   `attribute -> expression -> type -> attribute` cycle and is a performance cliff: the full test
   run went from 85s to NOT FINISHING within 10 minutes. Reverting restored 85s and the exact same
   label set, confirming the cause. Write a narrow rule per attribute instead — `@convention` took
   four lines (`conventionArguments`/`conventionArgument`/`conventionValue`) and cost nothing.

   Useful discovery while doing `@convention`: swift-syntax has NO dedicated node for it. The
   arguments surface as a plain `.argumentList(LabeledExprListSyntax)`, and the same is true of
   `@attached`/`@freestanding` (checked against the reference dumps). So several of these need only
   a narrow grammar plus the EXISTING `convertArgumentList` — not a new syntax node. The ones that
   really do have bespoke nodes are `@objc` (`objCName`), `@differentiable`
   (`differentiableArguments`), `@derivative`/`@transpose` (`derivativeRegistrationArguments`),
   `@backDeployed`, `@specialized` (`specializedArguments`) and `@lifetime`.

   Remaining, by `.unhandled` count: @differentiable 11, @attached 10, @isolated 6, @lifetime 6,
   @objc 5, @freestanding 5, @derivative 4, @transpose 4, @backDeployed 3, @specialized 3.
   Also still open: `@objc(+++)` is wrongly accepted (`AttributeSoupTests`).
   Source: Sep 5 2026; performance cliff measured Sep 6 2026.

29. **The converter re-derives classifications the grammar already made — read the alternate instead.**
   `convertStringLiteral` fell through to a text-based branch that rebuilt the literal from
   `collectTerminalText`: pound count, quote count, body, segments. In doing so it re-decided
   "is this multiline?" with `hasPrefix("\"\"\"")` and reached the OPPOSITE conclusion from the
   scanner, which had already classified `#""""#` as `extendedSinglelineStringLiteral` (its regex
   requires `tripleQuote` then `lineBreak`, and `GrammarRegexLibrary` even names this case).
   Result: we synthesised `"""` delimiters the source never had, on 11 labels.

   Measured extent: 77 `collectTerminalText` call sites, ~16 of which re-decide STRUCTURE by
   sniffing the collected text (`var`/`let`, leading `.`, trailing `?`/`!`, regex and string
   delimiters). Most are safe only because a single grammar terminal can reach them; the string
   one was not, because four terminals share the `"` prefix.

   Fix shape: where several grammar alternates can reach a converter, branch on WHICH alternate
   the parse took (`find`/`findTerminal` for `multilineStringLiteral` vs
   `extendedSinglelineStringLiteral`), not on the characters. Until then the duplicated rule in
   `convertStringLiteral` must be kept in step with the library regex by hand.
   Source: Sep 6 2026, RawStringTests.testFalseMultilineDelimiters.
            
31. **Model static string-literal BODIES in the grammar, so the parser chops them up.**
   Today `multilineStringLiteral` and `extendedMultilineStringLiteral` are single `@builder`
   terminals: one regex matching pounds, `"""`, the whole body and the closing delimiters as ONE
   token. The parse therefore contains no internal structure, and the converter must recompute
   every segment boundary, escape rule and indentation strip from the token's raw text (see
   TODO 30). Both string bugs of Sep 6 2026 came from that: with nothing to read, the converter
   re-derived.

   The INTERPOLATED forms already show the shape to copy — `singleLineInterpolatedStringLiteral`
   and `multilineInterpolatedStringLiteral` decompose into Head/Part/Tail terminals, and that
   converter path has never had this class of bug because it just walks the children.
   Sep 10 2026 update: the known repeated/nested interpolation tree mismatches were fixed by
   making the converter walk EBNF closure iterations for Head/Part/Tail and by adding a narrow
   plain-multiline recovery for active `\(` markers. The broader structural TODO remains: static
   bodies are still opaque builder terminals.

   Proposed: give the static forms the same treatment — a body as a sequence of segment and
   escape nodes, so `convertStringLiteral` reads segments instead of computing them, and
   `multilineSegmentTexts` can be deleted.

   Trade-offs, both real:
   - The escape, line-continuation and indentation rules move INTO `Swift.apus`, where they are
     declarative and testable per-node — but the indentation rule is contextual (it depends on
     the closing delimiter's column), which is exactly the kind of thing a CFG expresses badly.
     `REJECTS.md` § C2 Group D already lists the indentation rule as unenforced for this reason.
   - Touching the string terminals touches the SCANNER, the highest-risk area in the grammar
     (catastrophic-backtracking history, Schrödinger/Frankenstein interactions), for a payoff
     that is code quality rather than tree fidelity: the current converter now matches
     swift-syntax on every corpus fixture.

   So: worth doing, but schedule it as its own piece of work with a full A/B, not folded into
   tree-fidelity work.
   Source: Sep 6 2026, user request after TODO 29/30.

32. **Why is `>->` over a NONTERMINAL not equivalent to `>->` over that nonterminal's literals?**
   Measured Sep 7 2026, trying to de-duplicate the builtin-attribute exclusion list that appears
   in BOTH general `attribute` rules:

   ```
   // works
   attribute = "@" >-> ( "abi" "attached" "available" … ) >s< attributeName attributeArgumentClause? .

   // does NOT suppress the general rule
   builtinArgumentAttributeName = "abi" | "attached" | "available" | … .
   attribute = "@" >-> ( builtinArgumentAttributeName ) >s< attributeName attributeArgumentClause? .
   ```

   With the nonterminal, `Residual ambiguity` went 0 -> 89 and wrongly-accepted 0 -> 9, while the
   tree-diff label set stayed BYTE-IDENTICAL and accepts stayed at 0. So the gate silently stopped
   firing: both the bespoke rule and the general soup rule matched the same span.

   That the label set did not move at all is the interesting part — it says the extra readings were
   being discarded downstream (Oracle/`@longest`) rather than changing any tree, which is why only
   the ambiguity and reject counters noticed. Any invariant check that watched labels alone would
   have called this refactor clean.

   Resolved note:
   - Nonterminal gates are Oracle parse predicates spelled `@canParse(N)` /
     `@cannotParse(N)`. Symbolic `>+>` / `>->` are token lookaround and should not carry
     nonterminal operands.

   Source: Sep 7 2026.

33. **Tree fidelity frontier — refresh the count with `tools/rank_tree_diffs.py`.**
   `tools/rank_tree_diffs.py <log>` regenerates the queue; `caffeinate -i` the run (TESTING.md
   "Sleep, not flakiness"). Invariants held at every one of ~85 measured increments: accepts 0,
   ambiguity 0, wrongly-accepted 0, `.lookupFailed` 0, crashes 0.

   **Every remaining known label is TODO 38–40 (grammar).** The converter one-off list is CLOSED — there
   is no known converter gap left in the accept corpus. `testCoroutineAccessors#1` is DISABLED
   rather than fixed: SE-0443 `read`/`modify` need `@_spi` `Keyword` cases that cannot be
   constructed outside swift-syntax. Disabling skips all four of its tests, so the count
   understates the gap by one and that snippet no longer verifies Advent parses it.

   Three lessons, each of which cost real time and all of which recurred:

   - **A silent `return nil`, or a `find` that quietly misses, is the most expensive bug shape.**
     `labelName` lives inside `statementLabel` and `find` does not descend through nonterminals;
     `propertyWrapperProjection`/`forceMark`/`dotOperator` are `-` TERMINALS needing
     `findTerminal`; `initializedAccessorBlock` was routed to the willSet/didSet converter, which
     finds no observers and returns an empty list. Each LOOKED like "not implemented" and was
     actually "looked in the wrong place". Add a diagnostic before theorising — doing that to
     `convertInterpolatedStringLiteral` produced the cause in one run and 5 labels.
   - **Token kind is POSITION-dependent.** A backtick-escaped name is not an operator (one
     omission bit three separate name maps); `Self` is `keyword(Self)` only as a LEADING
     IdentifierType. Also `typeAsExpression`: swift-syntax spells a type that COULD be an
     expression as one (`Void` is a DeclReferenceExpr) and wraps only type-only forms in TypeExpr.
   - **Right-recursive grammar lists sometimes fold LEFT in swift-syntax.** Sibling nested postfix
     `#if` blocks chain, each taking the previous as its base; nested arrow returns SPLICE into
     one flat sequence rather than nesting. Read the reference dump before assuming the shape
     mirrors the rule.

39. **GRAMMAR: `\AStruct.Type` — no metatype alternate in `keyPathRootBase`.**
   The `.Type` becomes a key-path COMPONENT instead of making the root a `MetatypeType`. Adding
   `| metatypeType` risks ambiguity with the component route, so it needs `@longest`/`@prefer` and
   a full A/B. testKeyPathMethodAndInitializers#10.

40. **GRAMMAR: custom attributes with expression arguments take the balanced-token soup.**
   `@Argument(help: "…")`, `@attr2(…)`, `@inline(__always)` all reach `attributeArgumentClause`,
   which carries no structure, so the arguments cannot be converted. swift-syntax gives them
   `.argumentList`. The grammar's own note says swift dispatches on the attribute NAME — known
   attributes get token soup, unknown ones an expression list — so the fix is to route
   NON-builtin names to `attributeArgumentExprClause`. Must stay narrow: see the measured
   performance cliff in TODO 27. testAttributedMember#1, testTypealias#3, testYield#2 (~4).

41. **Fixture LABELS are not unique — the A/B method keys on them.**
   Measured Sep 8 2026: 114 label names appear in BOTH `SwiftSyntaxRejects.swift` and an accept
   file with DIFFERENT sources, and 11 names are duplicated WITHIN the accept corpus
   (`div-chain`, `if-else`, `if-simple`, `subscript`, `testDifferentiableAttribute#1`, …).

   Why it matters: the tree-diff baseline is captured as
   `grep -o "Trees differ for '…'" | sort -u`, so two differing snippets sharing one label
   collapse into a single entry. A regression in one could be masked by the other, and the
   "newly broken" diff would show nothing.

   Currently harmless — 33 raw `Trees differ` lines, 33 unique, and none of the 11 duplicates are
   in the differing set — so every number reported so far stands. But that is luck, not design.

   Also a live trap when READING results: a label in the tree-diff output refers to the ACCEPT
   snippet (the tree suites iterate the accept arrays), NOT to the same-named reject snippet.
   Looking a label up in `SwiftSyntaxRejects.swift` and concluding "this is a reject fixture" is
   wrong; that mistake was made once while triaging the final 33.

   Fix options: make labels unique at harvest time (prefix with the origin file), or make the
   suites emit `origin` alongside the label so the diff key is unambiguous.


43. **DISABLED fixtures (≈199 `disabledReason` occurrences) — audit as one pass.**
   They are not all the same kind of thing, and only the last group is a real backlog:

   - **≈126 feature-gated**: `"underscore attribute"` (89), `"experimental feature"` (37). Bulk
     categories applied wholesale; worth re-checking whether the corpus pin still justifies them.
   - **≈35 compiler-invalid**: swift-syntax parses permissively but `swiftc` rejects — empty
     case/default bodies (14), inline `where` in a generic parameter clause (8), deprecated
     `: class`, `case foo()`, bodyless subscripts, bare types as statements, keyword macro names,
     `\()`, misplaced `static`. We follow the COMPILER, so these are correctly disabled and only
     need re-probing if the arbiter changes.
   - **≈8 deliberate design divergence**: regex-body bracket balancing (7 — our
     `plainRegularExpressionLiteral` is a balanced CFG by design, swift-syntax uses a sub-lexer we
     do not replicate) and the leading-combining-char identifier (we follow Unicode TR31).
   - **REAL backlog, 3 items**: `read`/`modify` `@_spi` Keyword cases (TODO 33); the greedy-keypath
     commit needing a structural-lookahead primitive (REJECTS.md C1); and the regex-after-`?`
     case blocked by `conditionalOperator`'s `<s>` spacing policy.

   Only that last group is work. Re-probe the first three groups at the next swift-syntax bump
   rather than one at a time.

## Maintenance Rule

- Add new markdown TODOs here and link back to source context when needed.
- `Advent/codex.md` and `Advent/claude.md` should reference this file instead of maintaining separate TODO lists.
