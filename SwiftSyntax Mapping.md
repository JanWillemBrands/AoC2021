# APUS Swift Grammar → SwiftSyntax Mapping

This document maps nonterminals/terminals in `Swift.apus` to their SwiftSyntax
node types, and describes the incremental plan for building an AST converter.

## Architecture

```
Swift source text
  ├─→ SwiftParser.Parser.parse()       → SwiftSyntax tree (reference)
  └─→ Scanner → MessageParser → Oracle
                                   ↓
                        BSR yields on GrammarNodes
                            ╱               ╲
               DerivationBuilder         SwiftSyntaxGenerator
               (ParseTreeNode trees)     (SwiftSyntax trees)
               for diagram rendering     for comparison with reference
               (Graphviz .gv)            (memberwise inits)
```

Key components:
- `DerivationBuilder` (GenerateDerivationDiagram.swift) — walks BSR yields on
  GrammarNodes, produces `ParseTreeNode` trees for diagram rendering. Two modes:
  - `buildAllTrees()` — enumerates all derivations (ambiguous grammars)
  - `buildAST()` — single deterministic tree (after Oracle disambiguation),
    reports residual ambiguity diagnostics
- `SwiftSyntaxGenerator` (GenerateSwiftSyntaxAST.swift) — walks BSR yields
  directly on GrammarNodes, constructs SwiftSyntax trees using memberwise inits.
  Completely decoupled from DerivationBuilder. Assumes all ambiguity resolved.
- `ParseTreeNode` — tree node used by diagram rendering only.

### Operator folding

SwiftParser produces flat `SequenceExprSyntax` nodes — it does NOT fold operators
by precedence at parse time. `OperatorTable.foldAll()` (SwiftOperators) is a
separate post-parse step that restructures into `InfixOperatorExprSyntax`.

Advent's grammar also has no operator precedence — `infixExpressions` is a flat
right-recursive list at the same nonterminal level for all operators.
`SwiftSyntaxGenerator` flattens this right recursion into a flat `ExprListSyntax`,
matching SwiftParser's unfolded output exactly. No precedence logic needed.

## Construction Approach

Use **memberwise initializers** on SwiftSyntax types, not result builders or
string interpolation. Builders are for hand-writing known structure; memberwise
inits are for programmatic tree-to-tree conversion.

```swift
// Example: "let x = 42"
VariableDeclSyntax(
    bindingSpecifier: .keyword(.let),
    bindings: PatternBindingListSyntax([
        PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(identifier: .identifier("x")),
            initializer: InitializerClauseSyntax(
                equal: .equalToken(),
                value: IntegerLiteralExprSyntax(literal: .integerLiteral("42"))
            )
        )
    ])
)
```

## Incremental Phases

### Phase 1 — Literals & Simple Declarations
`let x = 42`, `let s = "hello"`, `var b = true`, `let n: Int? = nil`

| APUS nonterminal | SwiftSyntax type |
|---|---|
| `constantDeclaration` | `VariableDeclSyntax` (.let) |
| `variableDeclaration` | `VariableDeclSyntax` (.var) |
| `patternInitializerList` | `PatternBindingListSyntax` |
| `patternInitializer` | `PatternBindingSyntax` |
| `initializer` | `InitializerClauseSyntax` |
| `identifierPattern` | `IdentifierPatternSyntax` |
| `typeAnnotation` | `TypeAnnotationSyntax` |
| `typeIdentifier` | `IdentifierTypeSyntax` |
| `integerLiteral` | `IntegerLiteralExprSyntax` |
| `booleanLiteral` | `BooleanLiteralExprSyntax` |
| `nilLiteral` | `NilLiteralExprSyntax` |
| `stringLiteral` | `StringLiteralExprSyntax` |

### Phase 2 — Binary Expressions (flat sequences, no folding)
`1 + 2 * 3`, `x == 0 ? "zero" : "nonzero"`, `value as? Int`

| APUS nonterminal | SwiftSyntax type | Notes |
|---|---|---|
| `expression` + `infixExpressions` | `SequenceExprSyntax` | flatten right recursion to flat ExprList |
| `infixOperator` | `BinaryOperatorExprSyntax` | element in flat sequence |
| `conditionalOperator` | `UnresolvedTernaryExprSyntax` | element in flat sequence |
| `typeCastingOperator` (as) | `UnresolvedAsExprSyntax` + `TypeExprSyntax` | two elements in flat sequence |
| `typeCastingOperator` (is) | `UnresolvedIsExprSyntax` + `TypeExprSyntax` | two elements in flat sequence |
| `prefixExpression` (with op) | `PrefixOperatorExprSyntax` | |
| `postfixExpression` | various | `ForceUnwrapExprSyntax`, `OptionalChainingExprSyntax`, etc. |

### Phase 3 — Functions, Calls, Control Flow
`func f(x: Int) -> Int { ... }`, `f(x: 42)`, `if`/`for`/`while`/`switch`

| APUS nonterminal | SwiftSyntax type |
|---|---|
| `functionDeclaration` | `FunctionDeclSyntax` |
| `parameterClause` | `FunctionParameterClauseSyntax` |
| `parameter` | `FunctionParameterSyntax` |
| `functionResult` | `ReturnClauseSyntax` |
| `functionCallExpression` | `FunctionCallExprSyntax` |
| `functionCallArgument` | `LabeledExprSyntax` |
| `trailingClosures` | `MultipleTrailingClosureElementListSyntax` |
| `closureExpression` | `ClosureExprSyntax` |
| `forInStatement` | `ForStmtSyntax` |
| `whileStatement` | `WhileStmtSyntax` |
| `repeatWhileStatement` | `RepeatStmtSyntax` |
| `ifStatement` / `ifExpression` | `IfExprSyntax` |
| `guardStatement` | `GuardStmtSyntax` |
| `switchStatement` / `switchExpression` | `SwitchExprSyntax` |
| `returnStatement` | `ReturnStmtSyntax` |
| `breakStatement` | `BreakStmtSyntax` |
| `throwStatement` | `ThrowStmtSyntax` |
| `deferStatement` | `DeferStmtSyntax` |
| `doStatement` | `DoStmtSyntax` |

### Phase 4 — Type Declarations, Generics, Patterns
`struct`, `class`, `enum`, `protocol`, generics, pattern matching

| APUS nonterminal | SwiftSyntax type |
|---|---|
| `structDeclaration` | `StructDeclSyntax` |
| `classDeclaration` | `ClassDeclSyntax` |
| `enumDeclaration` | `EnumDeclSyntax` |
| `actorDeclaration` | `ActorDeclSyntax` |
| `protocolDeclaration` | `ProtocolDeclSyntax` |
| `extensionDeclaration` | `ExtensionDeclSyntax` |
| `genericParameterClause` | `GenericParameterClauseSyntax` |
| `genericWhereClause` | `GenericWhereClauseSyntax` |
| `typeInheritanceClause` | `InheritanceClauseSyntax` |

## Full Nonterminal → SwiftSyntax Mapping

### Declarations

| APUS | SwiftSyntax | Notes |
|---|---|---|
| `topLevelDeclaration` | `SourceFileSyntax` | children: `CodeBlockItemListSyntax` |
| `codeBlock` | `CodeBlockSyntax` | |
| `statements` | `CodeBlockItemListSyntax` | |
| `importDeclaration` | `ImportDeclSyntax` | |
| `constantDeclaration` | `VariableDeclSyntax` | `bindingSpecifier: .keyword(.let)` |
| `variableDeclaration` | `VariableDeclSyntax` | `bindingSpecifier: .keyword(.var)` |
| `functionDeclaration` | `FunctionDeclSyntax` | |
| `enumDeclaration` | `EnumDeclSyntax` | union + raw-value both map here |
| `structDeclaration` | `StructDeclSyntax` | |
| `classDeclaration` | `ClassDeclSyntax` | |
| `actorDeclaration` | `ActorDeclSyntax` | |
| `protocolDeclaration` | `ProtocolDeclSyntax` | |
| `extensionDeclaration` | `ExtensionDeclSyntax` | |
| `initializerDeclaration` | `InitializerDeclSyntax` | |
| `deinitializerDeclaration` | `DeinitializerDeclSyntax` | |
| `subscriptDeclaration` | `SubscriptDeclSyntax` | |
| `typealiasDeclaration` | `TypeAliasDeclSyntax` | |
| `operatorDeclaration` | `OperatorDeclSyntax` | |
| `precedenceGroupDeclaration` | `PrecedenceGroupDeclSyntax` | |
| `macroDeclaration` | `MacroDeclSyntax` | |

### Expressions

| APUS | SwiftSyntax | Notes |
|---|---|---|
| `expression` | `ExprSyntax` (protocol) | |
| `prefixExpression` | `PrefixOperatorExprSyntax` | |
| `infixExpression` | `SequenceExprSyntax` → fold → `InfixOperatorExprSyntax` | |
| `assignmentOperator` | `AssignmentExprSyntax` | |
| `conditionalOperator` | `TernaryExprSyntax` | |
| `typeCastingOperator` (as) | `AsExprSyntax` | |
| `typeCastingOperator` (is) | `IsExprSyntax` | |
| `tryOperator` | `TryExprSyntax` | |
| `awaitOperator` | `AwaitExprSyntax` | |
| `inOutExpression` | `InOutExprSyntax` | |
| `integerLiteral` | `IntegerLiteralExprSyntax` | |
| `decimalFloatingPointLiteral` | `FloatLiteralExprSyntax` | |huh?
| `stringLiteral` | `StringLiteralExprSyntax` | |
| `booleanLiteral` | `BooleanLiteralExprSyntax` | |
| `nilLiteral` | `NilLiteralExprSyntax` | |
| `regularExpressionLiteral` | `RegexLiteralExprSyntax` | |
| `arrayLiteral` | `ArrayExprSyntax` | |
| `dictionaryLiteral` | `DictionaryExprSyntax` | |
| `closureExpression` | `ClosureExprSyntax` | |
| `functionCallExpression` | `FunctionCallExprSyntax` | |
| `subscriptExpression` | `SubscriptCallExprSyntax` | |
| `tupleExpression` / `parenthesizedExpression` | `TupleExprSyntax` | |
| `selfExpression` | `DeclReferenceExprSyntax` | name = "self" |
| `superclassExpression` | `SuperExprSyntax` | |
| `ifExpression` | `IfExprSyntax` | |
| `switchExpression` | `SwitchExprSyntax` | |
| `keyPathExpression` | `KeyPathExprSyntax` | |
| `explicitMemberExpression` | `MemberAccessExprSyntax` | |
| `implicitMemberExpression` | `MemberAccessExprSyntax` | base = nil |
| `forcedValueExpression` | `ForceUnwrapExprSyntax` | |
| `optionalChainingExpression` | `OptionalChainingExprSyntax` | |
| `wildcardExpression` | `DiscardAssignmentExprSyntax` | |
| `macroExpansionExpression` | `MacroExpansionExprSyntax` | or `MacroExpansionDeclSyntax` |

### Statements

| APUS | SwiftSyntax | Notes |
|---|---|---|
| `forInStatement` | `ForStmtSyntax` | |
| `whileStatement` | `WhileStmtSyntax` | |
| `repeatWhileStatement` | `RepeatStmtSyntax` | |
| `ifStatement` | `IfExprSyntax` | SwiftSyntax treats as expr |
| `guardStatement` | `GuardStmtSyntax` | |
| `switchStatement` | `SwitchExprSyntax` | SwiftSyntax treats as expr |
| `breakStatement` | `BreakStmtSyntax` | |
| `continueStatement` | `ContinueStmtSyntax` | |
| `fallthroughStatement` | `FallThroughStmtSyntax` | |
| `returnStatement` | `ReturnStmtSyntax` | |
| `throwStatement` | `ThrowStmtSyntax` | |
| `deferStatement` | `DeferStmtSyntax` | |
| `doStatement` | `DoStmtSyntax` | |
| `labeledStatement` | `LabeledStmtSyntax` | |
| `conditionalCompilationBlock` | `IfConfigDeclSyntax` | treated as decl |
| `lineControlStatement` | `PoundSourceLocationSyntax` | |

### Types

| APUS | SwiftSyntax | Notes |
|---|---|---|
| `typeIdentifier` | `IdentifierTypeSyntax` / `MemberTypeSyntax` | member if dot-qualified |
| `tupleType` | `TupleTypeSyntax` | |
| `functionType` | `FunctionTypeSyntax` | |
| `arrayType` | `ArrayTypeSyntax` | |
| `dictionaryType` | `DictionaryTypeSyntax` | |
| `optionalType` | `OptionalTypeSyntax` | |
| `implicitlyUnwrappedOptionalType` | `ImplicitlyUnwrappedOptionalTypeSyntax` | |
| `protocolCompositionType` | `CompositionTypeSyntax` | |
| `opaqueType` / `boxedProtocolType` | `SomeOrAnyTypeSyntax` | |
| `metatypeType` | `MetatypeTypeSyntax` | |
| `anyType` | `IdentifierTypeSyntax` | name = "Any" |
| `selfType` | `IdentifierTypeSyntax` | name = "Self" |

### Patterns

| APUS | SwiftSyntax |
|---|---|
| `wildcardPattern` | `WildcardPatternSyntax` |
| `identifierPattern` | `IdentifierPatternSyntax` |
| `valueBindingPattern` | `ValueBindingPatternSyntax` |
| `tuplePattern` | `TuplePatternSyntax` |
| `enumCasePattern` | `ExpressionPatternSyntax` |
| `expressionPattern` | `ExpressionPatternSyntax` |
| `isPattern` | `IsTypePatternSyntax` |

## Terminal → TokenKind Mapping

| APUS Terminal | SwiftSyntax TokenKind | Notes |
|---|---|---|
| `plainIdentifier` | `.identifier` | |
| `escapedIdentifier` | `.identifier` | backtick-stripped |
| `implicitParameterName` | `.dollarIdentifier` | |
| `propertyWrapperProjection` | `.dollarIdentifier` | |
| `decimalNumber` | `.integerLiteral` | |
| `binaryLiteral` | `.integerLiteral` | |
| `octalLiteral` | `.integerLiteral` | |
| `hexadecimalLiteral` | `.integerLiteral` | |
| `decimalFloatingPointLiteral` | `.floatLiteral` | |
| `hexadecimalFloatingPointLiteral` | `.floatLiteral` | |
| `singlelineStringLiteral` | `.stringQuote` + segments | complex structure |
| `multilineStringLiteral` | `.multilineStringQuote` + segments | complex structure |
| `plainRegularExpressionLiteral` | `.regexSlash` + pattern | |
| `plainOperator` / `dotOperator` | `.binaryOperator` / `.prefixOperator` / `.postfixOperator` | context-dependent |
| `attributeMarker` | `.atSign` + `.identifier` | SwiftSyntax splits these |
| `macroIdentifier` | `.pound` + `.identifier` | SwiftSyntax splits these |
| keywords (`"if"`, `"let"`, etc.) | `.keyword(.if)`, `.keyword(.let)`, etc. | |

## Key Structural Differences

1. **Operator sequences are flat**: Both SwiftParser and Advent produce flat
   operator sequences (no precedence at parse time). SwiftParser uses flat
   `SequenceExprSyntax`; Advent has right-recursive `infixExpressions`.
   `SwiftSyntaxGenerator` flattens the right recursion to match.
   `OperatorTable.foldAll()` can fold later if needed, but is not used for
   structural comparison.

2. **if/switch are expressions**: SwiftSyntax uses `IfExprSyntax` and
   `SwitchExprSyntax`. Advent has both statement and expression variants.

3. **Intermediate nonterminals collapse**: Advent's `unionStyleEnum` vs
   `rawValueStyleEnum` both map to `EnumDeclSyntax`. Advent's
   `selfMethodExpression` / `selfSubscriptExpression` / `selfInitializerExpression`
   all map to `MemberAccessExprSyntax` on a `self` base.

4. **Tokens**: SwiftSyntax has `TokenSyntax` with a `.tokenKind` enum (~150 cases).
   Advent's 23 APUS terminals map into these, sometimes splitting (e.g.
   `@attribute` → `.atSign` + `.identifier`).

5. **Trivia**: SwiftSyntax attaches leading/trailing trivia (whitespace, comments)
   to every token. Advent's scanner strips whitespace and comments as trivia.
   For structural comparison, trivia can be ignored.

---

## Consolidated learnings (from agent memory, 2026-07-30)

### Disambiguation strategy — encode swift's decisions from its SOURCE, not from failing tests

(Endorsed 2026-07-21.) Swift's grammar is inherently ambiguous; swift-syntax
(hand-written recursive descent) hides it by **committing** at each fork via
unbounded lookahead + a finite documented decision set. A GLL parser surfaces EVERY
derivation, so those procedural decisions become ours to make **declaratively**.
Reactive per-test `@prefer`/`@longest` never converges — there's no shared model of
"which reading wins and why." Three pillars:

1. **Contextual-keyword discipline (~80 words).** Ground truth = swift-syntax
   `Keyword` enum entries with `isLexerClassified == false`. Each is an identifier by
   default; its keyword-productions are gated to EXACTLY swift's positions.
   Hard keywords use `---(…)` exclusion; contextual keywords need the INVERSE —
   allowed as identifiers, keyword-reading suppressed outside its site.
2. **The ≈32 `canParseAsXxx` / `atStartOfXxx` predicates.** Ground truth =
   SwiftParser's `Lookahead` predicates (`canParseType`, `atStartOfDeclaration`,
   `atValidTrailingClosure`, …). Each is a commitment point — encode with directional
   structured lookahead (`>+> >-> <+< <-<`) + structural grammar fixes at its site.
   (The `@unless(X)` predicate that once served this role was retired 2026-07-30.)
3. **Over-generality audit.** Every production must match swift's position-specific
   reachability (keyPath root → member-free simple type, not full `type`; `⚽` via
   faithful code-point classes, not coarse `\p{So}`).

This makes the grammar correct for constructs we have no test for, and converts an
open-ended patch stream into a finite porting task (~80 + ~32 items).

### Tight-`(` rule is NARROW (probe with `hasError`, not `swiftc`)

Requires tight `(` (space → `hasError`): **type specifiers with args**
(`nonisolated(nonsending)`, `dependsOn(...)`) and **`@attribute` arg clauses**
(`@available (*)`, `@convention (c)` reject). Allows a space (do NOT add `>s<`):
`private (set)`, `unowned (safe)`, `nonisolated (unsafe)` **decl modifier**,
`#available (..)`, `f (1)` calls, `yield (x)`. The three `nonisolated(...)` positions
have different valid arg-sets: type specifier = `nonsending` only (tight);
decl modifier = {`unsafe`,`nonsending`} (space OK); conformance = bare only. Bare
`nonisolated` as a type specifier binds a function type only
(`type = "nonisolated" functionType`).

### Reserved operator tokens

TSPL: `=`, `->`, `//`, `/*`, `*/`, `.`, and the unary prefix `&` are reserved — can't
be overloaded or used in custom operators. Grammar consequence: bare `&` must NOT be
in the overloadable `operator` production (not merely excluded from `prefixOperator`).
It has exactly two roles: prefix inout (`inOutExpression = "&" primaryExpression`) and
infix bitwise-and. Treating `&` as a general `prefixOperator` makes `&Y` double-parse
(prefixOperator + inOutExpression) — the root of the `[X] & [Y]` pivot cluster.
