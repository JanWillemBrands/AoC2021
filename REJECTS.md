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
have been **removed** (2026-08-01) in anticipation of a different fix (B2 structural lookahead).
These rules are now bare without the gates. ✓

**Side effect:** Removing the `>->("{")` gate on `while` now causes `testRecovery28#1` to fail
adventRejects — that snippet (`repeat {} while { true }()`) was previously rejected by the gate.
It is now a B2 failure (see below).

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

## Open: B2 — Trailing Closure / Closure Expression in Condition or Subject Position

**Test cases:**

| Label | Source summary |
|-------|---------------|
| `testTrailingClosureInIfCondition#1` | `if test { $0 } {}` |
| `testClosureAtStartOfIfCondition#1` | `if {x}() {}` |
| `testClosureAtStartOfIfCondition#2` | `if { x }() {}` (multiline) |
| `testClosureAtStartOfIfCondition#3` | `if { x\n}() {}` |
| `testClosureAtStartOfIfCondition#4` | `if { a in x + a }(1) {}` |
| `testTrailingClosureInGuard#1` | `guard test { $0 } else {}` |
| `testTrailingClosureInGuard#2` | `guard test { $0\n} else {}` (multiline) |
| `testTrailingClosureInGuard#3` | `guard test { $0\n} else {}` (different split) |
| `testTrailingClosureInGuard#4` | `guard test { x in x\n} else {}` |
| `testRecovery17#1` | `if { true } {}` |
| `testRecovery18#1` | `if { true }() {}` |
| `testRecovery23#1` | `while { true } {}` |
| `testRecovery24#1` | `while { true }() {}` |
| `testRecovery28#1` | `repeat {} while { true }()` |
| `testRecovery50#1` | `switch { 42 } { case _: return }` — closure as switch subject |
| `testRecovery51a#1` | `switch { 42 }() { case _: return }` — called-closure as switch subject |
| `testRecovery51b#1` | (same source, duplicate) |
| Swift.apus fixture | `if [1,2,3].filter { $0 % 2 == 0 }.isEmpty { print("accepts") }` |

**Note:** `testRecovery28#1` was previously Parked (P1) believing Advent rejected it, but
the B3 fix removed the `>->("{")` gate on `while`, exposing that Advent actually accepts
`repeat {} while { true }()`. It is now a confirmed B2 failure.

**Root cause:** The grammar uses `expression` inside `if`/`guard`/`while`/`switch` conditions
without restricting trailing closures. The condition's `{` is ambiguous with the
statement-body `{`, so `if test { $0 } {}` parses as either:
- `if` with condition `test { $0 }` (trailing closure) and body `{}` ← invalid
- `if` with condition `test` and body `{ $0 } {}` ← also invalid

**Swift-syntax equivalent:** `atValidTrailingClosure(flavor: .stmtCondition)` — a
structural lookahead that skips through the content of the `{ }` body and inspects the
token **after** the closing `}`. The trailing closure is accepted only if that token is a
continuation operator on the same line (`.`, `[`, `(`, `?`, `!`, `as`, `is`, `,`).
If the `}` is followed by a newline or `{` (the statement body), the closure is refused.

**Three fix options analysed:**

- **Option A — Negative lookahead `>->`:** Block trailing closure when `}` is followed
  by `{`. Simple, but over-broad: would incorrectly block `f { }.property { }` in a
  condition (continuation tokens after `}` should still allow the closure).

- **Option B — Condition expression non-terminal:** Introduce `conditionExpression` that
  omits `trailingClosures` entirely from function calls. Matches swift-syntax's
  `ExprFlavor.basic`. Slightly over-restricts (disallows `f { }.foo { }` in conditions)
  but structurally clean and requires no lookahead machinery.

- **Option C — Structural lookahead (preferred):** After the closing `}` of a trailing
  closure, assert a continuation token follows on the same line. Faithfully mirrors
  `atValidTrailingClosure`. Requires a new APUS mechanism: a lookahead that can inspect
  the token **following the end of a non-terminal** (here: the end of `closureExpression`
  inside `trailingClosures`). This is precisely the "structural lookahead" APUS extension
  candidate described below.

**Status:** Waiting for the structural-lookahead primitive before committing to an
implementation. Option C is preferred once the primitive exists.

---

## Open: C1 — Key Path Expression Extensions

**Test cases:**

| Label | Source |
|-------|--------|
| `testKeypathExpression#2` | `\String?.!.count.?` |
| `testKeypathExpression#3` | `\Optional.?!?!?!?.??!` |
| `testKeyPathMethodAndInitializers#3` | `\Foo.method<Int>()` |
| `testKeyPathSubscript#1` | `\Foo.Bar.[2].[1]` |
| `testKeyPathSubscript#2` | `\Foo.Bar.?.[1]` |
| `testChainedOptionalUnwrapsWithDot#1` | `\T.?.!` |
| `testChainedOptionalUnwrapsAfterSubscript#1` | `\T.abc[2].?` |

**Root cause:** The `keyPathExpression` grammar allows some but not all of the postfix
operations that Swift accepts inside key paths. Missing: consecutive `?.!` chains, bare
subscript notation `.[n]` (subscript immediately after `.`), optional chain `.?` as a
postfix in key paths, and generic method calls `method<T>()` inside key paths.

**Note:** Test #1 (`testKeypathExpression#1`) and `testKeyPathMethodAndInitializers#1/#2/#4`
are already passing — only the more complex chain forms fail.

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

## Open: C3 — Forward Slash Regex Edge Cases

**Test cases:**

| Label | Source | Issue |
|-------|--------|-------|
| `testLiteralWithTrailingClosure#6` | `_ = /foo/ { return /foo/ }` | Regex literal not in `literalExpression`; B1 exclusion doesn't apply |
| `testForwardSlashRegex116#1` | `_ = qux(/, 1) / 2` + multiline | Regex literal in argument position where `/` would be binary divide |
| `testForwardSlashRegex150a#1` | `_ = ^/"/"` | Custom operator `^/` preceding regex/string |
| `testForwardSlashRegex150b#1` | (same source, duplicate) | Same |
| `testForwardSlashRegex151a#1` | `_ = ^/"[/"` | Same with bracket inside |
| `testForwardSlashRegex151b#1` | (same source, duplicate) | Same |

**Root cause:** Three distinct sub-issues:
1. Regex literals (`/foo/`) are not part of `literalExpression`, so the B1 `nonLiteralPostfix`
   exclusion doesn't catch trailing closures on regex literals.
2. `qux(/, 1) / 2` — the `/` after `qux(` should be a binary-divide in that argument context;
   the scanner is treating it as the start of a regex literal.
3. `^/"/"` — the custom operator `^/` ends with `/`, which then starts a regex or string;
   the scanner needs to recognise that `^/` is a prefix operator and the next token starts fresh.

---

## Open: C4 — Module Selector Invalid Forms

**Test cases:** `testModuleSelectorImports#3`, `testModuleSelectorImports#4`,
`testModuleSelectorIncorrectAttrNames#1`,
`testModuleSelectorIncorrectBindingDecls#7`, `testModuleSelectorIncorrectBindingDecls#8`,
`testModuleSelectorIncorrectBindingDecls#9`,
`testModuleSelectorWhitespace#1`, `testModuleSelectorWhitespace#2`, `testModuleSelectorWhitespace#3`,
`testModuleSelectorAttrs#2`, `testModuleSelectorExpr#1` (11 tests)

**Root cause:** The module selector grammar (`#module(...)` or equivalent) accepts forms
that swift-syntax marks as errors. The exact malformed patterns have not been investigated;
these tests need source-level inspection to categorise the specific rejections required.

---

## Open: C5 — Duplicate / Invalid Access Level Modifier Combinations

**Test cases:** `testAccessLevelModifier#1`, `testAccessLevelModifier#2`

**Source:**
```swift
open open(set) var openProp = 0
public public(set) var publicProp = 0
package package(set) var packageProp = 0
internal internal(set) var internalProp = 0
fileprivate fileprivate(set) var fileprivateProp = 0
private private(set) var privateProp = 0
internal(set) var defaultProp = 0
```

**Root cause:** Swift rejects having both a bare access modifier (e.g., `open`) and the
same modifier with `(set)` on the same declaration (e.g., `open open(set) var`). Advent
accepts this because the grammar allows multiple access-level modifier tokens before a `var`.
The rejection is a semantic constraint, not a purely syntactic one — it requires counting
or deduplicating access-level modifiers in the attribute list.

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

**Fix (2026-08-04):** Added dedicated `attribute` rules in `Swift.apus`:
- `attribute = "@" >s< "abi" >s< "(" abiDeclaration ")" .` — requires exactly one of the 8 `ABIAttributeArgumentsSyntax.Provider` types; empty `@abi()` and bare `@abi` fail.
- Two `@longest` rules for `@attached`/`@freestanding` using `functionCallArgumentList?` — routes keyword `class` through the expression parser, which rejects it.
- General `attribute` rule uses `>->("abi" "attached" "freestanding")` to skip the three names that have dedicated rules.
- Added `abiDeclaration` non-terminal (8 specific declaration types from swift-syntax's `Provider` enum). ✓

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

`testEnum11#1`, `testSwitch64#1`, `testSwitch67#1`, `testSelfRebinding2#1`,
`testRegexParseError17#1`, `testConflictMarkers12#1`, `testIfconfigExpr8#1`,
`testIfconfigExpr9#1`, `testIdentifiers6#1`, `testInitDeinit11#1`,
`testInvalid17#1`, `testInvalid21#1`

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

### 2. Structural Lookahead

**Motivation:** B2 (condition trailing closure). The `atValidTrailingClosure` check fires
at the *end of a sub-parse* (the end of `closureExpression`) and inspects the token that
follows. Existing `>>N` lookaheads anchor on a terminal; `>+>` / `>->` annotations anchor
on the first token of a rule. Neither covers "inspect what follows the close of an embedded
non-terminal."

**Proposed form:** An annotation applicable at a specific position within a rule (e.g.,
after a nonterminal reference) that enforces a token-set constraint on the token
immediately following that nonterminal's extent in the input. Something like:
```
trailingClosures = closureExpression >>end+>(continuationTokens) labeledTrailingClosures? .
```
where `>>end` means "at the position just past the end of the preceding nonterminal."

**Reuse:** Any grammar with context-sensitive continuation requirements after a sub-parse —
layout-sensitive languages, operator precedence disambiguation, statement/expression
boundary detection.
