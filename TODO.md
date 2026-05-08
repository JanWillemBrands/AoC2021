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

4. Symmetric spacing boundary annotation: Swift requires balanced whitespace (both sides or neither) for infix operators. The ternary `?` needs this — `a? b : c` is postfix `a?` (not ternary), but our grammar currently accepts it as ternary since we only have `>s<` (no left space) and `<s>` (left space). Add a new boundary annotation (e.g. `<=>`) that checks for symmetric spacing to properly gate the ternary `? :` and potentially other infix operators.
Source: Swift Language Reference §Lexical Structure operator whitespace rules; `Swift.apus` conditionalOperator rule.

## TODO References Found In Markdown

These are TODO references, not standalone tasks, but included for completeness.

1. `Advent/Trivia Oracle.md`: "These are in `Swift.apus` comments/TODOs and should be modeled in oracle policy."
2. `Advent/Trivia Oracle.md`: "Local grammar notes/TODOs: `Advent/Swift.apus`"

## Maintenance Rule

- Add new markdown TODOs here and link back to source context when needed.
- `Advent/codex.md` and `Advent/claude.md` should reference this file instead of maintaining separate TODO lists.
