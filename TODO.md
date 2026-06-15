# Consolidated TODOs

This file is the canonical TODO list across markdown docs in this project.

## Active TODOs

1. Performance: profile `tortureART` and decide optimization priority between speed and memory.
Source: `Advent/claude.md` (previously in "Future Work & TODOs").

2. `@unless` engine — cascade pruning from body symbol yields to `.N` yields. The rule fires correctly on the last body symbol of the annotated alternate (verified: 2 yields disambiguated on `Array<Array<Int>>`), but the `.N` (nonterminal) yield that summarises the alternate's match still survives because nothing in the existing Oracle removes a `.N` yield when one of its alternates' body yields is pruned. As a result, `DerivationBuilder` continues to enumerate derivations through the surviving `.N` yield (Array<Array<Int>> stays at ~10 derivations instead of dropping to 1). The natural fix — a second `pruneUnproductive` call at the end of `Oracle.disambiguate` — breaks all subsequent message parses (descriptors=0 from message 2 onward). Likely cause: `pruneUnproductive` mutates `nt.yield` in place, and `GrammarNode.clearNodes()` doesn't fully reset state between message parses (known TODO comment in `clearNodes()` flags this). Need either (a) fix `clearNodes` to be exhaustive, then re-enable the second `pruneUnproductive`, or (b) add a targeted "remove .N yields whose alternate-body yields were pruned" hook driven from `UnlessPredicateRule`, or (c) augment `BinarySpan` with an alternate ID so `.N` yields can be filtered alternate-by-alternate.
Source: today's @unless implementation work; `Advent/Structured Lookahead Design.md`; `Advent/Oracle.swift`; `Advent/GrammarNode.swift:303` clearNodes TODO.

3. `@unless` engine — `resolveUnlessTargets` placement. The call must sit *after* `populateBitSets`, not between `assignNameIDs` and the FIRST/FOLLOW fixpoint loop. Iterating `grammar.nonTerminals` at that earlier point breaks FIRST/FOLLOW propagation — even a pure no-op iteration causes all parses to fail. Root cause not yet identified; FIRST/FOLLOW must have an undocumented iteration-order dependency that's stable only when the dictionary hash state is left undisturbed between `assignNameIDs` and the fixpoint loop. Investigate why a single read-only dictionary iteration perturbs subsequent FIRST/FOLLOW iteration order in a way that changes the converged result.
Source: today's @unless implementation work; `Advent/ApusParser.swift` finalisation sequence.

4. investigate caching the Swift regex instantiations so that successive use becomes faster.

## Maintenance Rule

- Add new markdown TODOs here and link back to source context when needed.
- `Advent/codex.md` and `Advent/claude.md` should reference this file instead of maintaining separate TODO lists.
