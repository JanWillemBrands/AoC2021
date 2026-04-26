# Swift Trivia Inventory (Project Reference)

Date: 2026-04-25

This is the working inventory for parser/oracle trivia policy.

## A) Normative Swift Reference Rules

1. Whitespace includes spaces, tabs, vertical tabs, form feeds, newlines.
2. Comments are treated as whitespace.
3. Operator fixity depends on whitespace shape around operator.
4. Infix when whitespace on both sides OR neither side.
5. Prefix when whitespace only on left.
6. Postfix when whitespace only on right.
7. Postfix when no left whitespace and operator immediately followed by `.`.
8. Delimiters `(` `[` `{` count as left-side whitespace for classification.
9. Delimiters `)` `]` `}` `,` `:` `;` count as right-side whitespace.
10. `!` and `?` with no left whitespace are postfix even with right whitespace.
11. Ternary `? :` requires spaces around both `?` and `:`.
12. Infix operator before regex literal requires whitespace on both sides.
13. Generic/bracket contexts may require parser-context token splitting (`<`/`>` max-munch exceptions).

## B) Rules Tracked from Local `Swift.apus` Notes

1. No space between `try` and `?` / `!`.
2. No space between `as` and `?` / `!`.
3. No space before postfix `?` in optional chaining.
4. No space before postfix `!` in forced unwrap.
5. No space between type and `?` in optional type spelling.
6. No space before `(` in `unowned(safe)` / `unowned(unsafe)`.
7. No space between `@` and attribute name (scanner token policy).
8. `#sourceLocation(file:..., line:...)` observed flexible whitespace behavior.
9. Newline-sensitive contextual keyword behavior (example: `copy` discussion).

## C) Coverage Status

1. Inventory documented.
2. Annotation forms documented.
3. Oracle checks not yet implemented in runtime.

## D) Sources

1. Swift Book: Lexical Structure  
https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/ReferenceManual/LexicalStructure.md
2. Swift Book: Expressions  
https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/ReferenceManual/Expressions.md
3. Local grammar comments/TODOs: `Advent/Swift.apus`
