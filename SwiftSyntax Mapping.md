# APUS Swift Grammar → SwiftSyntax Mapping

This document maps nonterminals/terminals in `Swift.apus` to their SwiftSyntax
node types, and describes the incremental plan for building an AST converter.

## Architecture

```
Swift source text
  ├─→ SwiftParser.Parser.parse()       → SwiftSyntax tree (reference)
  └─→ Scanner → MessageParser → Oracle
                                   ↓
                           DerivationBuilder.buildAST()
                                   ↓
                            ParseTreeNode tree
                            ╱               ╲
                  diagram rendering    SwiftSyntax converter
                  (Graphviz .gv)       (memberwise inits)
                                              ↓
                                    SwiftSyntax tree (Advent)
                                              ↓
                                    compare with reference
```

Key components:
- `DerivationBuilder` (GenerateDerivationDiagram.swift) — walks BSR yields on
  GrammarNodes, produces `ParseTreeNode` trees. Two modes:
  - `buildAllTrees()` — enumerates all derivations (ambiguous grammars)
  - `buildAST()` — single deterministic tree (after Oracle disambiguation),
    reports residual ambiguity diagnostics
- `ParseTreeNode` — unified tree node used by both diagram rendering and
  SwiftSyntax conversion. Fields: name, token, from/to positions, children,
  isAmbiguous, isMissing.
- `OperatorTable.foldAll()` (SwiftOperators) — applies operator precedence to
  `SequenceExprSyntax` nodes. SwiftParser produces flat sequences; Advent's
  grammar has explicit precedence. Use fold on the reference side before compare.

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

### Phase 2 — Binary Expressions & Operator Folding
`1 + 2 * 3`, `x == 0 ? "zero" : "nonzero"`, `value as? Int`

| APUS nonterminal | SwiftSyntax type | Notes |
|---|---|---|
| `infixExpression` | `SequenceExprSyntax` → fold → `InfixOperatorExprSyntax` | use `OperatorTable.foldAll()` on reference |
| `assignmentOperator` | `AssignmentExprSyntax` | post-fold |
| `conditionalOperator` | `TernaryExprSyntax` | post-fold |
| `typeCastingOperator` (as) | `AsExprSyntax` | post-fold |
| `typeCastingOperator` (is) | `IsExprSyntax` | post-fold |
| `prefixExpression` | `PrefixOperatorExprSyntax` | |
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

1. **Operator folding**: SwiftParser produces flat `SequenceExprSyntax`.
   `OperatorTable.foldAll()` restructures into `InfixOperatorExprSyntax`,
   `TernaryExprSyntax`, etc. Advent's grammar has explicit precedence via
   nonterminal structure. Compare post-fold.

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
