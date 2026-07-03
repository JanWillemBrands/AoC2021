# Bug report: recoverable char-class-range compile error becomes an uncatchable match-time `fatalError` (lazy compilation `try!`)

## Summary
`Regex(_ pattern: String)` **parses** the pattern but **defers program lowering to first
match**. Lowering can throw a recoverable `RegexCompilationError`
(`invalidCharacterClassRangeOperand`) — e.g. for a character-class range whose bound is a
canonically-decomposing scalar (a CJK Compatibility Ideograph like `U+F900`) or a
variation selector, which fail the `singleScalar && isNFC` check under grapheme semantics.
Because lowering is deferred and then force-unwrapped with **`try!`** in
`Regex.loweredProgram`, that recoverable error does **not** surface from `try Regex(...)`;
it instead aborts the process at first match:

```
Fatal error: 'try!' expression unexpectedly raised an error:
'…' is an invalid bound for character class range   (_StringProcessing/Regex/Core.swift)
```

Two observable symptoms:
1. **Uncatchable match-time crash.** A `Regex` that `try Regex(...)` accepted crashes at
   first use. Client code cannot defend against it — it is a `fatalError`, not a thrown
   Swift error.
2. **Inconsistent reporting.** The *same* bad bound is reported as a thrown error at `init`
   in a small character class (surfaces eagerly), but slips past `init` and crashes at
   match when embedded in a large multi-range class (surfaces via the deferred `try!`).

The underlying `isNFC` restriction is itself *defensible* for grapheme semantics (a range
starting at a canonically-decomposing scalar is genuinely ambiguous). The bug is that a
**recoverable** compilation error is turned into a crash by the lazy-compile `try!`.

Separately (motivating context, not the crash): there is **no run-time escape hatch** to
compile in Unicode-scalar semantics, where these ranges are well-defined — the inline flags
are parsed but rejected (see “Related”).

## Environment
- Swift toolchain: <FILL IN — output of `swift --version`>
- Platform: macOS <FILL IN — `sw_vers`>
- `swift-experimental-string-processing`: version bundled with the above toolchain.

## Reproducer A — throws at init (minimal, expected-ish but see note)
```swift
import Foundation
do { _ = try Regex("[\u{F900}-\u{FD3D}]") }
catch { print(error) }   // -> invalid bound for character class range
```
`U+F900` (CJK COMPATIBILITY IDEOGRAPH-F900) has a canonical decomposition, so as a range
*bound* under canonical-equivalence semantics it is arguably ill-defined. Throwing is
defensible — but see Reproducer B for the inconsistency and the crash.

## Reproducer B — compiles, then `fatalError` at match (the actual bug)
The **same kind of bound**, placed inside a large multi-range class (here the C/C++ N1518
identifier set used by SwiftParser’s `isValidIdentifierContinuationCodePoint`), is
**accepted by `Regex.init`** and then **crashes at match time**:

```swift
import Foundation
// The full identifier character class (≈90 ranges). Abridged here; the crash also
// reproduces with the Mongolian free variation selectors alone inside a large class,
// e.g. a class containing  \u{1681}-\u{180D}  among many other ranges.
let cls = "[A-Za-z_…\u{F900}-\u{FD3D}…\u{FE47}-\u{FFF8}…]"   // see full string below
let re = try! Regex(cls)          // <- does NOT throw
_ = try? re.firstMatch(in: "abc") // <- process aborts (lazy compile forced via try!):
// Fatal error: 'try!' expression unexpectedly raised an error:
// '…' is an invalid bound for character class range
//   _StringProcessing/Regex/Core.swift  (loweredProgram)
```

Observed: `try Regex(cls)` returns a value; the first match attempt aborts with the fatal
error above. Note the inconsistency — extract `[\u{F900}-\u{FD3D}]` on its own and init
throws; leave it in the big class and init succeeds but match crashes.

Full character-class string that reproduces the crash: see
`apus grammars/Swift.apus` (the commented-out `rawIdentifier` explicit-range alternative),
or reconstruct from N1518 Annex X.1 ranges.

## Root cause (source-verified against `main`)
The crash is a **recoverable compilation error forced through `try!` because lowering is
lazy**:

1. **Parse only at init.** `Regex(_ pattern: String)` parses to an AST; it does not lower
   to a program. So `try Regex("[…]")` succeeds even with a bad range bound.
2. **Deferred lowering, force-tried.** `Regex.loweredProgram`
   (`Sources/_StringProcessing/Regex/Core.swift`) compiles on first use and force-unwraps:
   ```swift
   let compiledProgram = try! Compiler(
     tree: list, compileOptions: compileOptions).emit()
   ```
3. **The throw.** `Compiler.emit()` → `ByteCodeGen.emitCustomCharacterClass` → the `.range`
   member calls `generateConsumer(_:)` in `Sources/_StringProcessing/ConsumerInterface.swift`:
   ```swift
   guard let lhs = lhsChar.singleScalar, lhs.isNFC else {
     throw RegexCompilationError.invalidCharacterClassRangeOperand(lhsChar)
   }
   ```
   `U+F900` decomposes canonically (→ `U+8C48`), so `isNFC == false` → it throws. (Same for
   the Mongolian variation selectors.)
4. **Throw → crash.** That recoverable throw hits the `try!` in step 2. `RegexCompilationError`’s
   description is exactly `"'\(c)' is an invalid bound for character class range"`, matching
   the fatal text.

The small-vs-large inconsistency is the same validation surfacing on two paths: eagerly (a
thrown error at `init`) for the isolated single-range class, vs deferred (the `try!` in
`loweredProgram`) for the large class.

## Expected behavior / suggested fix
- **`loweredProgram` must not `try!` a compilation that can legitimately fail.** Either
  compile eagerly inside the throwing `Regex.init(_:)`, or cache the `RegexCompilationError`
  and rethrow it from the throwing entry points — so an invalid pattern is **always** a
  thrown error and **never** a match-time `fatalError`.
- **Consistency:** with the above, an invalid range bound is reported identically regardless
  of how many other ranges share the class.
- Ideally, also provide a supported way to compile such ranges in **Unicode-scalar
  semantics** (see Related), where these bounds are well-defined.

## Related (not strictly part of this bug, but the motivating need)
Inline semantic-mode flags are recognized by the parser but rejected by the engine:
```swift
_ = try Regex("(?u)[\u{F900}-\u{FD3D}]")   // error: "unicode scalar semantic mode is not currently supported"
_ = try Regex("(?Xu)[\u{F900}-\u{FD3D}]")  // error: "grapheme semantic mode is not currently supported"
```
There is no `Regex(_:).matchingSemantics(.unicodeScalar)` equivalent that takes effect at
*init*, so a string-built regex cannot opt into scalar semantics — the setting only applies
after the (already-throwing/crashing) init.

## Impact
Parser/lexer generators and tools that build character classes from explicit Unicode
code-point ranges (identifier/operator sets, Unicode property expansions) at run time can
neither express these ranges nor guard against the crash.

---

## How to file this

1. **Confirm versions** — fill in the Environment section:
   - `swift --version`
   - `sw_vers` (macOS) or your OS/toolchain
2. **Repo:** file at **https://github.com/swiftlang/swift-experimental-string-processing/issues**
   (this is the implementation of Swift’s `Regex`; it was previously
   `apple/swift-experimental-string-processing`). Search existing issues first for
   “invalid bound for character class range” / “unicode scalar semantic mode”.
3. **Title:** `Lazy Regex compilation turns a recoverable char-class-range error into an uncatchable match-time fatalError (try! in loweredProgram)`
4. **Body:** paste this file’s Summary → Environment → Reproducers → Expected → Related.
   Attach a self-contained `main.swift` (Reproducer A is enough to file; include B to show
   the crash).
5. **Optionally cross-post** a short heads-up in the Swift Forums “Related Projects →
   String Processing” category linking the issue, especially if you also want to raise the
   run-time scalar-semantics gap (see `SwiftRegex-ScalarSemantics-Proposal.md`).
6. **Labels:** leave for maintainers; mentioning “crash”/“fatalError” in the title helps
   triage.
