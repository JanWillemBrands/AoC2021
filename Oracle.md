# Oracle: BSR Disambiguation

The oracle is a post-parse disambiguator. The GLL parser is permissive — it
finds ALL valid derivations and records them as BSR yield sets. The oracle
then narrows the forest to a single tree.

Two phases:

1. **Prune dead wood** — walk BSR top-down from root, remove yields not on
   any complete derivation path.
2. **Disambiguate** — apply grammar-annotated rules to choose among
   genuinely ambiguous alternatives.

After phase 1, every surviving yield participates in at least one complete
derivation. Phase 2 can safely prune without destroying the only valid parse.

## Three Flavors of Ambiguity

After dead-wood pruning, all remaining yields are productive. Ambiguity means
a grammar node has multiple ways to participate in complete derivations. At
the BSR level, this comes in exactly three flavors.

### Flavor 1: Different Extent

Same start position `i`, different end position `j`. The nonterminal can
parse different lengths from the same starting point.

```
@longest paragraph = < sentence > <n> .

Input:
    Something. Another thing.
    Sleep.
```

The `paragraph` nonterminal starting at "Something" has two productive yields:

    (i=3, k=3, j=8)   — two sentences: "Something. Another thing."
    (i=3, k=3, j=10)  — three sentences: "Something. Another thing. Sleep."

For LHS nonterminals, `k` always equals `i`, so the only variation is in `j`.

**Resolved by**: `@shortest` / `@longest` match annotations. These select
the minimum or maximum `j` per start position `i`.

### Flavor 2: Different Pivot

Same span `(i, j)`, different pivot `k`. The same extent has multiple internal
decompositions — different ways to split a sequence between sibling symbols.

```
E = E "+" E | "x" .

Input: x + x + x
```

The `< E >` closure (or the RHS `E` reference in the body) has yields with
the same `(i, j)` but different `k` values:

    (i=0, k=2, j=4)  — first E covers [0,2], "+" at 2, second E covers [3,4]
    (i=0, k=4, j=4)  — first E covers [0,4], then nothing remains

These represent `(x+x)+x` vs `x+(x+x)` — different binary decompositions
of the same span.

For closures, different `k` means different iteration boundaries. For body
sequences, it means different split points between siblings.

**Resolved by**: precedence and associativity annotations (future).
Left-associative keeps the leftmost pivot; right-associative keeps the
rightmost.

### Flavor 3: Alternate Ambiguity

Same span, same yields, but multiple alternates can derive it. This is
invisible at the LHS yield level — the nonterminal has just one yield entry
`(i, i, j)`. The ambiguity only surfaces when walking the body symbols and
finding that multiple alternates can tile the span.

```
statement = ifStatement | expressionStatement .
ifStatement = "if" expression block .
expressionStatement = expression ";" .

// Where both alternates can derive the same span
```

Or more commonly in expression grammars:

```
E = E "+" E | E "*" E | "x" .

Input: x + x * x
```

`E` has one yield `(0, 0, 4)`. Both the `"+"` and `"*"` alternates can
derive this span, but with different operator trees. The ambiguity is between
alternates, not between extents or pivots of a single alternate.

**Resolved by**: preference and reject annotations (future). Preference
explicitly ranks alternates. Reject removes derivations matching a forbidden
pattern.

## Exhaustiveness

These three flavors are exhaustive. Any two distinct parse trees for the same
input must differ in at least one of:

- how far some nonterminal extends (flavor 1)
- how some sequence is split between siblings (flavor 2)
- which alternate is chosen at some nonterminal (flavor 3)

All other forms of ambiguity reduce to compositions of these:

- **Epsilon ambiguity** (nullable nonterminal either derives empty or not):
  manifests as flavor 1 (different extent) or flavor 2 (different pivot).
- **Cyclic ambiguity** (`A = A | "x"` — infinitely many trees): degenerate
  flavor 3 with recursive alternates.
- **Schrodinger ambiguity** (same position, different token kinds): scanner-
  level variant. By the time BSR yields exist, it manifests as flavor 3
  (different alternates match because different token duals were used).

## Grammar Annotations

Disambiguation strategies are declared in the grammar using pragma syntax:

```apus
@shortest paragraph = < sentence > <n> .
@longest block     = "{" < statement > "}" .
```

The pragma appears before the production identifier. The oracle reads
`GrammarNode.disambiguation` and auto-creates the corresponding rule.

Currently implemented:

| Pragma       | Rule            | Flavor | Effect                        |
|-------------|-----------------|--------|-------------------------------|
| `@shortest` | ShortestMatchRule | 1      | Keep minimum `j` per start `i` |
| `@longest`  | LongestMatchRule  | 1      | Keep maximum `j` per start `i` |

Future annotations for flavors 2 and 3:

| Annotation          | Flavor | Effect                              |
|---------------------|--------|-------------------------------------|
| `@left` / `@right`  | 2      | Associativity — leftmost/rightmost pivot |
| `>`                  | 2+3    | Relative priority separator (tighter binds lower) |
| `@prefer` / `@avoid`| 3      | Prefer/reject specific alternates   |

## Operator Precedence

Operator precedence is a distinct problem from BSR disambiguation. The
distinction depends on the grammar shape.

### Left-Recursive Grammars: Precedence as BSR Ambiguity

A left-recursive expression grammar creates genuine parsing ambiguity:

```apus
E = E "+" E | E "*" E | "x" .

Input: x + x * x
```

This produces multiple BSR yields — different pivots (flavor 2) and
competing alternates (flavor 3). The Oracle resolves these by pruning
yields. The surviving yields naturally produce a correctly nested tree.
No tree reshaping needed.

This is how SDF/Rascal, yacc/bison, and most academic formalisms work.
Precedence is encoded in the grammar, ambiguity is real, and the
disambiguator selects the correct parse.

The `>` priority separator is the natural annotation for this shape:

```apus
expression
    = expression "||" expression        @left
    > expression "&&" expression        @left
    > expression "==" expression
    > expression "+" expression         @left
    | expression "-" expression
    > expression "*" expression         @left
    | expression "/" expression
    > prefixExpression
    .
```

`|` groups same-precedence alternates, `>` separates priority levels
(tighter binding as you read down). Priority is **relative** — determined
by position in the grammar text, not by absolute numbers. Adding a level
means inserting a line, not renumbering.

### Flat-Chain Grammars: Precedence as Tree Folding

A flat-chain grammar produces **no parsing ambiguity**:

```apus
infixExpressions = infixExpression infixExpressions? .
infixExpression = infixOperator prefixExpression .
```

For `a + b * c`, there is exactly one parse — a right-recursive chain
`a (+ b (* c))`. Each `infixExpression` grabs one operator and one
operand. No ambiguous pivots, no competing alternates. The Oracle has
nothing to prune.

To produce a precedence-respecting binary tree (`a + (b * c)`), a
**structural transformation** is needed — not BSR pruning. This is a
tree-folding step that takes the flat derivation and reshapes it based
on precedence metadata.

### How Swift Does It

Swift uses the flat-chain approach with a three-stage pipeline:

```
Source → Parser → flat SequenceExprSyntax → SwiftOperators folding → InfixOperatorExprSyntax tree
```

1. **Parser** produces `SequenceExprSyntax` — a flat list:
   `[expr, op, expr, op, expr, ...]`. No tree, no precedence.

2. **SwiftOperators** (a separate library in the swift-syntax package)
   folds that flat sequence into a binary tree of
   `InfixOperatorExprSyntax` nodes, each with `leftOperand`, `operator`,
   `rightOperand`. This is a tree transformation, not disambiguation.

3. Precedence groups form a **DAG** (not a total order) via relative
   `higherThan` / `lowerThan` declarations:

   | Group                        | Associativity |
   |------------------------------|---------------|
   | BitwiseShiftPrecedence       | none          |
   | MultiplicationPrecedence     | left          |
   | AdditionPrecedence           | left          |
   | RangeFormationPrecedence     | none          |
   | CastingPrecedence            | left          |
   | NilCoalescingPrecedence      | right         |
   | ComparisonPrecedence         | none          |
   | LogicalConjunctionPrecedence | left          |
   | LogicalDisjunctionPrecedence | left          |
   | TernaryPrecedence            | right         |
   | AssignmentPrecedence         | right         |

Swift chose this design because operators are user-definable — precedence
must be data, not grammar structure.

### How Other Systems Do It

| System       | Grammar shape   | Precedence encoding          | Mechanism          |
|--------------|-----------------|------------------------------|--------------------|
| **yacc/bison** | left-recursive | `%left`/`%right` declaration order | parser conflict resolution |
| **SDF/Rascal** | left-recursive | `>` separator + `left`/`right` | post-parse filter  |
| **ANTLR**    | left-recursive  | ordered alternatives (first wins) | PEG-style          |
| **tree-sitter** | left-recursive | `prec.left(N)` / `prec.right(N)` | GLR conflict resolution |
| **Swift**    | flat chain      | `precedencegroup` DAG        | post-parse folding |

Notable: yacc, SDF, and Swift all use **relative** priority — declared by
ordering or by `higherThan`/`lowerThan` relations, not absolute numbers.
Only tree-sitter uses numeric levels, and that's widely considered a
weakness of its design (fragile, hard to compose).

### Where This Fits in APUS

The Oracle handles BSR disambiguation — flavors 1, 2, and 3 as described
above. For left-recursive expression grammars, the Oracle resolves
precedence directly via yield pruning.

For flat-chain grammars (like Swift.apus), precedence folding is a
**tree construction** concern, not a disambiguation concern. It belongs
in the swift-syntax generation phase — the code that builds the output
AST from the (already disambiguated) derivation. The pipeline:

```
GLL Parser → BSR yields → Oracle (disambiguate) → AST Generator (fold operators) → swift-syntax tree
```

The AST generator reads precedence metadata from the grammar (annotated
on operator alternates) and uses it during tree construction to fold flat
operator chains into correctly nested binary trees. This is the same
separation of concerns as swift-syntax: the parser and Oracle produce a
flat, unambiguous derivation; the AST generator reshapes it.

Precedence metadata on operator alternates, using relative ordering:

```apus
infixOperator
    = assignOperator          @right
    > ternaryOperator         @right
    > disjunctionOperator     @left
    > conjunctionOperator     @left
    > comparisonOperator
    > nilCoalescingOperator   @right
    > castingOperator         @left
    > rangeOperator
    > additionOperator        @left
    > multiplicationOperator  @left
    > bitwiseShiftOperator
    .
```

The `>` separator establishes relative priority — no numbers. The grammar
text itself is the precedence table, read top (loosest) to bottom
(tightest). `|` groups same-level alternates. Bare entries (no `@left` /
`@right`) have no associativity — same-level chaining is an error, like
Swift's `ComparisonPrecedence`.

### Summary

| Grammar shape   | Precedence mechanism       | Where it happens       |
|-----------------|----------------------------|------------------------|
| Left-recursive  | BSR yield pruning          | Oracle phase 2         |
| Flat chain      | Tree folding               | AST generation phase   |

Both use the same grammar annotations (`>` separator, `@left`/`@right`).
The difference is when the annotation is consumed — during disambiguation
or during tree construction.

## Architecture

```
Parser (permissive)
  │
  ▼
BSR yield sets on GrammarNodes
  │
  ▼
Oracle phase 1: prune dead wood (top-down reachability)
  │
  ▼
Oracle phase 2: disambiguate (grammar-annotated rules)
  │
  ▼
DerivationBuilder / SPPF extractor (unambiguous derivation)
  │
  ▼
AST generator (fold flat operator chains using precedence metadata)
  │
  ▼
swift-syntax-style AST
```

The oracle operates entirely on `Set<BinarySpan>` — no tree construction.
After the oracle, the derivation is unambiguous. The AST generator then
builds the output tree, applying operator folding for flat-chain grammars
where precedence is structural, not a parsing ambiguity.

## See Also

- `Trivia Oracle.md` — boundary constraint design (`>s<`, `<n>`, etc.)
- `Oracle.swift` — implementation
- `GenerateDerivationDiagram.swift` — derivation tree visualization
  (ambiguous nodes shown with red outline)
