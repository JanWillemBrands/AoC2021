# Trivia Oracle Decisions

Date: 2026-04-25

## Core Decision

Default path:

1. parser stays permissive
2. oracle enforces trivia constraints
3. parser gating added later only with proof

Reason: avoid false pruning and lost derivations.

## Placement by Mechanism

1. Parser-level
- Frankenstein partial-token matching
- Schrodinger dual-token ambiguity
- `---` exclusion set checks

2. Scanner-level
- scanner mode stack (`>>>`, `===`, `<<<`)

3. Oracle-level (new work)
- whitespace/newline-sensitive validity
- context-sensitive trivia disambiguation
- precedence/associativity post-disambiguation for flat expression chains

## Promotion Rule (Oracle -> Parser)

Promote a trivia rule only if all pass:

1. same predicate implementation is reused
2. corpus comparison shows no valid parse loss
3. ambiguous accepted-set equivalence holds
4. debug switch can disable parser gating

## Practical Rule-of-Thumb

1. If rule is lexical admissibility: parser/scanner.
2. If rule is disambiguation policy on existing candidates: oracle.
3. If uncertain: oracle first.
