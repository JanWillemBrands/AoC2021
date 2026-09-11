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
            
39. **Key-path greedy commit: invalid method-specialization member still accepted.**
   `\Foo.method<Int>()` is still accepted even though swift-syntax rejects it. This is the
   long-standing greedy-keypath commit gap: Advent finds a shorter valid key-path prefix and lets
   the remaining postfix expression parse, while swift-syntax commits to the key-path shape and
   diagnoses the invalid member. Needs a structural commit/lookahead primitive, not a tree
   converter fix. testKeyPathMethodAndInitializers#3 / REJECTS.md C1.

   Resolved Sep 11 2026: `\AStruct.Type.property` and `\Foo.Type.[2]` now make `.Type` part of
   the key-path root and convert it to `MetatypeType`.

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
