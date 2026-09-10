# APUS Gotchas

Date: 2026-04-26

Hard-won knowledge. These will burn you if you forget.

## Comments are `//`, NOT `#`

APUS uses `//` for line comments. The `#` character is not recognized and causes a scan error at position 0. This is easy to forget when writing Python grammars (which use `#` for comments in the language being parsed, but `//` in the .apus file).

## `^^^` blocks capture everything between markers

The message extraction regex grabs everything between `^^^` markers. If you put comments between `^^^` blocks, those comments become part of the message content. The parser then tries to parse them as message input and fails.

Bad:
```
^^^x + 1
// this comment becomes part of the NEXT message
^^^y + 2
```

Good:
```
^^^x + 1
^^^y + 2
```

## Named terminals can't be referenced by name in rules

`shift - />>/.` defines a terminal named "shift" matching `>>`. But in production rules you must write `">>"`, not `shift`. Named terminals exist to give the scanner a pattern — they don't create grammar symbols you can reference.

## OSLog output is invisible from CLI

All Logger calls go to the unified logging system, not stdout/stderr. To see them:
```bash
/usr/bin/log show --last 30s --info --debug --no-pager --predicate 's="com.magenta.apusParser"' 2>&1 | head -100
```
Use full path `/usr/bin/log` — zsh has a builtin `log` that conflicts. All interpolations use `privacy: .public` so content is visible.

## Always build before running

Never trust stale DerivedData. The Debug binary path:
`/Users/janwillem/Library/Developer/Xcode/DerivedData/Advent-ctnlmtxiyxptaedefnxgsxptokfx/Build/Products/Debug/Advent`

## Annotation Placement Is Typed

Update: 2026-09-09

Do not treat `pragma` as a free-floating grammar symbol. The implementation has
position-typed annotation families:

- Oracle preferences: `@prefer` / `@avoid` at alternate start; `@longest` /
  `@shortest` / `@left` / `@right` before an LHS or bracket group.
- Oracle constraints: `@confinedTo` / `@excludedFrom` at alternate start, plus
  `@canParse` / `@cannotParse` with nonterminal operands.
- Sequence predicates: layout boundaries today, and token lookaround after the
  `.B` boundary migration.
- Terminal pragmas: `@lexicalClass`, `@preempt`, and `@builder` on
  terminal-like definitions.

The coherent target is that token lookaround (`>+>`, `>->`, `<+<`, `<-<`) becomes
a zero-width sequence predicate in the same placement class as `<s>`, `>s<`,
`<n>`, and `>n<`. Symbolic lookaround is for tokens; Oracle parse predicates are
the `@word(...)` form.

Implementation note: token lookaround in production bodies is now represented as
structured `.B` boundary nodes; the old factor-attached `followAhead` /
`followAheadExclude` path has been removed. Terminal-definition `<+<` / `<-<`
has also been removed; put token lookaround in the production body at the exact
cursor position it constrains.

Token lookahead EOF behavior is explicit: use `EOF` in the operand set. Do not
infer EOF from the boundary's placement.
