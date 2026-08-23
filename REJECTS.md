# Reject Test Failures: Inventory

## Purpose

Inventory of all known failures in the `adventRejects` / `swiftSyntaxRejects` test suites.
Each entry records the root cause, current status, and preferred fix approach.

The broader goal is to identify issues that expose gaps in the APUS annotation vocabulary,
and to design new general-purpose APUS tools — reusable across grammars, not Swift-specific.
"Structural lookahead" (peering through the content of a non-terminal before deciding to
match it) is one such candidate.

---

## Resolved

### R1 — `testNonBreakingSpace#1`

**Source:** `a \u{00A0}+ 2`
**Origin:** `ExpressionTests.testNonBreakingSpace`

Swift-syntax emits only a `.warning`-severity diagnostic for a non-breaking space (U+00A0),
not an `.error`. Since `swiftSyntaxAccepts` is keyed on `!parsed.hasError` (not `hasWarning`),
this snippet is syntactically valid and belongs in the accepts suite.

**Resolution:** Moved from `expressionRejectSnippets` to `expressionSnippets` in
`SwiftSyntaxExpressions.swift`. ✓

**Accept-side grammar fix (2026-08-05):** moving it to the accepts suite exposed that the
`whitespace` terminal (reject-era) had dropped U+00A0, so Advent couldn't parse `a<NBSP>+ 2`.
Added `\u{00A0}` back to the `whitespace` regex (swift-syntax lexes NBSP as trivia + a
`.nonBreakingSpace` warning; it is the only non-ASCII whitespace so treated). Accept now passes. ✓

---

### Resolved: B1 — Trailing Closure on Literal Expressions *(partial)*

**Test cases:** `testLiteralWithTrailingClosure#1` – `#9`

| # | Source | Status |
|---|--------|--------|
| 1 | `_ = true { return true }` | ✓ fixed (`disabledReason` on accept-side, compiler rejects) |
| 2 | `_ = nil { return nil }` | ✓ |
| 3 | `_ = 1 { return 1 }` | ✓ |
| 4 | `_ = 1.0 { return 1.0 }` | ✓ |
| 5 | `_ = "foo" { return "foo" }` | ✓ |
| 6 | `_ = /foo/ { return /foo/ }` | **still open** (see below) |
| 7 | `_ = [1] { return [1] }` | ✓ |
| 8 | `_ = [1: 1] { return [1: 1] }` | ✓ |
| 9 | `_ = 1 + 1 { return 1 }` | ✓ |

**Root cause:** The grammar rule `functionCallExpression = postfixExpression trailingClosures`
placed no restriction on what `postfixExpression` reduces to. A bare integer, boolean, nil,
string, regex, array, or dictionary literal is a valid `postfixExpression`, so the grammar
accepted `1 { }`, `[1] { }`, etc.

**Fix implemented (2026-08-01):** Introduced two new non-terminals:

- `nonLiteralPrimary` — all 20 `primaryExpression` alternatives **except** `literalExpression`
  (keeps `@prefer parenthesizedExpression` for the `(…)`-vs-functionType disambiguation)
- `nonLiteralPostfix` — `nonLiteralPrimary` plus all 8 postfix-chain alternatives:
  postfixOperator, postfixOperatorToken, dotOperator, functionCallExpression,
  initializerExpression, explicitMemberExpression, subscriptExpression, forcedValueExpression,
  optionalChainingExpression

Changed `functionCallExpression` to:
```
functionCallExpression = @prefer postfixExpression functionCallArgumentClause trailingClosures
                       | nonLiteralPostfix trailingClosures .
```

The second alternative covers trailing-closure-only calls (`f{}`). `nonLiteralPostfix`
ensures the callee is either a non-literal primary or has at least one postfix operation
applied (so `1!`, `[1][0]`, `1.description` are all callable — matching swift-syntax's
`!leadingExpr.raw.kind.isLiteral` check which applies at postfix level, not primary level).

**Residual: test #6** — `_ = /foo/ { return /foo/ }` — regex literals are not in
`literalExpression` in the grammar; they have their own scanner mode and production path.
The B1 exclusion therefore doesn't apply. Filed as C3 (forward slash regex issues) below.

**Net improvement:** 8 tests fixed, 107 → 99 effective adventRejects once C3 is addressed.

---

### Resolved: B3 — Guard without Required Clause

**Test cases:**

| Label | Source |
|-------|--------|
| `testGuard1#1` | `func noConditionNoElse() { guard {} }` |
| `testGuard2#1` | `func noCondition() { guard else {} }` |

**Root cause (investigated):** Both tests are already passing. `guard {}` — the `>->("{")` gate
on `"guard"` was preventing the rule when the next token was `{`, but even after those gates were
removed the tests still pass: swift-syntax's `parseConditionList` consumes the `{}` as a closure
condition, and the missing `else` means `hasError` is set. Advent rejects correctly because
`conditionList` parsing of a bare closure followed by no `else` fails. `guard else {}` — `else`
is excluded from `hardIdentifier` so `conditionList` finds no valid condition and Advent rejects.

**Status:** Tests confirmed passing. The `>->("{")` annotations on `if`/`switch`/`while`/`guard`
were briefly **removed** (2026-08-01) in anticipation of a different fix, then **re-added** as B2
discriminator 2 (see B2 above) — a condition/subject may never open with `{`. ✓

**Side effect (historical, now resolved):** while the gates were removed, `testRecovery28#1`
(`repeat {} while { true }()`) failed adventRejects. With the `>->("{")` gates restored under B2,
Advent rejects it again; the only remaining wrinkle is on the swiftSyntax-reference side (see the
B2 caveat).

---

### Resolved: B4 — if-Expression with Multiple / Invalid Type Operations

**Test cases:**

| Label | Source summary |
|-------|---------------|
| `testIfExprMultipleCoerce#1` | `if .random() { 0 } else { 1 } as Int as Int` |
| `testIfExprIs#1` | `if .random() { 0 } else { 1 } is Int` |

**Root cause:** An if-expression used as the left operand of `as`/`is` in a sequence
expression. Swift-syntax's `parseSingleValueStmt` handles if/switch and returns *without*
trying to parse infix operators — so no `as`/`is`/`+` etc. can follow an if/switch expression.
The grammar was allowing it because `conditionalExpression` was reachable via
`primaryExpression → postfixExpression → prefixExpression`, putting it in the same
sequence-element position as any other expression.

**What swift-syntax actually does:** If/switch are parsed inside `parseUnaryExpression`
as ordinary sequence elements — there is NO grammar-level gate. The sequence loop can
append `as Int`, `is Int`, `as Int as Int`, etc. Swift-syntax builds a `SequenceExprSyntax`
and sets `hasError` **post-parse** during operator-precedence folding/validation, not
during parsing.

**Fix (implemented 2026-08-01, grammar-level):**
- Removed `primaryExpression = conditionalExpression .`, so if/switch can no longer be
  a `prefixExpression` (sequence operand or infix LHS).
- Added `expression = tryOperator? awaitOperator? conditionalExpression coercingOperator? .`
  where `coercingOperator` covers `as`/`as?`/`as!` but NOT `is`.
- Added a separate `coercingOperator` non-terminal (subset of `typeCastingOperator`,
  excluding `"is" type`).
- Assignment (`=`) and ternary false-branch use `expression` (not `prefixExpression`)
  so `x = if...` and `a ? b : if...` remain valid.

**Verified:** `adventAccepts` and `swiftSyntaxAccepts` for ExpressionSyntaxTests: 0 failures.
`RejectSyntaxTests`: 118 (down from 121; B4's 2 tests × 2 facets = 4 fewer). ✓

---

### Resolved: B5 — Member Access with String Interpolation

**Test case:** `testMissing#1`
**Source:** `` someVar.\(trailing) ``

**Root cause:** `\(...)` is a string-interpolation escape sequence valid only inside a
string literal. Using it in member-access position (`someVar.\(...)`) is syntactically
invalid, but the GLL grammar may scan the `\(` as a valid token and admit it as a member
name.

**Status:** Confirmed passing (2026-08-01 test run). ✓

---

### Resolved: B6 — Xcode Placeholder Token

**Test case:** `testTrailingClosures13b#1`
**Source:** `fn {} g: <#T##() -> Void#>`

**Root cause:** `<#T##() -> Void#>` is an Xcode editor placeholder. Swift-syntax handles
it as an `editorPlaceholderExpr` and sets `hasError`. Advent's scanner does not recognise
the `<#…#>` syntax, so this should fail at scan time and `adventRejects` should pass.
Verify: the `swiftSyntaxRejects` check (`parsed.hasError`) should also pass since
swift-syntax sets `hasError` for placeholders.

**Status:** Confirmed passing (2026-08-01 test run). ✓

---

### Resolved: C13a — Missing Space Around `=` in Declarations

**Test cases:** `testRecovery163#1`, `testRecovery164#1`

| Label | Source |
|-------|--------|
| `testRecovery163#1` | `let _= 5` and `let _ =5` |
| `testRecovery164#1` | `let _: Int= 5` and `let _: Array<Int>= []` |

**Root cause:** Swift's lexer (`classifyOperatorToken` in `Cursor.swift`) rejects `=` with
inconsistent surrounding whitespace universally — in declarations and expressions alike.
Advent had no spacing enforcement on declaration-initializer `=`.

**Fix (2026-08-02):** Introduced `assignmentOperator` nonterminal with symmetric spacing:
```
assignmentOperator = <s> "=" <s> | >s< "=" >s< .
```
All production-rule `"="` tokens replaced: `initializer`, `infixExpression`, `captureListItem`,
`typealiasAssignment`, `defaultArgumentClause`, `enumCaseRawValueInitializer`, `macroDefinition`. ✓

---

### Resolved: C13b — Invalid Unicode in identifiers

**Test cases:** `testRecovery160#1`

| Label | Source |
|-------|--------|
| `testRecovery160#1` | `let ￼tryx = 123` (U+FFFC Object Replacement Character before identifier) |

**Root cause:** The `identifierHead` / `identifierCharacter` regex classes in
`SwiftGrammarRegexLibrary.swift` used `FE47–FFFD` as the upper Unicode range, but
swift-syntax (`UnicodeScalarExtensions.swift`) uses `FE47–FFF8` — U+FFF9–FFFD are excluded
(FFF9 = Interlinear Annotation Anchor, FFFC = Object Replacement Character, FFFD = Replacement
Character).

**Fix (2026-08-02):** Changed both `identifierHead` and `identifierCharacter` upper bounds from
`\u{FFFD}` to `\u{FFF8}` in `SwiftGrammarRegexLibrary.swift`. ✓

---

### Resolved: C13b — Consecutive member declarations without separator

**Test cases (9):** `testConsecutiveStatements4a/4b`, `5a/5b`, `6a/6b`, `8`, `testTrailingSemi4a/4b`

**Root cause:** All 6 member list types (`enumMembers`, `structMembers`, `classMembers`,
`actorMembers`, `protocolMembers`, `extensionMembers`) used `xMembers = xMember xMembers?` —
no separator required between consecutive members. The `statements` grammar already enforced
this correctly via `statementSeparator = <n> | ";"`.

**Fix (2026-08-03):** Mirrored the `statements` pattern for all 6 member list types.
Removed `";"?` from each `xMember` definition; replaced `xMembers = xMember xMembers?` with:
```
xMembers = xMember ";"? .
xMembers = xMember statementSeparator xMembers .
```
Reuses the existing `statementSeparator` non-terminal — no new rules needed. ✓

---

### Resolved: C13c — Assignment expression in condition position

**Test cases:** `testRecovery153#1`

| Label | Source |
|-------|--------|
| `testRecovery153#1` | `if var y = x, z = x { z = y; y = z }` |

**Root cause:** `condition = expression` allowed any `expression` in condition position,
including assignment expressions (`z = x` via `infixExpression = assignmentOperator ...`).
Swift assignment returns `Void` — it is never a valid condition expression — but Advent's grammar
accepted it without error.

**Fix (2026-08-03):** Introduced `conditionExpression` and `conditionInfixExpression` in
`Swift.apus`. `conditionInfixExpression` mirrors `infixExpression` but omits the
`assignmentOperator` alternative. Three usage sites updated to use `conditionExpression`:
`condition`, `repeatWhileStatement`, and `whereExpression`. ✓

**Permissive counterpart disabled (2026-08-05):** swift-syntax *accepts* `if _ = 42 {}` syntactically
(`testMissingIfClauseIntroducer#1`), but this same rule (correctly) rejects it as an assignment in
condition position. Per the follow-the-compiler policy we keep our interpretation and marked that
accept snippet `disabledReason: "compiler error — …(we follow compiler)"` rather than loosen the rule.

---

### Resolved: C11 (partial) — Invalid Backtick-Escaped Identifiers: Null Byte and Backslash

**Test cases:** `testEscapedIdentifiers18#1`, `testEscapedIdentifiers21#1`

| Label | Source | Violation |
|-------|--------|-----------|
| `testEscapedIdentifiers18#1` | `` `null\u{0000}is not allowed` `` | Null byte inside backtick identifier |
| `testEscapedIdentifiers21#1` | `` `\\starting` ``, `` `mid\\dle` `` | Backslash inside backtick identifier |

**Fix (2026-08-02):** The `escapedIdentifier` regex was corrected to exclude control characters
(`\u{0000}-\u{001F}`) and backslash (`\\`). Also fixed `\u{2000}-\u{200A}` range (invalid as
Swift regex range bounds) → `\u{2000}\u{2001}\u{2002}-\u{200A}`. ✓

**Residual:** `testEscapedIdentifiers16#1` (operators inside backticks) remains open — see C11 below.

---

### Resolved: B7 — Reserved Keyword as Trailing Closure Label

**Test cases:** `testTrailingClosures14a#1`, `testTrailingClosures14b#1`

**Source (both, appears duplicated):**
```swift
func produce(fn: () -> Int?, default d: () -> Int) -> Int {
    return fn() ?? d()
}
_ = produce { 0 } default: { 1 }
_ = produce { 2 } `default`: { 3 }
```

**Root cause:** Bare `default:` as a labeled trailing closure label. Swift-syntax's
`atStartOfLabelledTrailingClosure()` explicitly checks `self.at(.keyword(.default))`
and returns `false` — with comment: "But 'default:' is ambiguous with switch cases and
we disallow it (unless escaped) even outside of switches." All other keywords (including
`case`, `return`, etc.) ARE valid trailing closure labels per `atArgumentLabel()` /
`isArgumentLabel()`.

The duplicate source in 14a vs 14b is a harvesting artefact.

**Fix (2026-08-01):** Added `trailingClosureLabel` non-terminal used in
`labeledTrailingClosure` — mirrors `argumentLabel` (`softIdentifier | "_"`) but also
excludes `default`. The exclusion set is `---("_" "let" "var" "inout" "default")`.

**Status:** Both tests passing. ✓

---

## Resolved: B2 — Trailing Closure / Closure Expression in Condition or Subject Position

**Test cases:**

| Label | Actual source (verbatim; newlines matter) |
|-------|---------------|
| `testTrailingClosureInIfCondition#1` | `if test {⏎  $0⏎} {}` |
| `testClosureAtStartOfIfCondition#1` | `if {x}() {}` |
| `testClosureAtStartOfIfCondition#2` | `if {⏎  x⏎}() {}` |
| `testClosureAtStartOfIfCondition#3` | `if { x⏎}() {}` |
| `testClosureAtStartOfIfCondition#4` | `if { a in⏎  x + a⏎}(1) {}` |
| `testTrailingClosureInGuard#1` | `guard test { $0 } else {}` |
| `testTrailingClosureInGuard#2` | `guard test {⏎  $0⏎} else {}` |
| `testTrailingClosureInGuard#3` | `guard test { $0⏎} else {}` |
| `testTrailingClosureInGuard#4` | `guard test { x in⏎  x⏎} else {}` |
| `testRecovery17#1` | `if { true } {}` |
| `testRecovery18#1` | `if { true }() {}` |
| `testRecovery23#1` | `while { true } {}` |
| `testRecovery24#1` | `while { true }() {}` |
| `testRecovery28#1` | `repeat {} while { true }()` |
| `testRecovery50#1` | `switch { 42 } { case _: return }` — closure as switch subject |
| `testRecovery51a#1` | `switch { 42 }() { case _: return }` — called-closure as switch subject |
| `testRecovery51b#1` | (same source, duplicate) |

**Provenance / methodology note (2026-08-19):** an earlier pass hand-typed *single-line*
approximations of these sources from this table's summaries and mis-concluded that
swift-syntax now accepts them ("stale rejects"). That was a probe error, not a swift-syntax
change: `atValidTrailingClosure` keys on `isAtStartOfLine`, so flattening the newline flips the
verdict. Re-probed against the **verbatim** sources (`Parser.parse(source:).hasError`), **all
entries above are genuine rejects.** Always probe the literal snippet, never a paraphrase.

**Root cause (measured).** The rejects come from three *distinct* discriminators in
swift-syntax's `atValidTrailingClosure(flavor:)` (Expressions.swift:2263), all active only in
**`.stmtCondition`** flavor (in `.basic` flavor the function returns `true` at line 2284, so a
multiline `foo {⏎ bar⏎}` at statement level stays valid — any Advent gate MUST be scoped to the
condition path or it breaks accept-side statement closures):

1. **Newline after the closure's opening `{`** (`if test {⏎ $0⏎} {}`, and the multiline
   Recovery variants). `!self.peek().isAtStartOfLine` (line 2296): if the body's first token is
   at start of line, the `{…}` is not a condition trailing closure, so the enclosing structure
   breaks → reject. Largest sub-cluster.
2. **Condition begins with `{`** (`if {x}() {}`, `while { true } {}`, `switch { 42 } …`). The
   leading `{` is always taken as the statement body (condition = `MissingExpr`) → reject.
   Independent of newlines.
3. **Disqualifying follow token after the closing `}`** (`guard test { $0 } else {}`, single-line
   — not a newline case). The token after `}` is `else`, which is not in the follow true-set
   (`{ where , [ ( . is as ? ! : =` + operators, the operator/bracket group additionally
   requiring `!lookahead.atStartOfLine`) → closure refused → reject.

**Resolution (2026-08-23) — all three discriminators, fully declarative** (no procedural filter,
no Oracle input re-read; see `Grammar Predicate Lookahead Design.md`):

- **disc-1 — newline after `{`.** Folded the layout into a real nonterminal
  `newlineOpenedClosure = "{" <n> closureSignature? statements? "}" .` (the `<n>` fires at parse
  time), and excluded it from both condition and trailing-closure position:
  `closureExpression = @excludedFrom(conditionExpression) @excludedFrom(trailingClosures) newlineOpenedClosure .`
  `@excludedFrom` is a `ContainmentRule` BSR query — it prunes the newline-opened reading only where
  it is contained in a `conditionExpression`/`trailingClosures` yield, so statement-level multiline
  closures stay valid.
- **disc-2 — condition/subject begins with `{`.** `>->("{")` on the
  `if`/`while`/`switch`/`guard`/`repeat`-`while` keyword slots (existing terminal-anchored gate).
  Re-fixes `testRecovery28` on the Advent side.
- **disc-3 — `}` followed by `else`.** The genuinely-new primitive: the token-set `>->`/`>+>`
  forward gate now fires at **nonterminal completion**, not just after a terminal, via the shared
  `MessageParser.forwardGateAllows()` helper wired at the four CRF continuation sites (`call`
  pop-replay, `rtn`, `bracketCall`, `bracketRtn`). `trailingClosures` partitions into two disjoint
  alternates, and `@excludedFrom` prunes the `else`-following one inside a condition:
  ```apus
  trailingClosures = closureExpression >-> ("else") labeledTrailingClosures? .                              // not before else — always OK
  trailingClosures = @excludedFrom(conditionExpression) closureExpression >+> ("else") labeledTrailingClosures? .  // before else — pruned in a condition
  ```

The `@within`/`WithinRule` procedural filter that previously carried disc-1/disc-3 was deleted.

**Validation:** probe of the **verbatim** sources matches swift-syntax `hasError` on every case
(`testTrailingClosureInIfCondition#1`, `testTrailingClosureInGuard#1–4` REJECT; statement-level
`foo {⏎ bar⏎}` ACCEPTs). Full sweep: 0 accept-regressions, and no B2 label among `adventRejects`
failures. ✓

**Caveat (test data, not Advent):** `testRecovery28#1` (`repeat {} while { true }()`) now fails on
the *`swiftSyntaxRejects`* side — the current swift-syntax parses it without `hasError`, so the
snippet is miscategorised and should move to the accepts suite (same pattern as R1/B1). Advent's
own verdict is not at issue.

---

## Resolved: C1 — Key Path Expression Extensions *(one case parked)*

**Test cases:**

| Label | Source | Status |
|-------|--------|--------|
| `testKeypathExpression#2` | `\String?.!.count.?` | ✓ rejects |
| `testKeypathExpression#3` | `\Optional.?!?!?!?.??!` | ✓ rejects |
| `testKeyPathMethodAndInitializers#3` | `\Foo.method<Int>()` | ✓ rejects |
| `testKeyPathSubscript#1` | `\Foo.Bar.[2].[1]` | ✓ rejects |
| `testKeyPathSubscript#2` | `\Foo.Bar.?.[1]` | **disabled/parked** (see below) |
| `testChainedOptionalUnwrapsWithDot#1` | `\T.?.!` | ✓ rejects |
| `testChainedOptionalUnwrapsAfterSubscript#1` | `\T.abc[2].?` | ✓ rejects |

**Root cause (was):** the `keyPathExpression` grammar admitted some but not all of the postfix
operations Swift accepts inside key paths — consecutive `?.!` chains, bare subscript `.[n]`,
optional chain `.?` as a key-path postfix, generic method calls `method<T>()`.

**Status:** confirmed rejecting on the 2026-08-23 sweep (none appear among `adventRejects`
failures) — the grammar was extended to match swift-syntax's key-path postfix set. ✓

**Parked residual — `testKeyPathSubscript#2`** (`\Foo.Bar.?.[1]`), disabled in
`SwiftSyntaxRejects.swift`: swift-syntax *commits* to the key path and errors on the missing
member after `.?` (`.[` is not `.member`). Advent (GLL) also finds the valid-shaped reading
`\Foo.Bar` + infix `.?.` + `[1]`, and nothing prunes it — the greedy alternative doesn't
complete, so `@longest` can't see it. Needs a key-path-commit / structural-lookahead primitive,
not a lexical fix.

---

## Open: C2 — Malformed String / Multiline String Literals

**Test cases:**

| Label | Root issue |
|-------|-----------|
| `testMultilineString47#1` | `_ = """"""` — empty multiline string with no newline after open quotes |
| `testMultilineString48#1` | Unterminated multiline string with trailing whitespace |
| `testPostProcessMultilineStringLiteral#1` | Multiline string with inconsistent indentation |
| `testUnderIndentedWhitespaceonlyLineInMultilineStringLiteral#1` | Whitespace-only line under-indented |
| `testWhitespaceAfterOpenQuote#1` | Whitespace after opening `"""` on same line |
| `testStringLiterals#5` | String literal with invalid content |
| `testStringLiterals#10` | String literal with invalid content |
| `testNewlineInInterpolationOfSingleLineString#1` | Literal newline inside `\(...)` in single-line string |
| `testPoundsInStringInterpolationWhereNotNecessary#1` | `#"..."#` interpolation form where `#` is unnecessary |
| `testRawStringErrors2#1` | Invalid raw string delimiter |
| `testUnterminatedString4#1` | Unterminated string literal |
| `testUnterminatedString5#1` | Unterminated string literal variant |

**Root cause:** Advent's string scanner accepts malformed string literals that Swift rejects.
The scanner doesn't enforce: multiline string indentation rules, the requirement for a
newline immediately after `"""`, content restrictions in interpolation, or proper termination.
These are scanner-level (not grammar-level) checks.

---

## Open: C3 — Forward-Slash Regex: greedy-commit escape reading (same family as C1)

**Test cases:**

| Label | Source | Issue |
|-------|--------|-------|
| `testLiteralWithTrailingClosure#6` | `_ = /foo/ { return /foo/ }` | A non-regex reading makes `foo { … }` a trailing-closure call |
| `testForwardSlashRegex116#1` | `_ = qux(/, 1) / 2` + multiline | `/` should be a bare operator arg; a regex reading survives |
| `testForwardSlashRegex142#1` | `_ = /\()/` | Invalid regex body (`\(` escaped + unbalanced `)`); a non-regex reading survives |
| `testForwardSlashRegex150a#1` / `150b#1` | `_ = ^/"/"` | Custom operator `^/` ending in `/` vs. regex/string boundary |
| `testForwardSlashRegex151a#1` / `151b#1` | `_ = ^/"[/"` | Same, bracket inside the string |

**Root cause (corrected 2026-08-23): same family as C1 (greedy-commit escape reading).**
`regularExpressionLiteral` *is* part of `literal → literalExpression` (Swift.apus:358), so
`nonLiteralPrimary` already excludes it and the B1 machinery *would* reject `/foo/{}` on the regex
reading. The over-accept is NOT a missing grammar exclusion — it is the identical structure to the
disabled C1 reject `testKeyPathSubscript#2` (`\Foo.Bar.?.[1]`):

> swift-syntax **commits** greedily to one reading (regex / keypath), then **errors**; that committed
> reading yields nothing, so `@longest`/`@prefer` have no competitor to prune Advent's shorter,
> valid-shaped **escape reading**, which then survives → wrong accept.

- `/foo/{}` — swift commits to the regex `/foo/`, which can't take `{}` → error. Advent's escape is
  the division/operator lexicalization (`foo{}` becomes a trailing-closure call, the `/`s operators).
- `/\()/` — swift commits to the regex, whose body is unbalanced (`\(` escaped + stray `)`) → error.
  Advent's escape is a non-regex reading.
- `qux(/, 1)` — the position-dependence: here swift does NOT commit to regex (`/` is a bare operator
  arg). So the rule is contextual — exactly swift-syntax's `preferRegexOverBinaryOperator`.
- `^/"…"` — maximal-munch commit of the `^/` operator vs. a `/`-started regex/string.

So the fix is a **commit** primitive, not a scanner rewrite: once a regex is lexed at a
regex-eligible position (`preferRegexOverBinaryOperator`), the competing non-regex lexicalization must
be pruned **even though the regex-containing parse fails to complete** — the same "commit and prune
the escape reading" that C1 needs for keypaths. See `Regex CFG Discussion.md`,
`Regex Lookbehind Design.md`, `reference_regex_handling.md`.

**Testing (2026-08-23) — where it goes wrong (probe on `_ = <body>/ {}`):**
| body | advent | swift | note |
|------|--------|-------|------|
| `/foo/ {}` | accept | reject | leaks — identifier body |
| `/123/ {}` | reject | reject | only the `plainRegularExpressionLiteral` reading is tried, fails at `{}` |
| `/+/ {}` | reject | reject | operator body — no escape |
| `/foo/()`, `/foo/ + 1`, `/foo/.count`, `/foo/` | accept | accept | valid, unaffected |

The escape **requires an identifier body** — the scanner exposes `foo` as a bare identifier so
`foo { … }` becomes a trailing-closure call; a numeric/operator body has no such reading.

**Exact leak (per-position lexicalization dump of `_ = /foo/ {}`):**
```
P4 '/' : operatorToken='/'   regexOpenSlash='/'        ← both committed
P5 'foo': identifier='foo'   regexNonOperatorAtom='f'
P8 '/' : operatorToken='/'   postfixOperatorToken='/'  regexCloseSlash='/'
```
At P4 (right after `=`, a regex-eligible position) the leading `/` is committed as BOTH
`regexOpenSlash` AND `operatorToken` (via `operatorToken @splitBefore(regexOpenSlash)`). The escape
reading is: prefix `/` applied to `foo { }` (a trailing-closure call), then postfix `/` — a valid
prefix/postfix-operator expression. swift-syntax `preferRegexOverBinaryOperator` commits to the regex
at P4 and never offers the operator `/`, so only the (erroring) regex reading exists.

**Two grammar-level fixes tried and rejected (2026-08-23):**
- *Forbid a leading-`/` prefix operator.* Unfaithful: `_ = /x` and `_ = /E.e` (`testForwardSlashRegex21`,
  `testPrefixSlash4/6/8`) are VALID prefix-slash expressions — swift lexes a leading `/` as a prefix
  operator precisely when NO complete regex closes. Broke 36–84 regex accepts.
- *`prefixOperator = >->(regularExpressionLiteral) operator`* (the forward-derivation predicate that
  fixed `open⏎var`). Does not fire: for `/foo/{}` the `regularExpressionLiteral` reading spans `/foo/`
  but the enclosing parse fails at `{}`, so that yield is **dead-wood-pruned before the predicate
  runs** — the very reason `@longest` can't see the greedy reading in C1. The predicate only works when
  the target reading COMPLETES (a declaration does; a failing regex does not).

**The actual derivation (native `ParseTreeNode` dump of `_ = /foo/ {}`):**
```
expression [4,12]
  prefixExpression [4,12]
    <prefix-operator slot> [4,5]      ← the leading `/`
    postfixExpression [5,12]
      functionCallExpression
        nonLiteralPostfix: postfixExpression(foo [5,8])  postfixOperator(postfixOperatorToken "/" [8,10])
        trailingClosures: closureExpression "{" "}" [10,12]
```
So the escape is `/(foo/ {})` — prefix `/`, then a trailing-closure call whose callee is `foo` with a
postfix `/`.

**Raw-yield speculative predicate tried, and DISPROVEN as a fix (2026-08-23).** The
`regularExpressionLiteral` yield DOES exist in the RAW forest (`[4,10]`); the dead-wood sweep deletes
it before the predicate runs, so snapshotting the predicate's target starts from the RAW forest (a
faithful `canParseAsXxx`) makes `>->(regularExpressionLiteral)` on `prefixOperator` FIRE correctly —
instrumentation confirms it prunes `operator#1181[4,5]` to `remaining=0`. **Yet `/foo/ {}` still
accepts:** `buildAST` reconstructs a full-span tree *around* the emptied slot (the `[4,5]`
prefix-operator node above still appears, unpopulated). So the yield-keying was fine and the prune
cascaded — but post-hoc Oracle/grammar pruning of the operator yield does NOT force a reject here,
because the builder still spans the input. (The earlier `MissingExpr` I saw was just a
`SwiftSyntaxGenerator` render fallback, not an accept-criterion issue — ignore it.)

**Why the predicate prune didn't cascade (dead-wood reachability, 2026-08-23).** `pruneUnproductive`
(`Oracle.swift`) marks a node-span reachable from its **cached per-node yields** (via `endPositions` /
`visitSymbol` marking on own-yield), NOT by verifying its body still tiles from *surviving* yields.
`tileBody` returns `true` for any non-empty candidate `mids` and ignores the recursive results; the
predicate pruned `operator#1181` (inside `prefixOperator`), but `prefixOperator`'s own cached `[4,5]`
yield kept every ancestor "feasible", so the root survived and `buildAST` tiled around it. Attempting a
STRICT recursive reachability (propagate results; mark only when the body genuinely tiles) **broke 2541
accepts**: the walk's single-pass cycle guard (`expanding` → `false` on re-entry) under-marks every
span reachable only through a recursive cycle — pervasive in the Swift grammar. The generous
cached-yield approach is load-bearing: it never under-marks. A correct cascade needs the reachability
rewritten as a **least-fixpoint** (iterate marking to convergence), a real algorithm change, not the
"return the ignored value" tweak.

**Conclusion.** Two viable fixes, both real work: (1) scanner-side `preferRegexOverBinaryOperator` — do
NOT emit the operator lexicalization of a `/` where a complete regex lexes, so the escape never forms
(swift-syntax's `tryLexRegexLiteral`); or (2) a fixpoint dead-wood reachability so a targeted Oracle
prune cascades (which would also let the raw-yield `>->(regularExpressionLiteral)` predicate work).
Deferred. All exploratory changes reverted to the clean baseline (reject 46 / accept 0 / ambiguity 0).

**Separate latent bug found:** `---( namedTerminal )` crashes at grammar load. The `---(…)` operand
parser (`ApusParser`, `while token.kind == "literal"`) accepts ONLY quoted literals, not named
terminals (unlike `>+>`/`>->`/`<-<`), so a named-terminal operand isn't consumed, `expect(")")` fails,
and the load error surfaces as a crash. Should accept named terminals (or error cleanly).

---

## Resolved: C4 — Module Selector (SE-0491 `Module::name`) Invalid Forms *(11 of 11)*

Grounded in swift-syntax's `Names.swift` — `isAtModuleSelector` / `consumeModuleSelectorTokensIfPresent`
/ `parseModuleSelectorIfPresent` / `parseDeclReferenceBase`. A valid selector is
`identifier "::" baseName`: the module name must be a **plain identifier**, there is **no valid
chaining** (`A::B::c`), no leading `::`, and the base name must be on the **same line** as `::`.

- `testModuleSelectorImports#3`, `#4` — SE-0491 import-path / module-selector grammar work.
- **Same-line rule** — `testModuleSelectorWhitespace#1/#2/#3`, `testModuleSelectorExpr#1`.
  `consumeModuleSelectorTokensIfPresent` sets `skipQualifiedName = afterContainsAnyNewline`
  (Names.swift:117): a newline between `::` and the base name → missing base name → `hasError`.
  **Fix:** `moduleSelector = hardIdentifier "::" >n< .` (the `>n<` forbids a newline before the base name).
- **Binding-pattern rule** — `testModuleSelectorIncorrectBindingDecls#7/#8/#9`
  (`case let Optional.some(Swift::decl)`, `case let Swift::decl?`). Inside a `let`/`var` binding
  pattern a name is *introduced*; swift-syntax parses it as a plain identifier and leaves `::decl` as
  unexpected code → `hasError`. Advent leaked it in via `matchPattern → expressionPattern`.
  **Fix:** `moduleSelector = @excludedFrom(valueBindingPattern) hardIdentifier "::" >n< .` — the
  Oracle prunes any module selector whose span lies inside a value-binding pattern.
- **Attribute-name rule** — `testModuleSelectorIncorrectAttrNames#1` (`@main::available(macOS 10.15, *)`).
  A module-qualified attribute name is a *custom* attribute, so its args are an expression argument
  list, not the balanced-token soup builtins allow — `(macOS 10.15, *)` (an availability spec) is not
  a valid expression list. **Fix:** the general balanced-token rule's `attributeName` is now
  module-free (`attributeHeadName = hardIdentifier | selfType`); a dedicated rule
  `attribute = "@" … moduleSelector attributeName attributeArgumentExprClause?` gives module-qualified
  attributes a strict `functionCallArgumentList` argument clause. `@main::available(foo: bar)` still
  accepts.
- **`@isolated(x)` rule** — `testModuleSelectorAttrs#2` (`@isolated(Swift::any)`). SE-0431 `@isolated`
  takes a plain identifier argument (swift-syntax's parser accepts any identifier and defers the
  `any`-only check to sema, so `@isolated(sdfhsdfi)` parses). **Fix:** a dedicated rule
  `attribute = "@" "isolated" "(" identifier ")"` (and `isolated` added to the general rule's
  `>->` exclusion). A module selector leaves `::any` unconsumed → reject; `@isolated(any)` /
  `@isolated(sdfhsdfi)` accept. (`identifier`, not `hardIdentifier | "any"`, to avoid a double-match
  on `any`.)

All probe-verified against swift-syntax `hasError`; full sweep **reject 57 → 46, accept 0,
residual ambiguity 0** (matching the last commit). ✓

---

## Resolved: C5 — Invalid Access Level Modifier Combinations

**Test cases:** `testAccessLevelModifier#1`–`#11` (all confirmed rejecting, 2026-08-23 sweep)

**Source (representative):**
```swift
open open(set) var openProp = 0
public public(set) var publicProp = 0
...
```

**Root cause (corrected):** the failing cases are all `open(set)` — either bare `open(set) var`
or `open open(set) var`. This is NOT a "duplicate modifier" counting problem: `open` is simply
never a *setter* access level. Swift-syntax only tolerates a leading `open(set)` by reading it as
a call; the compiler rejects it.

**Fix:** `accessLevelModifier` offers the `X | X "(" "set" ")"` pair for
`private`/`fileprivate`/`internal`/`package`/`public`, but `open` has **no `(set)` alternate**
(`accessLevelModifier = "open" .`). Dropping that one alternate makes `open(set)` unparseable, so
both `open(set) var` and `open open(set) var` reject. The other `X(set)` forms remain valid. ✓

---

## Open: C6 — Coroutine Accessors and Init Accessor with Default Values

**Test cases:** `testCoroutineAccessors#1`, `testCoroutineAccessors#2`,
`testInitAccessorsWithDefaultValues#1`

**Coroutine accessor sources:**
```swift
// #1: _read + modify
var i_rm: Int { _read { yield _i }  modify { yield &_i } }
// #2: _modify + read
var ir_m: Int { _modify { yield &_i }  read { yield _i } }
```

**Root cause:** The coroutine accessor blocks `_read { yield }`, `_modify { yield }`,
`read { yield }`, `modify { yield }` use `yield` as a statement. Advent may be accepting
these because `yield` inside an accessor is parsed as an expression call `yield(...)` rather
than a statement. The combination `_read + modify` or `_modify + read` in one `var` block
is flagged by swift-syntax as an invalid accessor combination.

For `testInitAccessorsWithDefaultValues#1`: init accessors with default values on the same
binding are invalid in Swift but may be accepted by Advent.

---

## Open: C7 — Recently-Added / Evolving Language Keywords

**Test cases:**

| Label | Source | Keyword / Feature |
|-------|--------|-------------------|
| `testUsing#1` | `@MainActor\nusing` | `using` keyword (Swift 6.2+) |
| `testInverseTypesInParameter#1` | `func f(_: any borrowing ~Copyable) {}` | `~T` inverse type in parameter |
| `testNonisolatedSpecifier#2` | `func foo(test: nonisolated () async -> Void)` | `nonisolated` as type modifier |
| `testAsync11d#1` | (async-related snippet) | Async modifier ordering |

**Root cause:** Syntax added after the grammar was last updated:
- `using` is not a keyword in the grammar.
- `~Copyable` in parameter position (the `~` before a type name) may not be handled.
- `nonisolated` as a standalone type modifier (not a declaration modifier) — `nonisolated` in
  type position means the function type is not isolated, but the grammar may only handle it in
  declaration-modifier position.

---

## Open: C8 — Multiline Generic Arguments Containing `of` Keyword

**Test cases:** `testMultiline#1`, `testMultiline#2`, `testMultiline#3`

**Sources:**
```swift
S<[
    3
    of      // ← 'of' at start of line inside array-in-generic
    Int
]>()
```
```swift
S<[3
   of Int]>()
```

**Root cause:** The word `of` appears at the start of a line inside a generic argument that
is itself an array type `[...]`. The layout-sensitive scanner may be treating `of` as a
keyword (statement separator or similar) rather than as an identifier in this context, causing
the generic argument to be mis-parsed. Swift-syntax rejects these forms (sets `hasError`).

---

## Resolved: C9 — `@abi` Attribute and Macro Role Name Violations

**Test cases (all resolved 2026-08-04):**

| Label | Source | Violation |
|-------|--------|-----------|
| `testMacroRoleNames#1` | `@attached(member, names: named(class))\nmacro m()` | `class` used as a macro role name |
| `testABIAttribute#1` | `@abi(<#fnord#>)\nfunc placeholder() {}` | Placeholder inside `@abi` |
| `testABIAttribute#2` | `@abi(import Fnord)\nfunc invalidDecl() {}` | `import` inside `@abi` |
| `testABIAttribute#3` | `@abi(var )\nvar v1` | Trailing space / empty decl in `@abi` |
| `testABIAttribute#5` | `@abi()\nfunc fn2() {}` | Empty `@abi` arg list |
| `testABIAttribute#6` | `@abi\nfunc fn3() {}` | `@abi` with no argument at all |

**Fix (2026-08-04):** Added dedicated `attribute` rules in `Swift.apus`, with the general rule
using `>->("abi" "attached" "freestanding")` to skip the three names that have dedicated rules.

**Accept-regression + hybrid repair (2026-08-05):** The first cut over-tightened both arms and
**wrongly rejected 34 valid attribute snippets** (ACCEPT suite was at 0 before this work). Fixed by
making each arm cover exactly what swift-syntax accepts — a hybrid of specific + token-soup:
- **`@abi`** stays a *specific* declaration check (token-soup can't reject `@abi(import Fnord)`), but
  `abiDeclaration` was **widened** to the bodyless/accessor/constant forms swift-syntax allows:
  `constantDeclaration` (`let c1, c2`), `bodylessInitializerDeclaration` (`init()`),
  `abiSubscriptDeclaration` (bodyless `subscript(…) -> …`), `abiVariableDeclaration`
  (`var v { get set }` with no type annotation).
- **`@attached`/`@freestanding`** replaced `functionCallArgumentList?` (too narrow — rejected
  `named(deinit)`, `named(subscript)`, `named(init(a:b:))`, module selectors) with a faithful
  token-soup `macroRoleArguments`, whose identifier atom excludes exactly the keywords
  swift-syntax's `parseDeclReferenceBase` rejects as decl-reference names (everything except
  `init`/`deinit`/`subscript`/`self`/`Self`, plus role `extension`). `named(class)` still fails
  (`testMacroRoleNames#1` preserved); `literal` omitted so `named(true)`/`named(nil)` still fail.
  A stray `"::"` atom was dropped — it duplicated the scanner's `:`/`::` Schrödinger reading and
  caused 2 pivot ambiguities (`testModuleSelectorExpr#8/#9`).

All C9 rejects preserved; all 34 attribute accepts restored; 0 residual ambiguity. ✓

---

## Open: C10 — Spacing-Sensitive Postfix Operator Parsing

**Test cases:**

| Label | Source | Issue |
|-------|--------|-------|
| `testOperators34a#1` | `foo!!foo` | `!!` treated as custom operator |
| `testOperators34b#1` | `foo!!foo` | (duplicate) |
| `testOperators35a#1` | `foo??bar` | `??` without surrounding spaces parsed as operator |
| `testOperators35b#1` | `foo??bar` | (duplicate) |

**Root cause:** Swift requires that `!!` is parsed as `foo!` (postfix force-unwrap) followed by
`!foo` (prefix logical-not), and `??` without spaces is ambiguous. The expected parse of
`foo!!foo` is invalid Swift. Advent's postfix operator scanner may be accepting `!!` or `??`
as a single compound postfix operator, allowing `foo!!foo` to parse without error.

---

## Resolved: C11 — Invalid Backtick-Escaped Identifiers (residual)

**Test cases:**

| Label | Source | Violation |
|-------|--------|-----------|
| `` testEscapedIdentifiers16#1 `` | `` let `+` = 0 ``, `` let `.` = 0 `` | Pure-operator sequence inside backticks |

**Fix (2026-08-04):** Converted `escapedIdentifier` from a raw `/regex/` terminal in
`Swift.apus` to a `@builder` terminal backed by `ApusRegexLibrary.escapedIdentifier` in
`SwiftGrammarRegexLibrary.swift`.

The authoritative rule (from `lexEscapedIdentifier` in swift-syntax's `Cursor.swift`) is:
a backtick identifier is rejected if ALL of its characters form a pure operator sequence
— i.e., the first character is an `isOperatorStartCodePoint` and every subsequent
character is an `isOperatorContinuationCodePoint`.

The fix encodes this with a `NegativeLookahead`:
```swift
NegativeLookahead {
    One(operatorHead)           // first char ∈ isOperatorStartCodePoint
    ZeroOrMore { operatorCharacter }  // all remaining ∈ isOperatorContinuationCodePoint
    "`"
}
```
Both ASCII and Unicode operator ranges are covered via the existing `operatorHead`/
`operatorCharacter` constants (which already back `operatorToken`). A second lookahead
rejects all-whitespace identifiers (permittedRawIdentifierWhitespace). The `validRawIdentifierContent`
class (built from the three new named constants — `unprintableASCII`, `forbiddenRawIdentifierWhitespace`,
`permittedRawIdentifierWhitespace`) replaces the former ad-hoc exclusion list. ✓

*(Null byte and backslash cases fixed — see Resolved: C11 partial above.)*

---

## Parked: C12 — `@available` argument string literal kind

**Test cases:** `testDiagnoseAvailability17a#1`, `testDiagnoseAvailability17b#1`,
`testDiagnoseAvailability20#1`, `testDiagnoseAvailability21#1`

**Root cause:** `@available` attribute arguments are parsed via `balancedTokens`, which accepts
any string literal form. Swift-syntax parses the same input but emits a diagnostic based on the
*kind* of string literal found:

| Test | Diagnostic |
|------|------------|
| 17a/17b | "argument cannot be an **interpolated** string literal" (`"\(...)"`) |
| 20 | "argument cannot be an **extended escaping** string literal" (`#"""..."""#`) |
| 21 | "argument cannot be an **extended escaping** string literal" (`#"..."#`) |

Plain string literals (`"…"`, `"""…"""`) are accepted; only `#`-delimited and `\()`-interpolated
forms are rejected. The check is a property of the *parsed token kind*, not the token stream
shape — a post-parse predicate on `stringLiteralExpression` kind, not a grammar production split.

**Parked:** waiting for the Oracle Filter / Post-Parse Predicate mechanism (see APUS Extension
Candidates §1 below). The predicate would inspect the string literal's token type and prune
the derivation for those two disallowed forms.

---

## Open: C13 — Error Recovery: Miscellaneous

Tests where swift-syntax performs error recovery (`hasError = true`) but Advent accepts cleanly.
Require individual source inspection to determine root cause:

**Still failing:** `testSwitch64#1`, `testSwitch67#1`, `testSelfRebinding2#1`,
`testRegexParseError17#1`, `testConflictMarkers12#1`, `testIfconfigExpr8#1`,
`testIfconfigExpr9#1`, `testIdentifiers6#1`, `testInitDeinit11#1`

**Resolved (2026-08-23 sweep):**
- `testEnum11#1` — a top-level `case` is not a declaration; fixed by
  `declaration = @confinedTo(memberDeclaration) enumCaseDeclaration .` (see
  `Grammar Predicate Lookahead Design.md`). ✓
- `testInvalid17#1`, `testInvalid21#1` — confirmed rejecting. ✓

---

## APUS Extension Candidates

The patterns above suggest two high-value additions to the APUS annotation vocabulary:

### 1. Oracle Filter / Post-Parse Predicate

**Motivation:** B1 (literal trailing closure) and C12 (`@available` string literal kind).
Both restrictions are properties of the *parsed result*, not the token stream — B1 checks
`leadingExpr.isLiteral`; C12 checks `stringLiteral.isInterpolated || stringLiteral.isExtended`.
Encoding either as a grammar production split creates combinatorial duplication. An Oracle-level
hook is the natural home for such post-parse structural predicates.

**Proposed form:** A declarative annotation on a production rule (or a named Oracle rule)
that can inspect the sub-tree of one of the rule's components and prune the derivation if
a predicate fails. General enough to cover any "based-on-what-parsed" disambiguation.

**Reuse:** Any grammar where an alternative is valid only when a sub-expression has a
particular syntactic shape (e.g., lvalue restrictions, callable/non-callable distinctions).

### 2. Structural Lookahead — ✓ DELIVERED (2026-08-23)

**Motivation:** B2 (condition trailing closure). The `atValidTrailingClosure` check fires
at the *end of a sub-parse* (the end of `closureExpression`) and inspects the token that
follows. Existing `>>N` lookaheads anchor on a terminal; `>+>` / `>->` annotations anchored
only on a terminal-use. Neither covered "inspect what follows the close of an embedded
non-terminal."

**Delivered form:** no new syntax was needed — the existing `>+>` / `>->` token-set forward
gate simply became live **after a nonterminal / bracket completion** as well as after a
terminal. The gate is evaluated by one shared helper `MessageParser.forwardGateAllows(slot:at:)`
at the four CRF continuation sites, alongside `continuationViable`. So the proposed
`>>end+>(…)` is spelled with the ordinary gate on a nonterminal-use:
```apus
trailingClosures = closureExpression >-> ("else") labeledTrailingClosures? .
```
This honours the invariant *the Oracle never re-reads input* — a token-set lookahead is a
scanner query and stays at parse time. See `Grammar Predicate Lookahead Design.md` and the
`@within`/`WithinRule` retirement note in `The rise and fall of … dead-ends.md`.

**Reuse:** Any grammar with context-sensitive continuation requirements after a sub-parse —
layout-sensitive languages, operator precedence disambiguation, statement/expression
boundary detection.
