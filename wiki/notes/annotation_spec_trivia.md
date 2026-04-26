# Trivia Annotation Spec (Edge Form)

Date: 2026-04-25

## Scope

3-character annotations for trivia constraints.
Place annotation on edge between symbols only.
Never attach before/after token text.

## Base Set

1. `>~<` no constraint
2. `>:<` no trivia between A and B (adjacent)
3. `>.<` no newline between A and B (same line)
4. `>+<` horizontal space required between A and B
5. `>#<` newline required between A and B
6. `<?>` symmetric horizontal spacing around operator context

## Derived Shorthand

1. `<:>` both sides adjacency (expands to two `>:<` edges)
2. `<+>` both sides horizontal space (expands to two `>+<` edges)
3. `<.>` both sides same line (expands to two `>.<` edges)

## Examples

```apus
tryOperator = "try" >:< "?" | "try" >:< "!" | "try" .
typeCastingOperator = "as" >:< "?" type | "as" >:< "!" type | "as" type .
forcedValueExpression = postfixExpression >:< "!" .
optionalChainingExpression = postfixExpression >:< "?" .
```

## Usage Policy

1. annotation declares intent
2. oracle predicate enforces behavior
3. optional parser gating only after proof
