# Testing

How the Advent / APUS GLL parser is tested, how to run the suites, how to read
their (sometimes misleading) output, and the pitfalls that have cost real time.

This doc consolidates hard-won workflow knowledge. When you change any of it,
update this file — it is meant to be the single home for "how we test."

---

## 1. Test harnesses (and which one is the source of truth)

There are **two** ways a Swift snippet gets fed to the grammar. They disagree on
identical input, and only one is authoritative.

### 1a. SwiftSyntax Swift Testing suites — THE SOURCE OF TRUTH

`AdventTests/SwiftSyntax*.swift` — parametrized `swift-testing` suites over
`SwiftSnippet` arrays, driven through `adventParse` →
`runAdventOnce` → the shared `cachedSwiftGrammar`. The snippet source is the
byte-exact `SwiftSnippet.source` (a Swift `"""…"""` literal, so the compiler has
already unescaped it).

Suites (one `@Suite` each, struct in parens):

| File | Suite struct | Origin | ~count |
|------|--------------|--------|--------|
| `SwiftSyntaxDeclarations.swift` | `DeclarationSyntaxTests` | DeclarationTests | 173 |
| `SwiftSyntaxExpressions.swift` | `ExpressionSyntaxTests` | ExpressionTests | 184 |
| `SwiftSyntaxStatements.swift` | `StatementSyntaxTests` | StatementTests | 52 |
| `SwiftSyntaxTypes.swift` | `TypeSyntaxTests` | TypeTests | 71 |
| `SwiftSyntaxPatterns.swift` | `PatternSyntaxTests` | PatternTests | 6 |
| `SwiftSyntaxAttributes.swift` | `AttributeSyntaxTests` | AttributeTests | 104 |
| `SwiftSyntaxTranslated.swift` | `TranslatedSyntaxTests` | 79 translated files | 1263 |
| `SwiftSyntaxTests.swift` | shared infra (`SwiftSnippet`, `adventParse`, `ParserProbe`) | — | — |

### 1b. `^^^` messages in `Swift.apus` — NOT a truth signal

`Swift.apus` embeds ~840 snippets as `^^^ … ^^^` blocks, parsed by
`main.swift` and by `LanguageGrammarTests / SwiftGrammar / parseMessagesSequentially`
(→ `parseLanguageMessage`). **Do not use this path to judge whether Advent accepts
a snippet.** It is retained only because `main.swift` and `harvest_ambiguity.py`
still drive off it.

**Why they disagree (this has caused weeks of phantom debugging, twice):**
1. `^^^` blocks re-add leading/trailing whitespace that single-line `"""` sources
   don't have, and are stored **escaped** (`\"`, `\n`, `\t`) — see the escaping bug
   in §7.
2. `parseLanguageMessage` checks only `parser.currentParseRoot` with a **strict
   `j == endIndex`**; `adventParse` requires a `grammar.root` yield via `buildAST`
   with **EOS-trivia tolerance**. Different root + different criterion.

Concrete: `func square(_ x: Int) -> Int { return x*x }` "passes" the `^^^` path but
genuinely **fails** `adventParse`. Conversely (2026-07-28) the four top-level
bodiless-func snippets (`@objc(_:)⏎func f(_: Int)`, `@abi(func fn()) func fn()`, …)
**pass** as `^^^` messages — because that path checks acceptance only — while the
Swift Testing cases still show red, because they *also* run `treesMatch`
(the acceptance is fine; the tree comparison is the frontier — see §7).

**Rule of thumb:** "passes as a message but fails as a test case" almost always
means *acceptance passes, `treesMatch` fails*. Check the `@Test` name before
concluding anything is broken.

---

## 2. The four `@Test`s per suite — what each one signals

Each SwiftSyntax suite runs the same snippet array through four checks. They are
NOT equal in authority:

| `@Test` | Question | Authority |
|--------|----------|-----------|
| **`swiftSyntaxAccepts`** | does swift-syntax `Parser.parse(source:).hasError == false`? | baseline — confirms the snippet is valid input |
| **`Advent accepts`** | does the grammar produce a full-span root yield? | **correctness signal** — a failure is a real accept regression |
| **`no residual ambiguity`** | after the Oracle, is the parse unambiguous? | **correctness signal** — a failure is a real ambiguity |
| **`trees match`** | does Advent's derivation dump byte-match swift-syntax's tree dump? | **aspirational frontier** — most failures here are expected, not regressions |

`accepts` is computed **pre-Oracle** (raw yields), so Oracle rules like
`@longest`/`@prefer` cannot cause an accept failure. `unambiguous` and `treesMatch`
are post-Oracle.

**`treesMatch` is the current frontier.** ~1660 of the Translated cases fail it —
that is the baseline, not a regression. When triaging a run, always split issues by
`@Test`: only `accepts` / `no residual ambiguity` failures are actionable
correctness signals. A `treesMatch` count that is *stable vs baseline* means "no
regression" even though the run is red.

---

## 3. Running the suites

Grammars (`*.apus`) are read at runtime via `#filePath`, so **Xcode's build system
does not treat a grammar edit as a changed input.** Consequences:
- A `.apus`-only change needs no recompile — the next test run picks it up.
- But MCP `RunSomeTests` "smart re-run" then thinks nothing changed and re-runs only
  previously-failing args (§7).

### Authoritative full sweep — use `xcodebuild` directly

```bash
SWIFT_DETERMINISTIC_HASHING=1 xcodebuild test \
  -scheme Advent -destination 'platform=macOS,arch=arm64' \
  -only-testing:AdventTests/ExpressionSyntaxTests \
  -only-testing:AdventTests/DeclarationSyntaxTests \
  … > /tmp/run.log 2>&1
```

Triage the log by `@Test` name (this is the single most useful command):

```bash
grep -aoE 'Test "[^"]+" recorded an issue' /tmp/run.log | sort | uniq -c
# e.g.  1662 Test "trees match" recorded an issue   ← frontier, fine
#          0 accepts / ambiguity                    ← what you actually care about
```

To see which snippets fail a given test:
```bash
grep -aE '"(Advent accepts|no residual ambiguity)".*snippet → ' /tmp/run.log \
  | grep -aoE 'snippet → [^ ]+' | sort -u
```

### Iterating on the grammar — use the probe

For fast single-snippet iteration use the non-parametric `SwiftSyntaxTests / ParserProbe`
`@Test` calling `adventParse` on exact strings: `RunSomeTests` runs one test
reliably (no smart-rerun collapse, no truncation), and `.apus` edits need no rebuild.

### `SWIFT_DETERMINISTIC_HASHING=1` — always set it

Set it on every test run. It forces `Dictionary`/`Set` iteration to a fixed seed,
which is what turns order-dependent flakes into deterministic pass/fail (see the
dollar-closure story in §7). `xcodebuild` forwards it into the test runner; if you
launch the runner yourself, forward it with the `TEST_RUNNER_` prefix.

---

## 4. Reading output — the traps

### `main.swift` / CLI logs are invisible on stdout

`Logger.*` (OSLog) messages go to the unified log, **not** stdout/stderr. Worse, the
console app's logs are effectively **not captured** at all when run headless — a
grammar-load failure exits `1` with **completely empty stdout** (all diagnostics
went to `Logger.ui.error` then `exit(1)`). Don't assume "no output" means "no run."

Read OSLog explicitly (note: full path `/usr/bin/log` — zsh has a `log` builtin):
```bash
/usr/bin/log show --last 30s --info --debug --no-pager \
  --predicate 's="com.magenta.apusParser"' 2>&1 | head -100
```
Subsystem `com.magenta.apusParser`; categories `ui`/`scan`/`parse`/`grammar`/`generate`.
OSLog **redacts** `\(interpolated)` values as `<private>` outside the debugger — for
content, temporarily `fputs(…, stderr)` or read them in Xcode's console.

### Probe swift-syntax truth with `hasError`, not `swiftc`

Ground truth for "is this valid Swift?" is swift-syntax
`Parser.parse(source:).hasError` (what `swiftSyntaxAccepts` uses). `swiftc -parse`
is a *different* parser and diverges on trivia (it accepts `@available (*)`,
`nonisolated ()->` with a space, that `hasError` rejects). To probe fast, add a temp
`@Test` in `SwiftSyntaxTests.ParserProbe`, `print("PROBE …")`, run with
`RunSomeTests`, grep `PROBE`, remove it. (`RunCodeSnippet` needs `-Onone`; the main
target is `-O`.)

---

## 5. Parallel execution (2026-07-27)

The SwiftSyntax comparison suites run **in parallel**. This is safe because the
parser was made reentrant:

- **Shared immutable grammar.** `cachedSwiftGrammar` loads `Swift.apus` **once**
  (lazy `let`, thread-safe init) and shares it; it is load-time immutable
  (yields moved off `GrammarNode` into `MessageParser.yields[node.number]`).
- **Per-parse instances, no static state.** `MessageParser`, `Grammar`, `Scanner`,
  `CallReturnForest`, `Descriptor`, BSR carry **no** `static var`. Each parse builds
  its own `MessageParser`.
- **Per-source memoization.** `parseCache` parses each unique source once; the three
  post-parse `@Test`s share that result.

### What had to change to go parallel
1. **`ebnfDot()`/`emit()` made static-free** (GrammarNode.swift). They used four
   process-global statics (`dottedEBNF`/`dottedSlot`/`containingNonterminal`/
   `toplevelAlternate`) as recursion scratch — a data race in diagnostics. State is
   now threaded as `inout`/params.
2. **Dropped the global lock from the hot path.** `withParserIsolation`
   (an `NSRecursiveLock` in `TestInfrastructure.swift`) previously serialized *every*
   parse. It was removed from `runAdventOnce` (which uses the pre-built cached grammar
   and touches no statics). It is **kept** around the small-grammar helpers
   (`parseMatches`/`parseGrammar`/`loadGrammarFile`, and Performance/ParserGenerator/
   SpecialToken suites) which *build* grammars and touch `GrammarNode.sizeofSets`.
3. **Un-`.serialized`ed the 7 SwiftSyntax comparison suites** so their parametrized
   cases (e.g. the 1263-case `treesMatch`) fan out across cores. The grammar-building
   suites stay `.serialized`.
4. **Gated the baseline CSV.** `runAdventOnce` only writes `baseline-phase0.csv` when
   `APUS_BASELINE_CSV=1` — otherwise parallel row order churns that tracked file.

### Results / verification
- Test-run phase **~43s → ~16s** on the 7 suites (~2.6×); `user ≈ 2×real` confirms
  real multicore use. Wall time is now dominated by the build (see §7 stale builds).
- **Deterministic:** identical issue counts and identical failing snippets across
  repeated `SWIFT_DETERMINISTIC_HASHING=1` runs.
- **ThreadSanitizer: 0 data-race warnings** on a high-concurrency subset
  (`-enableThreadSanitizer YES` on Expressions+Attributes). TSan exits non-zero
  simply because `treesMatch` fails — that is not a race; grep for
  `WARNING: ThreadSanitizer`.

---

## 6. The test corpus / extraction pipeline

Snippets are extracted from the `swift-syntax` repo (tag must match the dependency,
currently **603.0.1**) by `tools/extract_snippets.py`:
1. Parse `assertParse(...)` calls; **skip** those with a `diagnostics:` arg
   (error-recovery tests).
2. Strip diagnostic markers (1️⃣, ℹ️).
3. Tag `@_`-underscored attributes → `disabledReason: "underscore attribute"`.
4. Emit `SwiftSnippet` arrays.

`disabledReason` values: `"underscore attribute"`, `"experimental feature"`
(features swift-syntax 603.0.1 itself rejects), `"compiler error — <ref>"`
(cases where Advent deliberately follows the **compiler**, which is stricter than
swift-syntax's permissive parser — see the acceptance-policy note in `TODO.md`).

**Limitation:** the script can't expand `assertParse` sources that use string
interpolation with loop variables — expand those into concrete snippets by hand.

**On a swift-syntax version bump:** re-download test files, re-run the extractor with
the new version string, diff against existing snippet files, and re-check the
experimental-feature disables (features may have graduated).

---

## 7. Known problems, gotchas & stale-test hazards

- **Stale binaries / stale builds.** Never run a DerivedData binary without a fresh
  build first — old products persist indefinitely (once burned an afternoon on an
  April Release binary with a *different* grammar). And note: editing a core `.swift`
  (e.g. `GrammarNode.swift`) forces a **full** rebuild of the giant test files, so a
  post-edit run's *wall time* is build-dominated and not comparable to a
  grammar-only run.

- **`^^^` fixtures are stored escaped.** The `^^^` blocks contain literal `\"`,`\n`,
  `\t`. `harvest_ambiguity.py` **unescapes** before running; `loadLanguageFixture`
  and `accept_dump.py` do **not** → they feed malformed Swift → **false rejections**.
  The `LanguageGrammarTests / SwiftGrammar` "104 issues" baseline is exactly this
  artifact, **not** a grammar bug. Don't chase it.

- **Message-path vs test-path (see §1b).** "Passes as a message, fails as a test" =
  acceptance passes, `treesMatch` fails. Always split by `@Test`.

- **MCP `RunSomeTests` smart re-run — stale across sessions.** The re-run cache
  is process-level and **persists across conversation context resets**. After a
  long pause or context compaction, the cache may still point to a stale set of
  failing args from a completely different grammar state — typically resolving to a
  single test case (e.g. `testEnum17f#1`) that has nothing to do with the current
  work. Symptom: `RunSomeTests` runs 0 or 1 tests and returns a misleadingly
  small result. Fix: use `RunAllTests` for a definitive full sweep, or run the
  specific suite directly. Do **not** diagnose grammar health from a smart-rerun result.

- **MCP `RunAllTests` — "failed" count is not the grammar-failure count.**
  `RunAllTests` reports a `failed` total (e.g. 122) that **includes both grammar
  failures AND parallel-execution crashes**. The crash failures
  (`Crash: xctest at <deduplicated_symbol>`) are pre-existing noise from the
  parallel test runner — they are NOT grammar regressions. A crash count of
  100+ is normal and expected. The actual grammar-failure count (tests where
  the parser made a wrong decision) is obtained by grepping the console log:
  ```bash
  # Reject-suite grammar failures (parser wrongly accepted invalid input):
  grep -c "Advent wrongly accepted" "$full_console_log"

  # Accept-suite grammar failures (parser wrongly rejected valid input):
  grep -c "Advent wrongly rejected" "$full_console_log"
  ```
  Both counts are typically 0-100; a crash-inflated "122 failed" with
  0 "wrongly accepted" means the grammar is passing and the failures are all crashes.

  MCP `RunAllTests` also **truncates** the JSON results to 100 entries — read
  the `fullSummaryPath` file (all 1186+ results in the same key=value format)
  and grep it by `TEST_STATE`, `TEST_IDENTIFIER`, or `TEST_DISPLAY_NAME`.

- **`treesMatch` is red by design.** ~1660 Translated cases fail it. Track the count
  vs baseline; a *stable* count = no regression.

- **Load-time non-confluence → per-process flakes.** The old
  `testClosureWithDollarIdentifier#1/#2` "flake" (~50%) was NOT a parser race — it
  was a **non-confluent exclude-set fixpoint at grammar load**
  (`Grammar.propagateExcludeSets` used a `formUnion` *least* fixpoint for
  intersection semantics; the result depended on hash-seeded `Dictionary` order).
  Because the grammar is loaded once and **cached/shared**, the wrong-or-right set was
  baked in per process → looked flaky. Fixed as a **greatest** fixpoint (start at TOP,
  shrink by intersection). **Lesson:** a shared cached grammar makes *any* load-time
  order-dependence a per-process flake — audit load-time set computations for
  order-independence, and pin flakes with `SWIFT_DETERMINISTIC_HASHING=1`, then diff
  descriptors/yields between a PASS and a FAIL run.

---

## 8. Debugging workflow (grammar vs swift-syntax failures)

1. **Fix by root cause, not by test.** Cluster failures by shared cause (same as the
   ambiguity-signature workflow) — one grammar change usually clears a whole cluster.
2. **Probe swift-syntax truth (`hasError`) before every faithfulness claim** (§4).
3. **Prefer structural grammar fixes over `@prefer`/oracle hacks** — only `.apus`
   declarations, no custom Swift disambiguation. `@prefer` is single-level (no 3-way
   priority) and can create *new* ambiguities; re-harvest after.
4. **Measure with the right yardstick.** `Advent accepts` (decoded `source`) is ground
   truth for acceptance; `harvest_ambiguity.py ALL` for ambiguity. The `^^^` /
   `accept_dump.py` paths are unreliable (escaping).
5. **After every change:** re-harvest (ambiguity unchanged or down) **and** run the
   affected suite (no acceptance regression).
6. **Distinguish "compiler-invalid but swift-syntax-permissive."** Many disabled
   snippets are cases where Advent correctly follows the *compiler* and rejects —
   those are policy, not gaps (see `TODO.md` acceptance-policy note).

---

*Testing improvement options live in `TODO.md` under "Testing infrastructure & speed."*

---

## 9. Efficient testing workflow — recommendations

### Tier 1: single-snippet iteration (fastest, seconds)

Use `SwiftSyntaxTests / ParserProbe` with a temporary inline `adventParse` call.
`RunSomeTests` runs it instantly with no smart-rerun collapse (it is not
parametrized). Best for: confirming a single snippet accepts/rejects before
touching the grammar.

### Tier 2: targeted suite run (seconds to ~1 min)

Use `RunSomeTests` on a single suite (e.g. `RejectSyntaxTests/adventRejects(_:)`)
**immediately after** starting a fresh session (or after verifying the smart-rerun
cache is pointing at the right suite). Best for: confirming that a specific
category of failing tests passes after a fix. **Do not trust this after a session
reset without checking which test case it intends to run** (smart-rerun caveat above).

### Tier 3: reject-count sweep (the real correctness signal)

The definitive metric for "how many snippets does Advent wrongly accept?" is
a `RunAllTests` followed by a grep:
```bash
grep -c "Advent wrongly accepted" "$full_console_log"
```
This number is **immune to crash-count noise**. Run it:
- Before starting a new fix (establish baseline)
- After applying a fix (confirm it went down)
- Before closing a session (record final count in `REJECTS.md`)

Use `xcodebuild` (§3) for the authoritative command-line equivalent.

### Tier 4: full regression check (5–10 min)

Run `RunAllTests` (or `xcodebuild test`) targeting all suites. Then check:
1. `grep -c "Advent wrongly accepted"` — should be ≤ baseline
2. `grep -c "Advent wrongly rejected"` — must be 0 (no accept regressions)
3. Crash count in the `failed` total is expected to be 50–150 (pre-existing parallel noise)

The `treesMatch` suite failure count (~1660 baseline) is separately tracked and
not a correctness signal by itself.

### Interpreting a `RunAllTests` result quickly

| Observation | Meaning |
|-------------|---------|
| `failed` jumps by 20–40 with all-crash error messages | Pre-existing parallel noise, not a regression |
| `grep "wrongly accepted" log` goes up | Real regression — a previously-rejected snippet now accepts |
| `grep "wrongly rejected" log` > 0 | Accept regression — fix narrowed the grammar too much |
| `testEscapedIdentifiers16#1` STATE: Passed in `fullSummaryPath` | C11 fix is live |
| `fullSummaryPath` missing a test you expect | The test ran in a process that crashed — not a grammar signal |
