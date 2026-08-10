# Oracle Disambiguation Unification — plan

**Status:** planning / pre-implementation. Work happens on an **isolated branch**.
**Goal:** make *every* Oracle disambiguation pragma (`@prefer`, `@longest`, `@shortest`,
`@left`, `@right`; `@avoid` already done) work at **any ALT-bearing node** — not just the
top-level `nt.alt` of a nonterminal, but also the alternate clusters produced by inline
`( a | b )` selection, `[ … ]` (OPT), `{ … }` (KLN) and `< … >` (POS). Expected payoff:
one uniform code path (major simplification), and grammar rules like the factored
`keyPathExpression` become expressible.

Motivating cases:
- FAILED today: `keyPathExpression = "\\" ( @prefer keyPathRootType keyPathComponents? | keyPathComponents ) .`
  — `@prefer` inside the group is inert → ambiguity explodes (1 → 40, measured).
- WORKS today: `parameter = attributes? [ @avoid parameterDeclarationModifiers ] parameterNames … .`
  — `@avoid` is nested and works, because it is the one rule already registered by a full-graph walk.

---

## Why the asymmetry exists (grounded in the code)

The rule *mechanisms* are already **level-agnostic** — they key on BSR spans/pivots `(i, j, k)`,
never on nesting depth (`Oracle.swift`):
- `pruneByExtent` (group by start `i`, keep max/min `j`) → `LongestMatchRule`/`ShortestMatchRule`
- `pruneByPivot` (group by `(i, j)`, keep max/min `k`) → `LeftAssocRule`/`RightAssocRule`/`AvoidOptionalRule`
- `PreferRule` (prune a non-preferred span `(i, j)` where a preferred sibling covers the exact same `(i, j)`)

And **Phase-1 productivity pruning already recurses through nested clusters**
(`visitAlternates` / `iterEndPositions` / `visitBracket` walk `bracket.alt`). So pruning at a
nested level is already *safe* — the "never destroy the only complete derivation" net exists.

The asymmetry is only in **registration** (Oracle `init`):

| pragma | registration site | attaches where | nested today? |
|---|---|---|---|
| `@avoid` | **full-graph walk** (`Oracle.swift:199–209`) | symbol after any bracket | ✅ yes |
| `@prefer` | walks **only `nt.alt`** (`177–193`) | non-preferred sibling's last symbol | ❌ |
| `@longest`/`@shortest` | `nt.disambiguation` on the **nonterminal LHS** (`156–161`) | the nonterminal node | ❌ |
| `@left`/`@right` | walks **only `nt.alt`** bodySymbols (`162–171`) | each body symbol | ❌ |

Attachment facts (from `ApusParser.swift` / `GrammarNode.swift`):
- `@prefer` sets `isPreferred` on the **sequence node** (`ApusParser:408`), inside `selection()` —
  which runs for `( … )` groups too. **So `isPreferred` ALREADY lands on nested alternates**; the
  grouped grammar loaded fine — the Oracle simply never scanned the cluster. → nested `@prefer` is
  almost entirely a *registration-walk* change.
- `@longest`/`@shortest`/`@left`/`@right` are read at production start (`ApusParser:185–187`) and
  stored on the LHS (`lhsNode.disambiguation`, `:363`). They are **not placeable on a cluster**
  today → nested support needs parser + model plumbing.
- Node kinds (`GrammarNode.swift:41`): `EOS T TI C B EPS N ALT END DO OPT POS KLN`.
  `isBracket = DO|OPT|KLN|POS` (`:55`); `isClosure = KLN|POS` (`:57`). Clusters carry an `.alt`
  chain (their alternates) exactly like a nonterminal.

---

## Clean end-state (the target)

**One graph walk that treats every ALT-bearing node uniformly.** For each node that owns an
`.alt` chain (a nonterminal, or a `DO`/`OPT`/`KLN`/`POS` cluster):
1. read disambiguation annotations attached to the node (`@longest`/`@shortest`/`@left`/`@right`)
   and to its alternates (`@prefer`), and
2. register the matching, already-existing rule keyed on **that node's own `.alt`** (and its
   body symbols), reusing `PreferRule`/`LongestMatchRule`/… verbatim.

This folds today's separate `@avoid` walk + the two `nt.alt` loops into a single recursion,
sharing the traversal — the "major simplification" the branch is chasing.

---

## Work plan (branch)

Tests first (this is the risky bit — lock behaviour before touching the engine):

1. **Extract** the existing pragma tests from `CoreGrammarTests.swift` (~461–562) into a new
   `OracleDisambiguationTests` suite (helpers `parsePostOracle` / `parseAndDisambiguate` in
   `TestInfrastructure.swift`):
   - `@left`/`@right`: `leftAssocPrunes`, `rightAssocPrunes`, `leftAssocFourOperands`
   - `@longest`: `longestExtent`
   - `@prefer` under OPT: `preferUnderOptFlat`, `preferUnderOptLeftRecursive`
   - `@avoid`: `avoidSkipsOptional`, `avoidKeepsTakenWhenSkipFails`
2. **Add NESTED-cluster test grammars** (the new capability), one per pragma × cluster kind,
   using tiny inline grammars — e.g.
   - `@prefer` in a selection group: `S = "\" ( @prefer A B? | B ) .`
   - `@longest`/`@shortest` on `{ }` / `< >` / `( )`
   - `@left`/`@right` on a nested cluster
   Assert both **acceptance preserved** and **residual ambiguity → expected** (mirror the
   top-level assertions).
3. **Implement** the unified registration walk in `Oracle.swift`; add parser/model support for
   cluster-attached `@longest`/`@shortest`/`@left`/`@right` (a `disambiguation` slot on cluster
   nodes + apus parse).
4. **Validate**: new suite green; then the full Swift sweep must hold **accept 0 / reject 79 /
   ambiguity 1** (run 2–3× — non-deterministic hashing is the fuzzer). Re-test the factored
   `keyPathExpression` group as the headline win.

Tiering (safe increments):
- **Tier A — `@prefer` on non-repeating selection `( a | b )`** (the `keyPathExpression` case):
  LOW risk. Registration-walk generalization only; `isPreferred` already attaches; `PreferRule`
  reused as-is. ✅ **DONE** (commit `3685f3f`). `registerPrefer(altChainHead:)` extracted and
  called per BRACKET node inside the existing `@avoid` full-graph walk. Verified: every `@prefer`
  in `Swift.apus` is a top-level nonterminal alternate (none inside an inline group), so the change
  is purely additive on the real grammar — full sweep unchanged at accept 0 / reject 79 / residual
  ambiguity 1. New nested test `preferInSelectionGroup` green.
- **Tier B — `@longest`/`@shortest`/`@left`/`@right` on clusters, incl. `{ }` / `< >`**: MEDIUM.
  ✅ **DONE**. **Design resolved (user):** all disambiguation pragmas are alternate-prefixes on an
  `.ALT` node — `@prefer` via `isPreferred`, the rest via `alt.disambiguation` — both parsed in
  `sequence()`. Since a nonterminal AND every bracket own an alternate chain, there is *no* placement
  question: the annotation lives on the alternate, wherever alternate-prefixes already go
  (`( @left E "+" E | n )`, `< @longest word >`, `{ @longest word }`). Implementation:
  - `ApusParser.sequence()`: parse `@longest/@shortest/@left/@right` prefix → `startOfSequence.disambiguation`.
  - `Oracle.registerAltDisambiguation(owner:altChainHead:)`: reads `alt.disambiguation` off any chain;
    extent (`@longest/@shortest`) registers on the OWNER node, assoc (`@left/@right`) on that alt's
    body symbols. Called for both nonterminals (loop) and brackets (walk).
  - Legacy production-start form (`@longest X = …`, `nt.disambiguation`) untouched → zero Swift.apus
    migration. Full sweep unchanged: accept 0 / reject 79 / residual ambiguity 1.
  Six `NestedCluster` tests green (prefer×2, left, right-parity, longest-POS, longest-KLN).

  **Two findings (recorded, orthogonal to this branch):**
  1. **KLN yield-identity hazard did NOT bite** the tested `{ @longest word }` case — the shared-cluster
     conflation concern (below) did not manifest for a simple repetition extent. Not proven safe in
     general; revisit if a cluster-`@longest` over genuinely-varying repetition extents misbehaves.
  2. **`@right` under-prunes on 3+ operands** — `@right E = E "+" E | n` on `1 + 2 + 3` prunes only
     1 pivot and leaves residual ambiguity (`isUnambiguous: false`), whereas `@left` fully resolves.
     Verified **level-independent** (same at top level and in a cluster), so it is a PRE-EXISTING
     `RightAssocRule` limitation, not a Tier-B/cluster issue. `rightOnCluster` therefore asserts
     `pruned > 0` (parity with the top-level `rightAssocPrunes`), not `isUnambiguous`. Fixing the
     right-assoc keep-min-pivot rule to cascade to a fixpoint is a separate task.

---

## The one real hazard (why this is risky)

**EBNF cluster sharing / yield identity.** Per the project's EBNF-closure work, `KLN`/`POS`
re-entry reuses a **single** CRF cluster ("cluster index is a node ref, not a position"), so a
**repetition** cluster node's yields can conflate multiple textual occurrences. Span/pivot pruning
assumes yields separate cleanly by `(i, j)` / `(i, j, k)`. That holds for **non-repeating
selection groups** (`DO`/choice) — Tier A is safe — but repetition brackets (`{ }` / `< >`) need
verification that a cluster's yields don't collapse distinct occurrences before we prune them.
Mitigation: land Tier A first; for Tier B, add repetition-specific nested tests and check
yield identity at shared cluster nodes before trusting the prune.

Also mind: `@prefer`'s preferred branch must be **non-empty** (it keys on the last body symbol);
`@prefer` is same-span only (extent preference is `@longest`'s job) — these invariants carry over
to clusters unchanged.

---

## Epsilon watertightness & the `@avoid` model (findings, 2026-08-10)

Stress suite `OracleDisambiguationTests.EpsilonAndAvoidModel`, grounded in Scott/Johnstone/van
Binsbergen "Derivation representation using binary subtree sets" (SCICO 2019): an empty derivation
is a real degenerate BSR element `(X ::= ε, j, j, j)` (§3.1 rule 1); the paper explicitly **punts**
on nullable `X ::= BBβ`, which makes `(BB,i,i)` a multigraph with two `(B,i,i)` children (§1.1 p4,
§3.2 p8: "easy to add if required"). That punt is our KLN/POS shared-cluster hazard, by name.

1. **Same-span `@prefer`/`@avoid` are epsilon-watertight.** `@prefer` keys correctly through an
   explicit-ε tail and a skipped-OPT tail: an empty alternate is an addressable `(i,i)` element on
   its last symbol, so `PreferRule` keys on it. Empty vs non-empty are different spans → no false
   cross-prune.
2. **The engine does NOT conflate nullable `A A`.** `A = "a" | ""` on `"a"` is represented as a
   genuine two-tree ambiguity — we close the gap Scott left open (no ε-multigraph collapse).
3. **`@avoid A` ≡ `@prefer` on all siblings** for **same-span** groups (the "3 = 1" equivalence
   holds via `PreferRule`, winners unranked). Generalising `@avoid` to a non-optional multi-alt
   group needs it parseable as an **alt-prefix** on any alt chain (today `consumeAvoid` only fires
   right after `[`/`{`/`<`); tripwire `oneAvoidEqualsThreePrefer` is `withKnownIssue` until then.

### Should Swift.apus replace `[ @avoid X ]` with `@shortest [ X ]`? — **No.**

They are equivalent **only locally**, when skip and take converge to the **same end** (verified: the
two original `@avoid` cases pass with `@shortest`). But the two rules differ in *scope*:
- `@avoid` = `pruneByPivot` on the **following symbol**, grouped by the follower's `(i,j)` — surgical:
  it only pits skip against take when they reach the **same overall span**.
- `@shortest [X]` = `pruneByExtent` on the **OPT node**, grouped by the OPT's **start `i`** — coarser:
  it prunes *every* take `(i,m)` in favour of skip `(i,i)` from that start, **ignoring the follower**.

Swift.apus's five `@avoid` uses (`prefixExpression`, `closureParameter`×2, `parameter`×2) are
*deliberately* shared-end (the comments at `Swift.apus:899,1620` engineer a "common end" so
`pruneByPivot` groups correctly), so a swap would *probably* hold — but `@shortest` is a blunter
instrument with real over-prune risk if any optional-start ever has take-readings that complete at
different extents, it buys nothing, and `@avoid` already works. **Keep `@avoid`.** The valuable
direction is the opposite: generalise `@avoid` to any alt chain as "prefer the siblings" (finding 3),
not replace it with `@shortest`.

---

## Key file references

- `Oracle.swift`: rules (`28–98`), registration `init` (`152–210`), Phase-1 `pruneUnproductive`
  (`268–453`, already cluster-aware).
- `GrammarNode.swift`: kinds `:41`, `isBracket` `:55`, `isClosure` `:57`, `isPreferred` `:161`,
  `isAvoided` `:169`, `disambiguation` `:200`.
- `ApusParser.swift`: disambiguation pragma parse `:185–187` + LHS attach `:363`; `@prefer` attach
  `:405–409`; `@avoid` (`consumeAvoid`) `:639–696`.
- Tests: `CoreGrammarTests.swift:461–562`; harness `TestInfrastructure.swift:237` / `:261`.

**Repo state at plan time:** `main` at the pushed grammar-cleanup commit (+ the `operatorBody`
`.matchingSemantics` tidy, now pushed). This unification proceeds on a fresh isolated branch.
