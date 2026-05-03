# Scanner Mode Design

## Goal

A clean, general scanner-mode model for Apus based on well-understood theory (Flex start conditions, ANTLR lexer modes). Supports nested and context-sensitive token constructs (Python f-strings, C++ raw strings, Swift multiline comments, JS template literals) while preserving the pre-scan + GLL architecture.

## Theoretical Foundation

Scanner modes are a well-established mechanism in lexer generators. The key references:

- **Flex start conditions** — each rule is tagged with states it's active in. `BEGIN(state)` switches state after a match. Inclusive vs exclusive modes. Flat state (no stack). [Flex manual: Start Conditions](https://westes.github.io/flex/manual/Start-Conditions.html)
- **ANTLR lexer modes** — stack-based modes with `pushMode`/`popMode`/`mode` commands. Each rule belongs to exactly one mode. [ANTLR Lexer Rules](https://github.com/antlr/antlr4/blob/dev/doc/lexer-rules.md)
- **Van Wyk context-aware scanning** — parser passes valid token set to scanner based on parse state. [Context-Aware Scanning (PDF)](https://www-users.cse.umn.edu/~evw/pubs/vanwyk07gpce/vanwyk07gpce.pdf)
- **Tree-sitter** — context-aware tokenization where the lexer is coupled to the parser; external scanners for context-sensitive constructs. [Tree-sitter External Scanners](https://tree-sitter.github.io/tree-sitter/creating-parsers/4-external-scanners.html)

Apus follows the **ANTLR model**: stack-based modes (to support nesting), with the clean separation of concerns that both Flex and ANTLR share.

## The Key Principle: Separation of Concerns

All successful implementations separate two concerns:

| Concern | When | What |
|---------|------|------|
| **Mode membership** | *Before* matching | Which patterns participate? |
| **Mode transition** | *After* matching | How does the mode change? |

Mode membership is a **pre-filter** — ineligible patterns don't participate in matching and don't enter the longest-match competition. Mode transitions are **unconditional post-actions** — they execute only after the winning candidate is determined.

This separation eliminates the need for try/rollback transactions. A pattern either participates or it doesn't, decided before the regex runs. If it wins, its transitions execute unconditionally.

## The Gated Transition Model

A scanner mode annotation is a **gated transition** — a structured triple, not a sequence of independent actions:

```swift
struct GatedTransition {
    let gate: String       // === operand (required — which mode activates this)
    let pops: Bool         // <<< present? (pops the gate mode)
    let push: String?      // >>> operand (optional — which mode to enter)
}
```

### Why this structure is forced

- **`===` always comes first** — it's the pre-filter; nothing else can execute without it.
- **`<<<` comes before `>>>`** — a push before a pop would push X then pop X, which is a no-op.
- **`<<<` has no operand** — it always pops whatever `===` gated on; the operand is redundant.
- **`>>>` is optional** — not every transition changes the mode.

### The four shapes

| APUS syntax | pops | push | Meaning | ANTLR equivalent |
|-------------|------|------|---------|------------------|
| `=== "X"` | false | nil | participate in mode X | rule in mode X |
| `=== "X" >>> "Y"` | false | "Y" | enter Y from X | `pushMode(Y)` in mode X |
| `=== "X" <<<` | true | nil | leave X | `popMode` in mode X |
| `=== "X" <<< >>> "Y"` | true | "Y" | replace X with Y | `mode(Y)` in mode X |

### Multiple transitions per terminal

A terminal can have **multiple gated transitions**, one per mode it's active in. This is strictly more expressive than ANTLR (which requires duplicating the rule in each mode block). Each `===` starts a new transition:

```apus
fBraceOpen    - "{" .
              === "fStr" >>> "fExpr"
              === "fSpec" >>> "fExpr"
              === "fExpr" >>> "fExpr"
```

The scanner checks each transition's gate against the current mode. The first match determines eligibility and, if the candidate wins longest-match, which post-action executes.

### Default mode

Terminals without any `===` annotation are active in **all modes** (inclusive behavior). A terminal that should only be active in the default (empty-stack) mode uses `=== ""`:

```apus
fStringOpen   - /f"/ .
              === "" >>> "fStr"
```

## Scanner Algorithm

With gated transitions, the scanner loop is simple:

1. **For each pattern**, check if any of its transitions has a `gate` matching `modeStack.last ?? ""`. If none match, **skip this pattern entirely** (don't run the regex).
2. **Among eligible patterns**, find the longest match (existing logic, unchanged).
3. **Resolve ties** as before: keyword priority, then Schrodinger chain.
4. **Execute the winning candidate's matched transition**: if `pops`, pop the stack; if `push != nil`, push it. Both are unconditional.

No transactions, no rollback, no snapshot/restore. The pre-filter guarantees that post-actions always succeed.

## Example: Python F-Strings

Grammar fragment for `f"{value:{width}.{prec}f}"`:

```apus
fStringOpen       - /f"/ .
                  === "" >>> "fStr"

fStringText       - /(?:[^{"\\]|\\.)+/ .
                  === "fStr"

fStringExprOpen   - "{" .
                  === "fStr" >>> "fExpr"
                  === "fSpec" >>> "fExpr"
                  === "fExpr" >>> "fExpr"

fStringClose      - /"/ .
                  === "fStr" <<<

fExprToSpec       - ":" .
                  === "fExpr" <<< >>> "fSpec"

fExprClose        - "}" .
                  === "fExpr" <<<
                  === "fSpec" <<<

fSpecText         - /(?:[^{}"\\]|\\.)+/ .
                  === "fSpec"
```

Note how `{` has three transitions (active in three modes, same post-action) and `}` has two (closes either fExpr or fSpec). No duplicate terminal definitions needed.

### Stack trace for `f"{value:{width}.{prec}f}"`

| # | Input | Terminal | Gate | Post-action | Stack after |
|---|-------|----------|------|-------------|-------------|
| 1 | `f"` | fStringOpen | `""` | push fStr | `[fStr]` |
| 2 | `{` | fStringExprOpen | `fStr` | push fExpr | `[fStr, fExpr]` |
| 3 | `value` | identifier | — | — | `[fStr, fExpr]` |
| 4 | `:` | fExprToSpec | `fExpr` | pop, push fSpec | `[fStr, fSpec]` |
| 5 | `{` | fStringExprOpen | `fSpec` | push fExpr | `[fStr, fSpec, fExpr]` |
| 6 | `width` | identifier | — | — | `[fStr, fSpec, fExpr]` |
| 7 | `}` | fExprClose | `fExpr` | pop | `[fStr, fSpec]` |
| 8 | `.` | fSpecText | `fSpec` | — | `[fStr, fSpec]` |
| 9 | `{` | fStringExprOpen | `fSpec` | push fExpr | `[fStr, fSpec, fExpr]` |
| 10 | `prec` | identifier | — | — | `[fStr, fSpec, fExpr]` |
| 11 | `}` | fExprClose | `fExpr` | pop | `[fStr, fSpec]` |
| 12 | `f` | fSpecText | `fSpec` | — | `[fStr, fSpec]` |
| 13 | `}` | fExprClose | `fSpec` | pop | `[fStr]` |
| 14 | `"` | fStringClose | `fStr` | pop | `[]` |

Every post-action succeeds unconditionally because the gate already verified the stack top.

## Example: Swift Nested Multiline Comments

```apus
multilineCommentHead  : "/*" .
                      === "" >>> "multiline-comment"
                      === "multiline-comment" >>> "multiline-comment"

multilineCommentText  : /(?s).*?(?=\/\*|\*\/)/ .
                      === "multiline-comment"

multilineCommentTail  : "*/" .
                      === "multiline-comment" <<<
```

The `===` pre-filter on `multilineCommentText` ensures its greedy regex never participates outside comment mode — eliminating the longest-match collision that caused scan failures when this pre-filter was missing.

## Example: C++ Raw Strings

`R"tag(hello world)tag"` requires runtime delimiter matching. This is a case that goes beyond the static gated transition model — the gate value is captured from the input at runtime.

### Proposed extension: `===` accepts either a mode literal or a capture identifier

Current syntax (static):

```apus
=== "mode-name"
```

Extended syntax (dynamic):

```apus
=== tag
```

Semantics:

- `=== "mode"` keeps existing behavior: candidate is active when the top mode frame kind is `mode`.
- `=== ident` is a dynamic gate over the top frame's dynamic value.

Normative rule for `=== ident`:

1. If the candidate regex exposes named capture `ident`, require:
   - `capture(ident) == top.dynamicValue`
2. If the candidate regex does **not** expose named capture `ident`, require:
   - `top.dynamicValue != nil`

This gives both behaviors needed in practice:
- strict delimiter equality checks for closers, and
- in-scope gating for body tokens that do not re-capture the identifier.

This enables C++ raw-string delimiters without introducing parser coupling or NSRegularExpression.

### APUS example for C++ raw strings

Two equivalent styles could be supported but requires one extra mechanism to bind tag on push (separate from mode kind). Rejected for apus implementation.

Explicit mode literal + capture guard:

```apus
cppRawOpen - /R"(?<tag>[A-Za-z_0-9]{0,16})\(/ .
           === "" >>> "cpp-raw"

cppRawBody - /[\s\S]+?(?=\)[A-Za-z_0-9]{0,16}")/ .
           === "cpp-raw"

cppRawClose - /\)(?<tag>[A-Za-z_0-9]{0,16})"/ .
            === tag <<<
```

Compact weakly-typed style (preferred for this use-case):

```apus
cppRawOpen : /R"(?<tag>[A-Za-z_0-9]{0,16})\(/ .
           === "" >>> tag

cppRawBody : /[\s\S]+?(?=\)[A-Za-z_0-9]{0,16}")/ .
           === tag

cppRawClose : /\)(?<tag>[A-Za-z_0-9]{0,16})"/ .
            === tag <<<
```

Interpretation:

- `cppRawOpen` captures `tag` and pushes a new mode frame.
- Scanner stores one frame-local dynamic value on that frame (the captured tag).
- `=== tag` means the candidate is active only if that frame has a value and, when the candidate exposes capture `tag`, the values match.
- `cppRawClose` therefore matches only the correct runtime delimiter.
- On success, `<<<` pops the frame.

Clarification for dynamic gates:

- Dynamic `=== tag` is intentionally different from static `=== "mode"`.
- Static gates check fixed mode names.
- Dynamic gates check the top-frame dynamic value (in-scope check) and optionally equality with a same-named capture when that capture exists on the candidate.
- Therefore `cppRawBody` does not need to re-capture `tag`; it is admitted while a raw-string frame is active, and the actual delimiter equality is enforced by `cppRawClose`.

Note on weak typing and naming discipline: APUS intentionally allows this dynamic identifier style. In return, grammars should use clear identifier conventions (for example `cpp_tag`, `xml_name`, `tmpl_id`) to avoid accidental cross-feature reuse. The parser should also emit grammar-time diagnostics when an annotation references a capture name that is not present where required.

### Scanner data model update

Use a minimal frame object instead of a plain string stack:

```swift
struct ModeFrame {
    let kind: String
    var dynamicValue: String?   // used by >>> tag / === tag
}

private var modeStack: [ModeFrame] = []
private var scannerMode: String { modeStack.last?.kind ?? "" }
```

Optional future generalization: replace `dynamicValue` with a small bindings dictionary only if a real multi-value use-case appears.

Transition and push target both need tagged variants:

```swift
enum Gate {
    case mode(String)     // === "fstr-expr"
    case capture(String)  // === tag
}

enum PushTarget {
    case mode(String)     // >>> "fstr-expr"
    case capture(String)  // >>> tag
}

struct GatedTransition {
    let gate: Gate
    let pops: Bool
    let push: PushTarget?
}
```

### Candidate eligibility check

Gate checking remains pre-filter logic (before longest-match competition):

```swift
func gateMatches(_ t: GatedTransition,
                 modeStack: [ModeFrame],
                 matchCaptures: [String: String]) -> Bool {
    switch t.gate {
    case .mode(let m):
        return (modeStack.last?.kind ?? "") == m
    case .capture(let name):
        guard let expected = modeStack.last?.dynamicValue,
              let actual = matchCaptures[name] else { return false }
        return actual == expected
    }
}
```

Important: for `.capture(name)` gates, you must extract named captures for that token candidate **before** candidate admission.

### Binding strategy on push/pop

When applying the winning transition:

```swift
if transition.pops { _ = modeStack.popLast() }
if let push = transition.push {
    switch push {
    case .mode(let m):
        // Static mode push, no dynamic value attached.
        modeStack.append(ModeFrame(kind: m, dynamicValue: nil))

    case .capture(let name):
        guard let captured = winningCaptures[name] else {
            // grammar-time validation should prevent this; keep runtime safe
            return
        }
        // Compact dynamic push: mode kind and value are the captured tag.
        modeStack.append(ModeFrame(kind: captured, dynamicValue: captured))
    }
}
```

This keeps the dynamic value lexical (frame-local), naturally handling nesting and avoiding global rollback complexity.

### Named captures in Swift Regex

With compile-time regex literals, key-path access (`match.output.tag`) is ergonomic, but this project compiles regexes from grammar text at runtime. In that setup:

- Prefer `Regex<AnyRegexOutput>` for capture-bearing patterns.
- Read named captures dynamically from `AnyRegexOutput` (by capture name), not by key-path (`\.name`).
- This stays in Swift Regex and avoids `NSRegularExpression`.

### Tag collection process (not hardcoded)

The identifier in annotations (e.g. `tag` in `=== tag`) is data from the grammar, not a hardcoded scanner constant.

1. Parse annotations for each terminal and collect dynamic identifiers referenced by `=== ident` and `>>> ident`.
2. Parse that terminal's regex source and collect named capture groups (`(?<name>...)`) with their group indices.
3. Validate: each referenced identifier must correspond to a named capture where required. Emit grammar diagnostics if missing.
4. At scan time, for candidate matches of that terminal, extract only the needed captures by name/index.
5. Apply transitions using those extracted values (`=== ident` compare, `>>> ident` push value).

This keeps the mechanism generic: `tag`, `delim`, `quote`, etc. all work the same way.

### Why this extension is minimal

- No new scanner operator needed.
- Existing `===`, `>>>`, `<<<` semantics remain unchanged.
- Static grammars remain fully backward compatible.
- Dynamic behavior is opt-in and only used where needed (notably C++ raw strings).

The static model still covers Swift/Python/JS interpolation-style mode switching; this dynamic gate extension addresses runtime-delimiter families cleanly.

## Example: C# Interpolated Strings

`$"Hello {name}, you have {count:N0} items"` — structurally identical to Python f-strings. Same terminal definitions with different mode names (e.g., `csStr`, `csExpr`, `csFmt`).

## Existing Grammar Migration

Current grammars (Swift.apus, ScanModeTest.apus) use bare `>>>` and `<<<` with operands. These need `=== "mode"` prepended:

| Old syntax | New syntax |
|------------|-----------|
| `>>> "multiline-comment"` | `=== "" >>> "multiline-comment"` |
| `=== "multiline-comment"` | `=== "multiline-comment"` (unchanged) |
| `<<< "multiline-comment"` | `=== "multiline-comment" <<<` |

The `<<<` operand is dropped since it's always identical to the `===` gate.

## Implementation Plan

### Data model

Replace `ModeOperator` / `ModeAction` / `[ModeAction]` with:

```swift
struct GatedTransition: CustomStringConvertible {
    let gate: String
    let pops: Bool
    let push: String?
}
```

`TokenPattern.annotations: [ModeAction]` becomes `TokenPattern.transitions: [GatedTransition]`.

### ApusParser changes

Replace the annotation-parsing loop with:
```
while token.kind == "===" {
    parse === literal
    optionally parse <<<
    optionally parse >>> literal
    append GatedTransition to terminal's transitions
}
```

### Scanner changes

In the matching loop, before trying a pattern:
```swift
let mode = modeStack.last ?? ""
let transition = pattern.transitions.first { $0.gate == mode }
guard pattern.transitions.isEmpty || transition != nil else { continue }
```

After the winning candidate is determined:
```swift
if let t = winningTransition {
    if t.pops { modeStack.removeLast() }
    if let push = t.push { modeStack.append(push) }
}
```

### Layout interaction

`LayoutTokenInjection.swift` needs to check the mode stack — indent/dedent injection should be suppressed when inside modes that don't use layout (e.g., f-string text, format specs). This is a separate concern from the mode model itself and can be addressed independently.

## Design Principles

1. **Mode membership is a pre-filter, not a runtime check.** Ineligible patterns never run.
2. **Post-actions are unconditional.** The pre-filter guarantees they succeed.
3. **No transactions, no rollback.** The gated transition model eliminates this complexity.
4. **Structured, not sequential.** A transition is a triple (gate, pops, push), not a list of operations. Invalid states are unrepresentable.
5. **Multiple transitions per terminal.** More expressive than ANTLR's one-rule-per-mode, less repetitive.

## Implemented Learnings (April 2026)

- **Literal matching is by terminal source text, not terminal name.**  
  After introducing named literal terminals, scanner literal matching must compare input prefix with `TokenPattern.source`.
- **Mode annotations are parsed as annotations, not as grammar literals.**  
  Parsing `=== "" >>> "mode"` via `literal()` accidentally registered `""` as a real terminal and caused non-advancing behavior.
- **Unannotated terminals remain globally active (inclusive behavior).**  
  `=== ""` means default-mode-only; it is not the default for unannotated terminals.
- **Scanner has an explicit non-advancing-match guard.**  
  Empty winning matches now fail fast (`nonAdvancingMatch`) instead of risking scanner loops.
- **Telemetry/reporting is isolated from scanner core and DEBUG-scoped.**  
  Scanner timings/events are routed through `ScannerTelemetry`; release behavior uses no-op telemetry.
- **Swift key-path lexical edge case retained intentionally.**  
  `\\.` may be consumed as one longest token, so the explicit `keyPathExpression = "\\." ...` fallback remains useful.
