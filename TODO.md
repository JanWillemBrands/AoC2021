# Consolidated TODOs

This file is the canonical TODO list across markdown docs in this project.

## Active TODOs

1. Output: simple parse tree from BSR set, similar to Covfefe README example.
Source: `Advent/claude.md` (previously in "Future Work & TODOs").

2. Performance: profile `tortureART` and decide optimization priority between speed and memory.
Source: `Advent/claude.md` (previously in "Future Work & TODOs").

2a. Descriptor dedup A/B stress run: repeat `globalDescriptorSet` vs `distributedPackedBySlot` on larger source inputs (concatenated Swift corpus / heavy grammars) to confirm whether the observed small win is stable.
Source: thread implementation + `Advent/AdventTests/PerformanceTests.swift`.

3. Scanner optimization: add first-byte guard (`[Bool]` ASCII lookup table per `Pattern`) to cut failed regex attempts.
Source: `Advent/claude.md` (previously in "Future Work & TODOs").

5. `@unless` engine — cascade pruning from body symbol yields to `.N` yields. The rule fires correctly on the last body symbol of the annotated alternate (verified: 2 yields disambiguated on `Array<Array<Int>>`), but the `.N` (nonterminal) yield that summarises the alternate's match still survives because nothing in the existing Oracle removes a `.N` yield when one of its alternates' body yields is pruned. As a result, `DerivationBuilder` continues to enumerate derivations through the surviving `.N` yield (Array<Array<Int>> stays at ~10 derivations instead of dropping to 1). The natural fix — a second `pruneUnproductive` call at the end of `Oracle.disambiguate` — breaks all subsequent message parses (descriptors=0 from message 2 onward). Likely cause: `pruneUnproductive` mutates `nt.yield` in place, and `GrammarNode.clearNodes()` doesn't fully reset state between message parses (known TODO comment in `clearNodes()` flags this). Need either (a) fix `clearNodes` to be exhaustive, then re-enable the second `pruneUnproductive`, or (b) add a targeted "remove .N yields whose alternate-body yields were pruned" hook driven from `UnlessPredicateRule`, or (c) augment `BinarySpan` with an alternate ID so `.N` yields can be filtered alternate-by-alternate.
Source: today's @unless implementation work; `Advent/Structured Lookahead Design.md`; `Advent/Oracle.swift`; `Advent/GrammarNode.swift:303` clearNodes TODO.

6. `@unless` engine — `resolveUnlessTargets` placement. The call must sit *after* `populateBitSets`, not between `assignNameIDs` and the FIRST/FOLLOW fixpoint loop. Iterating `grammar.nonTerminals` at that earlier point breaks FIRST/FOLLOW propagation — even a pure no-op iteration causes all parses to fail. Root cause not yet identified; FIRST/FOLLOW must have an undocumented iteration-order dependency that's stable only when the dictionary hash state is left undisturbed between `assignNameIDs` and the fixpoint loop. Investigate why a single read-only dictionary iteration perturbs subsequent FIRST/FOLLOW iteration order in a way that changes the converged result.
Source: today's @unless implementation work; `Advent/ApusParser.swift` finalisation sequence.

7. **Workflow — binary cache traps**. `BuildProject` reports "successful" but doesn't always re-link the executable, especially after small edits. The binary mtime ends up *older* than the source mtimes, and runs of `/.../Debug/Advent` execute stale code, producing misleading results (today: a "0/47 PASS" panic for ~20 min was just stale binary). Workarounds tried: `touch` source files, then `BuildProject` — works most of the time. Better fix needed: (a) make `BuildProject` always force a fresh link, (b) verify binary mtime > source mtime before each run, (c) add a "clean build" MCP tool. Until fixed, always check `stat -f "%Sm %N" Advent <SourceFile>` before drawing conclusions from run output.
Source: today's @unless implementation debugging; `BuildProject` MCP tool.

8. **Workflow — slow integration testing**. Running the 47-message Swift.apus test bed via `main.swift` takes ~190s end-to-end. The SwiftSyntax 590-case sweep via `xcodebuild test` takes ~40min projected. Both are too slow for iterative grammar development. Options: (a) parallelise messages across cores, (b) cache `Scanner` token streams by input hash so re-runs only re-parse, (c) carve a small "smoke" subset (~10 messages) for fast iteration, (d) profile and optimise the GLL hot path on the longest messages.
Source: today's @unless verification; `Advent/main.swift` per-message loop; `xcodebuild test -only-testing:...` sweep timing.

## TODO References Found In Markdown

These are TODO references, not standalone tasks, but included for completeness.

1. `Advent/Trivia Oracle.md`: "These are in `Swift.apus` comments/TODOs and should be modeled in oracle policy."
2. `Advent/Trivia Oracle.md`: "Local grammar notes/TODOs: `Advent/Swift.apus`"

## Maintenance Rule

- Add new markdown TODOs here and link back to source context when needed.
- `Advent/codex.md` and `Advent/claude.md` should reference this file instead of maintaining separate TODO lists.
