# This file is the canonical TODO list in this project.

0. **preserving trivia** needs a round-trip test

1. **wider tests on Swift 6.4** test all swift-syntax sources files for equivalence.

2. **SwiftSyntax 604 migration frontier**

   Treat the imported 604 corpus as ground truth: no disabled snippets. A 604 test is done when it
   passes, or when a remaining SwiftSyntax-604-vs-Swift-6.4-compiler disagreement has an explicit
   note.

   Current rough classification from the 604 failure bundle:

   - 122 distinct failing snippets.
   - 98 Advent accept/reject gaps.
   - 60 SwiftSyntax reference mismatches in our harness.
   - 22 tree mismatches.
   - 0 residual ambiguities.

   Feature-family buckets:

   - 31 mixed/other.
   - 19 `@_implements` attribute fragments.
   - 15 ownership keywords / pattern modifiers.
   - 10 deprecated generic `where` forms.
   - 9 key-path method/init/subscript cases.
   - 7 `using` declarations.
   - 6 `dependsOn` / nonescapable type cases.
   - 6 inline-array expression-count cases.
   - 5 accessor/coroutine variants.
   - 3 `@_specialize` / SIL-ish constraints.
   - 3 literal-with-trailing-closure cases.
   - 3 SwiftSyntax recovery-leniency cases.
   - Singletons: protocol members / associatedtype `where`, dynamic-replacement subscript spelling,
     `reasync`/`rethrows`, dollar identifiers, non-breaking-space trivia.

   First work item: classify and fix the 60 SwiftSyntax reference mismatches. Likely causes include
   fragment parser entry points, experimental feature flags, and recovery-mode fixtures. Do not mark
   them disabled; either teach the 604 harness the correct SwiftSyntax parse context or record a real
   SwiftSyntax/compiler disagreement.

---

## Maintenance Rule

- Add new markdown TODOs here and link back to source context when needed.
- `Advent/codex.md` and `Advent/claude.md` should reference this file instead of maintaining separate TODO lists.
