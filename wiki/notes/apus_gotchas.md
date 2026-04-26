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
