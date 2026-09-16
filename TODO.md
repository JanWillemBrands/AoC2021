# This file is the canonical TODO list in this project.

11. **preserving trivia** needs a round-trip test

12. **wider tests on Swift 6.4** test all swift-syntax sources files for equivalence.

1. Wrong accepts: condition trailing closures
   • testTrailingClosureInIfCondition#1
   • testTrailingClosureInGuard#1...#4
   • Also related tree failures: testTrailingClosureInIfCondition#1...#3
   • High value: correctness failure, clustered root.

2. Accessor/init accessor ambiguity
   • testVariableDeclarations#9
   • testInitAccessor#3/#4
   • testInitAccessorsWithDefaultValues#1
   • testYield#1/#3/#4
   • testRecovery165/#166, testSemicolon6, testTrailingSemi5
   • Biggest cluster. Likely one grammar/Ast-builder root.

3. String interpolation / unterminated string handling
   • testNewlineInInterpolationOfSingleLineString#1
   • testUnterminatedString4#1
   • testUnterminatedString5#1
   • Plus string ambiguity cases.
   • Correctness, and likely scanner/string-mode boundary issue.

4. Module selector in binding/pattern positions
   • testModuleSelectorIncorrectBindingDecls#7/#8/#9
   • testModuleSelectorType#7
   • Correctness. Needs careful grammar containment, not a broad ban.

5. Regex / slash disambiguation leftovers
   • testForwardSlashRegex116#1
   • testForwardSlashRegex142#1
   • testForwardSlashRegexSkippingAllowed11#1
   • testPrefixSlash4#1
   • Important but risky; touch after cleaner structural buckets.

6. Literal with trailing closure
   • testLiteralWithTrailingClosure#4
   • testLiteralWithTrailingClosure#6
   • Narrow, correctness-focused. Might share suffix/call eligibility logic.

7. Top-level enum case / enum tree mismatches
   • testEnum11#1
   • testEnum70#1
   • testEnum72#1
   • Probably declaration-position containment.

8. ABI attribute ambiguity
   • testABIAttribute#7/#19
   • Pure ambiguity, likely small grammar disambiguation.

9. Single correctness stragglers
   • testSelfRebinding2#1
   • Handle after bigger reject clusters.

10. Low-priority tree-only mismatches
• testInitCallInPoundIf#1
• testDiagnoseAvailability18#1
• Other isolated tree diffs.
• Leave last unless they fall out of earlier fixes.---

## Maintenance Rule

- Add new markdown TODOs here and link back to source context when needed.
- `Advent/codex.md` and `Advent/claude.md` should reference this file instead of maintaining separate TODO lists.
