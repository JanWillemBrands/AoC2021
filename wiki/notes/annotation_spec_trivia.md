# Trivia Annotation Spec (Edge Form)

Date: 2026-04-25

## Scope

3-character annotations for trivia constraints.
Place annotation on edge between symbols only.
Never attach before/after token text.

## Base Set

1. `>~<` no constraint
2. `>s<` no trivia between A and B (adjacent)
3. `>n<` no newline between A and B (same line)
4. `>+<` horizontal space required between A and B
5. `>#<` newline required between A and B
6. `<?>` symmetric horizontal spacing around operator context

## Derived Shorthand

1. `<s>` both sides adjacency (expands to two `>s<` edges)
2. `<+>` both sides horizontal space (expands to two `>+<` edges)
3. `<n>` both sides same line (expands to two `>n<` edges)

## Examples

```apus
tryOperator = "try" >s< "?" | "try" >s< "!" | "try" .
typeCastingOperator = "as" >s< "?" type | "as" >s< "!" type | "as" type .
forcedValueExpression = postfixExpression >s< "!" .
optionalChainingExpression = postfixExpression >s< "?" .
```

## Usage Policy

1. annotation declares intent
2. oracle predicate enforces behavior
3. optional parser gating only after proof
