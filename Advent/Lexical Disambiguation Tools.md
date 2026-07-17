# Lexical Disambiguation Tools — a unified perspective

Written Jul 7 2026, after the maximal-munch / whitespace / merge work drove Swift.apus
ambiguity from ~1378 → ~782. This synthesises the recurring problem and proposes an
**orthogonal, language-neutral tool set**, so future grammars aren't a pile of ad-hoc hacks.

## The recurring problem
A character or token means different things depending on **context** or **adjacency**.
Cases we hit (all in Swift, but every language has its own set):

| case | example |
|---|---|
| keyword vs longer identifier | `for` inside `foreach` |
| multi-char operator vs its pieces | `&&`, `<<`, `==` |
| operator that must *split* | `>>`→`>` `>` (nested generics), `??`→`?` `?` (`Int??`) |
| `.self`/`.Type` vs member access | `Foo.self` |
| regex delimiter vs division | `/abc/` vs `a / b` |
| operator prefix/infix/postfix | `a-b` vs `a - b` vs `a⏎-b` |
| newline: separator vs continuation | `a⏎-b` (two stmts) vs `a - b` |
| call `(` / subscript `[` at line start | `g()⏎(x)` (two stmts) vs `g()(x)` |

## The two underlying axes
Every one of these is resolved by **extent** and/or **context**:

1. **EXTENT** — how far a token reaches: *longest match* (maximal munch), or a permitted *shorter split*.
2. **CONTEXT** — where it sits:
   - **adjacency** — the characters/whitespace bordering it,
   - **grammar position** — which slot the parser is in (handled by grammar *structure*),
   - **priority** — which of two *same-span* interpretations wins.

## The orthogonal tool set (four tools)

### Tool 1 — Boundary predicates (adjacency): `<s>` `>s<` `<n>` `>n<`  ✅ HAVE, proven
Constrain the trivia gap immediately before a symbol (whitespace present/absent, newline
present/absent). Resolves: operator prefix/infix/postfix **boundness** (`a+b`/`a + b`/`a⏎-b`
— infix ⟺ symmetric gaps), **statement separators**, **call/subscript at line-start** (`>n<`).
This is the workhorse and it is genuinely general.
- **Generalisation worth considering:** `<s>`/`<n>` are two hard-wired boundary *classes*
  (any-whitespace, newline). A `<[class]>` / `>[class]<` form — boundary defined by an
  arbitrary grammar-declared character class — would cover other languages' rules
  (e.g. "no tab here", "must be followed by a digit") with the same primitive.

### Tool 2 — Longest match / lexical class: `@lexicalClass`  ✅ HAVE, proven
A regex terminal declared a lexical class; a literal match is suppressed when a class
terminal matches strictly longer at the same start. Resolves maximal munch (keyword `for`
inside `foreach`; operator `&&`). Grammar-derived, language-neutral.

### Tool 3 — Munch exemption / split  ⚠️ EXISTS IN THREE AD-HOC FORMS — should unify
"At *this* position a token shorter than the maximal munch is allowed." Currently spelled:
- `@splitBefore("/")` on `operatorToken` (offer the prefix ending before an internal `/`),
- the *regex-terminal trick* (`closeAngle - />/` closes a generic even inside `>>`, because
  regex terminals are exempt from the literal munch),
- the retired `~~~` Frankenstein marker.
These are **one concept**. They should collapse into a single primitive — e.g. a per-use
`~split` marker meaning "this terminal-use is exempt from maximal munch / may take a single
class char here." Resolves `>>`, `??`, `^^/regex/`.

### Tool 4 — Priority (same-span choice): Oracle `@prefer` / `@longest` / `@shortest`  ⚠️ UNDERUSED — the outstanding one
When two interpretations cover the **same span**, choose one. Resolves **regex-vs-division**
(prefer regex at expression-start) and same-span keyword-vs-identifier. This is *not* an
extent or adjacency problem — both readings have identical extent — so Tools 1-3 cannot
touch it. It is the Oracle's job. TODO #19 independently concluded "regex ambiguity is
structural — use the Oracle."

## Mapping (which tool each case wants)
| ambiguity | tool |
|---|---|
| keyword/`foreach`, `&&`, `<<` | 2 (`@lexicalClass`) |
| generic `>>`, optional `??`, `^^/regex/` | 3 (exemption/split) |
| `.self` | grammar redundancy (it *is* a member access) |
| operator prefix/infix/postfix, newline continuation, call/subscript line-start | 1 (boundary) |
| **regex vs division** | **4 (priority)** ← the residual |

## The insight / where to invest
- **Tools 1 (adjacency) & 2 (extent) are in place and carry most of the load.** They're
  orthogonal and reusable — the boundary annotations especially.
- **Tool 3 is fragmented** (three spellings of "exempt from munch"). Unify into one primitive
  before adding more languages, or the ad-hoc forms multiply.
- **Tool 4 (priority) is the missing piece for the regex residual.** regex-vs-`/` is a
  same-span choice (regex preferred at expression-start; `/` is division only after a value).
  Boundary/munch can't express it; it belongs in the Oracle (`@prefer`) — OR is sidestepped
  by a targeted grammar fact (below).

## Regex: analysis + attack
`/abc/` at expression-start parses two ways: **(1)** a `regularExpressionLiteral`, and
**(2)** prefix-`/` applied to (`abc` with postfix-`/`) — because `/` ∈ `operatorToken`, so it
is a candidate prefix *and* postfix operator. swift-syntax never sees (2): its lexer prefers
regex at expression-start (`preferRegexOverBinaryOperator`). Both `/`s in (2) are even
correctly prefix/postfix-*shaped* by whitespace, so Tool 1 can't kill it — it's a genuine
same-span priority (Tool 4).

**Attempted grammar workaround — and why it's not the answer.** The faithful positional
statement is narrow: *at expression-start (= the prefix position), `/` is regex, not a prefix
operator*. That justifies excluding `/` from **`prefixOperator` only** — and since reading
(2) *starts* with prefix-`/`, breaking that start alone kills it (the postfix exclusion I
first wrote was redundant AND mis-justified — "expression-start" says nothing about postfix).
But the exclusion can't be expressed with the tools we have: `---("/")` is a no-op (`/` is
not a literal terminal — it reaches prefix position via the `operatorToken` regex), and a
`/`-less prefix-operator terminal would duplicate the big `operatorToken` regex (the exact
duplication we've been *removing*). It's also not truly faithful — swift-syntax doesn't forbid
`/` as a prefix operator; it *prefers regex by position*.
**Conclusion: regex-vs-`/` is Tool 4 (priority), full stop.** The clean fix is an Oracle
priority — "at expression-start, prefer `regularExpressionLiteral` over the `/`-operator
tiling" — i.e. `preferRegexOverBinaryOperator` realised as an Oracle rule, not a grammar
hack. This is a separate track (the Oracle), consistent with TODO #19.

**✅ DONE Jul 7 — via a new `@avoid` bracket pragma (Tool 4, the negative dual of `@prefer`).**
First attempt used `@prefer`, but `@prefer` is *start-keyed*: it prunes a non-preferred sibling
`(i…j)` where a preferred sibling yields from the same start, and it keys on the preferred
alternate's *last body symbol*. That forces two shapes the inline OPT can't provide — the readings
must be **sibling alternates** (the Oracle only walks top-level `nt.alt`) and the preferred branch
must be **non-empty**. The regex "skip the operator" reading is the *empty* branch of an OPT, so
`@prefer` needed a manufactured split into a helper nonterminal (`prefixOperatorApplication`) that
duplicated `postfixExpression` into two non-empty siblings.

`@avoid` removes the split. It marks the **explicit, non-empty "take" branch** instead:
```
prefixExpression = [ @avoid prefixOperator ] postfixExpression .
```
Preferring the empty branch is really a **pivot** choice, not a same-start choice: in the enclosing
alternate `[OPT postfixExpression]` over `(i,j)`, `postfixExpression`'s BSR pivot `k` is the OPT
boundary — `k=i` ⟺ operator skipped, `k>i` ⟺ operator taken. So `@avoid` compiles to a **min-pivot**
rule (`AvoidOptionalRule`, = `pruneByPivot keep:min`) on the symbol *following* the bracket. That
needs no empty branch to key on. Where skipping fails (`-x`), phase-1 already drops the `k=i` yield,
so the lone "taken" pivot survives untouched. Harvest **782→720 (−62)**, regex `postfixExpression`
pivot **64→4**, **0 acceptance regressions**, and **one fewer signature** than the `@prefer` split
(no helper nonterminal). `-x`/`!x`/`consume x`/`a/b` unaffected.

`@avoid` generalizes: a fallback sibling alternate or a lazy `{…}`/`<…>` repetition can be
`@avoid`ed the same way (min-pivot on the following symbol = prefer fewest iterations). Syntax:
`@avoid` as the first token inside any bracket — `[ @avoid X ]`, `{ @avoid X }`, `< @avoid X >`.

## Does the `<c>`/`>c<` generalization subsume Tool 3 (munch-exemption)? — No.
They are on **orthogonal axes**: `<c>`/`>c<` is *adjacency* (which character borders the token —
a generalization of `<s>`/`<n>` to arbitrary declared char-classes), whereas munch-exemption is
*extent* (this token may be shorter than maximal munch here). A boundary predicate constrains
neighbours; it cannot "opt out of the length check" (what `closeAngle` does by being a regex
terminal) nor "offer two extents" (what `@splitBefore` does). So `<c>`/`>c<` is a valuable Tool-1
generalization (cross-language: "followed-by-digit", "no-tab-here") but leaves Tool 3 standing.
Tool 3's cleanup remains its own exercise: unify `@splitBefore` / regex-terminal-trick / `~~~`
into ONE "exempt-from-munch-here" primitive.
