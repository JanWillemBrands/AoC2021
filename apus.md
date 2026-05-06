# APUS Language Reference

APUS is grammar language. You write grammar, parser read grammar, parser parse things.

APUS describe itself. Grammar file called `apus.apus`. Self-describing. Very elegant. Like snake eating tail.

Name come from *Apus apus* — the common swift. Bird that never land. Parser that never stop.

## Grammar File

Grammar file have two parts: productions, then messages.

```swift
grammar = < production > { message } .
```

First come productions. One or more. They define terminals and rules. Then come messages — zero or more test inputs, each starting with `^^^`.

Every production end with `.` — the full stop. You forget the dot, parser angry.

## Comments

```swift
// this is a comment
```

Comments start with `//` and run to end of line. APUS does NOT use `#` for comments. The `#` character not an APUS token. You use `#`, scanner scream.

## Productions

Three kinds of production. All start with a name.

### Silent Terminal (`:`)

```swift
whitespace : /\s+/ .
comment    : /\/\/.*/  .
```

Colon mean silent terminal. Scanner match it, scanner throw it away. Good for whitespace, comments. Parser never see these tokens.

Right side is regex or literal. Then dot.

### Visible Terminal (`-`)

```swift
identifier - /\p{XID_Start}\p{XID_Continue}*/ .
literal    - /\"(?:[^\"\\]|\\.)+\"/ .
number     - /[0-9]+/ .
```

Dash mean visible terminal. Scanner match it, scanner keep it. Parser see these tokens. Use for identifiers, numbers, string literals — things with meaning.

Right side is regex or literal. Then dot.

A visible terminal can also be a literal:

```swift
fBrace - "{" .
```

This give the literal `{` a name. Now you can write `fBrace` in production rules instead of `"{"`. The terminal is still keyed by its literal content — the name is just an alias.

### Production Rule (`=`)

```swift
S = "hello" "world" .
```

Equals sign mean production rule. Left side is nonterminal name. Right side is what it expand to. Then dot.

First production rule in file is the start symbol. Parser start there.

Same nonterminal can have multiple definitions — they merge:

```swift
S = "x" .
S = "x" "x" .
S = "x" "x" "x" .
```

This make S match one, two, or three x's.

## Terminals in Rules

### Literals

```swift
S = "hello" "world" .
```

Double-quoted strings. Match exact text. Literals use Swift string escape conventions — `"\t"` match a tab, `"\\"` match a backslash, `"\/"` match a single slash.

### Regex

```swift
number - /[0-9]+/ .
```

Forward-slash delimited. Swift regex syntax inside. Use in terminal definitions (`:` or `-` productions). Can also appear inline in rules, but then they get an auto-generated name.

Named regex terminal can be referenced by name in rules:

```swift
shift - />>/ .
S = shift "other" .
```

Here `shift` in the rule resolve to the regex terminal.

### Identifiers

```swift
S = A B .
A = "a" .
B = "b" .
```

Bare name in a rule is either a nonterminal reference or a terminal reference. If the name was defined as a terminal (`:` or `-`), it resolve as terminal. Otherwise it is a nonterminal. Nonterminal get defined when it appear on the left side of `=`.

### Epsilon

Two ways to say nothing:

```swift
S = "a" | ε .
S = "a" | "" .
```

The Greek letter `ε` and the empty string literal `""` both mean epsilon — match zero tokens. Good for optional things.

## Selection (Alternation)

```swift
selection = sequence { "|" sequence } .
```

Vertical bar separate alternatives:

```swift
S = "a" | "b" | "c" .
```

S match `a` or `b` or `c`. GLL parser explore all alternatives — even ambiguous ones. This not LL(1) parser. This GLL. All paths explored.

## Sequence

```swift
sequence = < factor [ "?" | "*" | "+" ] > .
```

Things next to each other in a rule match in order:

```swift
S = "a" "b" "c" .
```

Match `a` then `b` then `c`.

## EBNF Brackets

APUS support four kinds of bracket:

### Grouping `( )`

```swift
S = "a" ( "b" | "c" ) "d" .
```

Parentheses group alternatives. Match `abd` or `acd`.

### Option `[ ]`

```swift
S = "a" [ "b" ] "c" .
```

Square brackets mean zero or one. Match `ac` or `abc`.

### Kleene Closure `{ }`

```swift
S = "a" { "b" } "c" .
```

Curly braces mean zero or more. Match `ac`, `abc`, `abbc`, `abbbc`, ...

### Positive Closure `< >`

```swift
S = "a" < "b" > "c" .
```

Angle brackets mean one or more. Match `abc`, `abbc`, `abbbc`, ... but NOT `ac`.

## Postfix Repetition Operators

Same three repetition ideas, but postfix style:

```swift
S = "a" "b"? "c" .     // "b" zero or one time
S = "a" "b"* "c" .     // "b" zero or more times
S = "a" "b"+ "c" .     // "b" one or more times
```

`?` is option, `*` is zero-or-more, `+` is one-or-more. Same as brackets but stick after a single factor. Good for compact rules.

## Messages (Test Inputs)

```swift
^^^
hello world
^^^
goodbye world
```

Triple caret `^^^` start a message block. Everything between `^^^` markers (or between `^^^` and end of file) is captured as test input. Parser use these to test the grammar.

Do NOT put comments between `^^^` blocks. Comments become part of message content. Message capture everything.

## Pragmas

```swift
S = @python-indent < statement > .
```

@-prefixed strings are pragmas — hints to the parser or code generator. They pass through the grammar without affecting parsing semantics.

## Actions

``` swift
S = 'init' "x" 'process' { "y" 'accumulate' } 'finalize' .
```

Single-quote delimited blocks are actions — code fragments attached to grammar positions. They are silent terminals (scanner strips them from the visible token stream) and get stored on grammar nodes for code generation.

Actions can appear before the first production (preamble), between the nonterminal name and `=` (signature), between grammar symbols, and after the last production (epilogue).

---

## Annotations

Annotations extend terminals and nonterminals with special behavior. They not change what the grammar matches — they guide the scanner and parser.

### Exclusion Sets `---()`

```swift
safeId = identifier ---("if" "while" "for" "return") .
```

Problem: scanner see `if` and produce two tokens of same length — keyword `if` and identifier `if`. These are Schrödinger tokens (same text, same length, different kinds). Parser explore both paths.

Sometimes you know: in this grammar position, `if` is NOT an identifier. The `---()` annotation say: suppress these specific Schrödinger duals here. Kill the bad branch locally.

The annotation go after an identifier (nonterminal or terminal reference) in a rule. List the literal values to exclude in parentheses.

### Frankenstein Split `~~~`

```swift
S = "x" | "<" Y .
Y = S ">" ~~~ .
```

Problem: scanner see `>>` and make one token. But sometimes `>>` is two `>` closing nested brackets:

```swift
Array<Dictionary<String, Int>>
                             ^^— two ">" not one ">>"
```

The `~~~` annotation after a literal say: this literal is allowed to match a PREFIX of a longer token. Parser can split the Frankenstein monster.

Scanner still produce `>>` as one token. But when parser reach `">" ~~~`, it is allowed to match just the first `>` and leave the second `>` as remainder for a later descriptor.

### Layout Tokens `>>|` and `|<<`

```swift
block = >>| < statement > |<< .
```

For indent-sensitive languages (Python, Haskell). These are synthetic tokens injected between scanning and parsing:

- `>>|` — indent (column increased on new line)
- `|<<` — dedent (column decreased on new line)

They appear unquoted in grammar rules. When the grammar uses them, the layout injection pass activates automatically. It tracks indentation levels and inserts `>>|` or `|<<` tokens into the token stream. Bracket pairs (configurable) suppress indent tracking inside them.

### Boundary Constraints `>s<` `<s>` `>n<` `<n>`

```swift
prefix_op = >s< operator .
binary_op = <s> operator .
same_line = >n< expression .
new_line  = <n> statement .
```

Spatial constraints between tokens (future — design complete, not yet enforced):

| Annotation | Meaning |
|------------|---------|
| `>s<` | Tokens must be adjacent (touching, no gap) |
| `<s>` | Tokens must NOT be adjacent |
| `>n<` | Tokens must be on the same line |
| `<n>` | Tokens must be on different lines |

These are predicates, not tokens. They consume no input. They check the spatial relationship between the previous and next token and abandon the parse path if violated.

### Scanner Modes `===` `<<<` `>>>`

```swift
multilineCommentHead : "/*" .
                     === "" >>> "multiline-comment"
                     === "multiline-comment" >>> "multiline-comment"

multilineCommentText : /(?s).*?(?=\/\*|\*\/)/ .
                     === "multiline-comment"

multilineCommentTail : "*/" .
                     === "multiline-comment" <<<
```

Scanner modes control which terminals are active at each point in the input. Stack-based, like ANTLR lexer modes.

A mode annotation is a **gated transition** — a structured triple:

- `=== "mode"` — gate: this terminal only participates when the scanner is in this mode
- `<<<` — pop: after matching, leave this mode
- `>>> "mode"` — push: after matching, enter this mode

The four shapes:

| Syntax | Meaning |
|--------|---------|
| `=== "X"` | Active only in mode X |
| `=== "X" >>> "Y"` | Active in X, enter Y after match |
| `=== "X" <<<` | Active in X, leave X after match |
| `=== "X" <<< >>> "Y"` | Active in X, replace X with Y after match |

Terminals without any `===` annotation are active in ALL modes. A terminal gated with `=== ""` is active only in the default mode.

One terminal can have multiple gated transitions — active in multiple modes with different actions:

```swift
fBraceOpen - "{" .
           === "fStr" >>> "fExpr"
           === "fSpec" >>> "fExpr"
           === "fExpr" >>> "fExpr"
```

Mode membership is pre-filter. Ineligible terminals not even try to match. Post-actions (pop/push) are unconditional — the gate already verified the stack. No rollback needed.

---

## Full Grammar

APUS defined in APUS:

```swift
whitespace  : /\s+/ .
comment     : /\/\/.*/  .

action      : /@(?:[^@\\]|\\.)+@/ .

identifier  - /\p{XID_Start}\p{XID_Continue}*/ .
literal     - /\"(?:[^\"\\]|\\.)+\"/ .
regex       - /\/(?!\*)(?:[^\/\\]|\\.)+\// .
pragma      - /'(?:[^'\n])*'/ .

message     - /\^\^\^(?:(?s).*?)(?=\^\^\^|$)/ .

grammar     = < production > { message } .

production  = identifier
                ( ":" ( regex | literal ) "." mode
                | "-" ( regex | literal ) "." mode
                | "=" selection "."
                ) .

selection   = sequence { "|" sequence } .

sequence    = < layout | factor [ "?" | "*" | "+" ] > .

factor      = terminal
            | "[" selection "]"
            | "{" selection "}"
            | "<" selection ">"
            | "(" selection ")"
            .

terminal    = identifier    [ "---" "(" < literal > ")" ]
            | literal       [ "~~~" ]
            | regex
            | epsilon | empty
            | pragma
            .

epsilon     = "ε" .
empty       = "\"\"" .

layout      = [ ">>|" | "|<<" | "<n>" | "<s>" | ">n<" | ">s<" ] .

mode        = { "===" name [ "<<<" ] [ ">>>" name ] } .
name        = literal | identifier .
```

## Sample Grammar

A small calculator language:

```swift
whitespace : /\s+/ .
comment    : /\/\/.*/  .

number - /[0-9]+/ .

expr = term { ( "+" | "-" ) term } .
term = atom { ( "*" | "/" ) atom } .
atom = number
     | "(" expr ")"
     .

^^^
1 + 2 * (3 + 4)
^^^
42
^^^
(1 + 2) * (3 + 4)
```
