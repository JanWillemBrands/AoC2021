# Schrodinger vs Frankenstein Boundary

Date: 2026-04-25

## Schrodinger

Problem:

- same span, equal length, multiple token kinds

Mechanism:

- keep dual chain on token
- parser walks duals
- `---` suppresses known-bad duals in context

Placement:

- parser-level (not oracle)

## Frankenstein

Problem:

- one longest-match token must be consumed in pieces

Mechanism:

- packed token position (`tokenIndex + charOffset`)
- parser consumes token remainder by offset

Placement:

- parser-level (not oracle)

## Why Not Oracle

Oracle cannot recover derivations never built.
If lexical alternatives or token splits are removed before parser, BSR/CRF paths are gone.

## Practical Boundary Rule

1. lexical admissibility/completeness -> parser/scanner
2. candidate disambiguation policy -> oracle
