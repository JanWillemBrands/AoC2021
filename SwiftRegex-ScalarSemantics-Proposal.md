# Draft proposal: run-time Unicode-scalar semantics for `Regex`

Status: draft pitch (for the Swift Forums “String Processing” category / a
`swift-experimental-string-processing` discussion). Not a formal Swift Evolution
document yet.

## Motivation
Swift `Regex` matches in **grapheme-cluster (canonical) semantics** by default. In that
mode, a character-class range whose *bound* is a canonically-decomposing scalar
(e.g. CJK Compatibility Ideographs `U+F900…`) or a variation selector is either rejected
at `init` or — inside a large class — crashes at match time (see
`SwiftRegex-BugReport.md`). This is correct *for grapheme semantics*: `U+F900` is
canonically equivalent to `U+8C48`, so “the scalars between two grapheme-equivalent
bounds” is genuinely ill-defined.

But a large class of clients works at the **Unicode scalar** level, where these ranges are
perfectly well-defined:
- lexer / parser generators building identifier and operator character classes from
  explicit code-point ranges (this project);
- tools translating language specs (C/C++ N1518, Swift’s own `UnicodeScalarExtensions`,
  UAX#31) into runnable matchers;
- anyone porting ICU/PCRE/oniguruma patterns that assume code-point semantics.

Today there is **no way to build such a regex from a string at run time**:
- `Regex(_:).matchingSemantics(.unicodeScalar)` applies *after* init, so the throwing /
  crashing init has already happened.
- The inline flags are parsed but not implemented:
  `try Regex("(?u)…")` → *“unicode scalar semantic mode is not currently supported”*;
  `(?Xu)` → *“grapheme semantic mode is not currently supported.”*

The regex-syntax surface reserves these flags; the engine just doesn’t honor them.

## Proposed solution
Support selecting **Unicode-scalar matching semantics at compile time** for
string-initialized regexes, via either (ideally both) of:

1. **Inline flag** `(?u)` (scalar) / `(?g)` (grapheme), honored by the engine — matching
   the already-reserved syntax. `try Regex("(?u)[\u{F900}-\u{FD3D}]")` then compiles and
   matches on scalars, and range bounds are validated as scalar values (ascending
   `UInt32`), so decomposing scalars and variation selectors are legal bounds.

2. **A throwing initializer parameter**, e.g.
   `Regex(_ pattern: String, semanticLevel: RegexSemanticLevel = .graphemeCluster)`, so the
   semantic level is fixed *before* pattern compilation and bound-validation:
   ```swift
   let re = try Regex(pattern, semanticLevel: .unicodeScalar)
   ```
   This mirrors the existing `RegexBuilder`/`.matchingSemantics(_:)` level but makes it
   effective at `init` for the string API.

Under scalar semantics, a character-class range `a-b` is valid iff `a.value <= b.value`;
canonical equivalence is not consulted, so the current “invalid bound” restriction does
not apply.

## Behavior & compatibility
- **Opt-in only.** Default stays grapheme semantics; no source or behavioral change for
  existing regexes.
- **Well-specified.** Scalar semantics already exists as a `RegexBuilder` option; this
  extends the *string* API and the inline-flag surface to reach it at compile time.
- **Fixes the crash regardless.** Independent of this feature, an invalid bound must throw
  from `init`, never `fatalError` at match (that part is a pure bug — see the bug report).

## Alternatives considered
- *Relax bound validation in grapheme mode.* Rejected: in canonical semantics the range is
  genuinely ambiguous; loosening it would give ill-defined matches.
- *Auto-detect scalar intent.* Rejected: implicit semantics switching is surprising and
  unsound.
- *Client-side workarounds* (split ranges at non-decomposing bounds, substitute `\p{…}`):
  fragile and cannot reproduce arbitrary spec ranges exactly (e.g. N1518 `F900–FD3D` spans
  multiple blocks).

## Scope / effort
Engine work to honor the scalar semantic level during class-bound validation and matching
for the string-compiled path. The syntax and the `RegexSemanticLevel` type already exist;
the gap is wiring compile-time selection through the string initializer and implementing
scalar-mode matching where it is currently stubbed out (“not currently supported”).

## For this project
Even if accepted, this ships in a future toolchain; it is **not** on our critical path. It
would, however, let the faithful explicit-range identifier/operator terminals
(commented in `apus grammars/Swift.apus`) compile as-is, superseding the
`\p{XID_*}`/`\p{Sm}\p{So}` approximations we ship today. Our own code-point-class matcher
(TODO #8) remains the portable, engine-independent long-term answer.
