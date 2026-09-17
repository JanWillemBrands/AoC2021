# This file is the canonical TODO list in this project.

1. **preserving trivia** needs a round-trip test

2. **wider tests on Swift 6.4** test all swift-syntax sources files for equivalence.

3. **Convert the plain-regex body to a `-` lexical recognizer** — ATTEMPTED 2026-09-17, REVERTED TWICE. Do not retry without solving the two blockers below first.

    Baseline was 6 issues. Attempt 1 (whole literal as `-`): **45**. Attempt 2 (body only as `-`):
    **629**. Both reverted; the grammar is back to the `>n<`-gated `=` form.

    **Blocker 1 — `regexSlash >s< regexBody >s< regexSlash` does DOUBLE DUTY.** Beyond pinning the
    body, those two `>s<` are the ONLY thing forbidding a space adjacent to a delimiter. Swift
    rejects `/ x*/`, `/ {}/`, `/ x}*/`; inside a fully tight recognizer there is no trivia for `>s<`
    to test, so the prohibition evaporated and **11 `ForwardSlashRegexSkipping*` reject fixtures
    started passing as valid**. Any retry must re-express "no space adjacent to a delimiter" as a
    STRUCTURAL rule of the body, not a trivia predicate. (Attempt 1 also regressed the newline fix
    itself — `testPrefixSlash4` / `testForwardSlashRegexSkippingAllowed11` came back — because
    moving the literal out of main-parse prediction changes what the
    `@preempt(regexSlash, …)` / `@cannotParse(regularExpressionLiteral)` machinery can see.)

    **Blocker 2 — tightness does NOT propagate through `=` nonterminals.**
    `markRecognizerBodySuppressesLeadingTrivia` (`ApusParser.swift:336`) sets
    `suppressesLeadingTrivia` only on terminals reached directly, and stops at a nonterminal
    boundary by design (`ApusParser.swift:354`: "a structured recognizer may call a normal `=`
    payload, whose terminals keep normal leading-trivia skipping"). So `regexBody - regexItem {…}`
    is tight for nothing — `regexItem` is a `=` nonterminal and its terminals keep skipping trivia.
    That is what produced 629. A viable conversion must inline the whole body into the recognizer's
    own production, or teach the marker to descend through `=` nonterminals reachable only from a
    recognizer (a grammar-load change, and a sharp edge for shared nonterminals).

    Coverage was added and is the durable win: `regexLookbehindSnippets` now has interior-space rows
    plus a `treesMatch` test in `RegexLookbehindIntegration`, so the bug below is recorded instead of
    invisible. Six rows carry a `gapReason` pointing here; `regex-escaped-space` is the passing
    control. That new `treesMatch` also surfaced a pre-existing converter gap on
    `regex-after-try-bang` (accepts fine, tree differs), likewise now recorded.

    **Original motivation (unchanged, still worth fixing):**

    `regexBody` / `regexGroup` / `regexCharacterClass` and their
    `tryScanOperatorAsRegexLiteral*` mirrors now carry a `>n<` at every intra-body junction
    (added 2026-09-17 to fix `testPrefixSlash4` / `testForwardSlashRegexSkippingAllowed11`:
    the body is a TOKEN sequence, so the lexer was skipping a newline *inside* the literal and
    `/E.e⏎(/` lexed as one regex literal). That is correct but the gates are scattered — add an
    alternative to `regexItem`, or a new `regexX` rule with its own concatenation, and you must
    remember the gate.

    The real fix is to declare the literal with `-` instead of `=`: `ApusParser.swift:281`
    (`isLexical = token.kind == "-"`) routes a structured `-` body through
    `markRecognizerBodySuppressesLeadingTrivia`, which sets `suppressesLeadingTrivia` on every
    terminal in the body — so **no trivia is skipped inside at all** and the `>n<`/`>s<` gates
    become unnecessary rather than merely centralised. `regexSpaceAtom` then becomes load-bearing
    again, which is what the surrounding comments always assumed, and it matches swift-syntax,
    where `RegexLiteralLexer` emits the literal as a single token.

    Both "costs" were investigated 2026-09-17. **(a) is not a cost — it is the reason to do this,
    and it fixes a live bug. (b) is real, and is a silent-vacuous-predicate trap.**

    **(a) The converter never wanted the internal structure, and losing it FIXES a bug.**
    `convertLiteral` (`GenerateSwiftSyntaxAST.swift:7527`) treats the literal as opaque: it takes
    `collectTerminalText` over the `regularExpressionLiteral` span, strips the slashes and emits one
    `regexLiteralPattern` — exactly swift-syntax's shape. It never looks at `regexBody`/`regexItem`.

    But `collectTerminalText` → `tiledText` reconstructs the text by **concatenating committed
    terminals**, so any interior character absorbed as TRIVIA is silently dropped. Because
    `regexSpaceAtom` is never actually matched (spaces are always skipped as trivia first), *every
    space inside a bare regex literal is lost from the emitted pattern*. Measured:

    | source | round-trips as | `treesMatch` |
    |---|---|---|
    | `_ = /foo/` | `/foo/` | ✅ (control) |
    | `_ = /a+b/` | `/a+b/` | ✅ (control) |
    | `_ = /a b/` | `/ab/` | ❌ |
    | `_ = /a  b/` | `/ab/` | ❌ |
    | `_ = /a b c/` | `/abc/` | ❌ |
    | `_ = /(a  b)/` | `/(ab)/` | ❌ |

    So `/a b/` currently generates a regex that means something *different*. The corpus has ZERO
    fixtures with an interior space, which is why it has never shown up — **add some**. A `-`
    recognizer strips no trivia (`MessageParser.swift:331`: "The sub-parser strips no trivia
    (isSubParser), so the body is matched character-tight — right for whitespace-sensitive
    constructs like regex" — regex is the named use case), so `regexSpaceAtom` finally matches and
    the text is exact. Corollary: `regexBody = regexItem { regexSpaceAtom? regexItem }` allows only
    ONE space between items, so it must become `regexSpaceAtom*` (or the terminal `/[ \t]+/`) or
    `/a  b/` will start being REJECTED instead of mistranslated.

    Separately, Advent accepts `_ = /a<TAB>b/`, which swift-syntax rejects (`hasError == true`).
    Small reject gap, same area.

    **(b) The opener gates MUST move out of the recognizer body — inside it they read as
    vacuously true.** A recognizer runs as a fresh `MessageParser` (`MessageParser.swift:336-341`)
    with its own empty commit log. `<-<` resolves through `previousKindIDs` →
    `terminalKindIDs(endingAt:)` → `commitsByEnd` (`MessageParser.swift:117`), so at the sub-parse's
    start position it finds nothing, `matches == false`, and a NEGATIVE lookbehind returns `!false`
    = **true**. `>n<` degrades the same way: `boundaryMatches` finds no commit at the position and
    falls back to *departing* trivia, which at an opening `/` is empty → also true. The gate that
    stops `/` stealing division would disappear **silently**. Same failure class as item 14.

    The fix is easy and leaves the grammar simpler than today: the two alternates exist ONLY to
    carry the two opener gates, so move the gates to the referring production, where the outer
    parse's commit log is visible, and the recognizer body collapses to one alternate:

    ```
    plainRegularExpressionLiteral - regexSlash regexBody regexSlash .      // one alternate, tight
    regularExpressionLiteral = >n< <-< ( … ) plainRegularExpressionLiteral .
    regularExpressionLiteral = <n> plainRegularExpressionLiteral .
    ```

    The interior `>s<`/`>n<` gates all become unnecessary (nothing can be skipped), which is the
    point of the exercise. Note `Grammar.swift:418` requires a structured lexical terminal to be
    DEFINED BEFORE USE, which the current file order already satisfies.

    **Pre-existing bug found while checking (b): `tryScanOperatorAsRegexLiteral`'s opener gates are
    ALREADY dead.** It is the target of `@preempt(regexSlash, tryScanOperatorAsRegexLiteral)`, and
    `@preempt` viability also runs as a fresh sub-parse (`MessageParser.swift:359`), so its leading
    `>n< <-< ( … )` has been vacuously true all along. Currently masked — the live gates on
    `plainRegularExpressionLiteral` in the main parse carry the load and the "Regex Lookbehind"
    suite is green — but it is a real dead predicate. Fix it the same way: gate at the reference,
    not inside the recognizer. Worth a regression test that fails if the gate is removed.

    **`@sameLine` is NOT an alternative here** (evaluated and rejected 2026-09-17). It is an
    Oracle rule, so the bad yield is built and pruned *afterwards* — but `@cannotParse` snapshots
    the RAW forest at Oracle registration (`Oracle.swift:183-188`: "a target that lexes/parses but
    whose enclosing parse fails still counts"), so `@cannotParse(regularExpressionLiteral)` would
    still see the cross-newline literal and still prune the correct prefix-`/` reading. `@preempt`
    is scanner-time, earlier still. And `registerSameLine` asserts a single-alternate nonterminal,
    which `plainRegularExpressionLiteral` is not. Only a parse-time gate works.

## Maintenance Rule

- Add new markdown TODOs here and link back to source context when needed.
- `Advent/codex.md` and `Advent/claude.md` should reference this file instead of maintaining separate TODO lists.
