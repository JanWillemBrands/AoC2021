# Ambiguity Resolution: swift-syntax predicates ↔ Swift.apus annotations

Where swift-syntax (hand-written recursive descent) resolves Swift's inherent
ambiguity by **committing** at each fork with unbounded lookahead, a GLL parser
surfaces every derivation and must resolve the same forks **declaratively**. This
document cross-correlates swift-syntax's commitment predicates with the annotations
in `Swift.apus`, to convert an open-ended patch stream into a finite porting task and
to guide reduction of the residual reject/ambiguity failures.

## Method & caveat

- **Predicate list = ground truth** from the checked-out `SwiftParser` source
  (`Sources/SwiftParser/*.swift`, `grep` of `func canParse* / atStartOf* / isStartOf* /
  atAttributeOrSpecifier`), 37 methods minus 3 generic helpers (`withLookahead`,
  `atContextualPunctuator`, `atContextualKeywordPrefixedSyntax`) ≈ the "~32".
- **Status column is a structural assessment**, not a per-predicate test. Most
  predicates are NOT named gates in the grammar — they are handled by grammar shape +
  Oracle annotations. Calibrated by three signals: *cited by name* in a grammar
  comment (high confidence), *construct present*, *construct absent*.

## Annotation inventory (Swift.apus)

`@prefer`×59 · `@longest`×34 · `@shortest`×10 · `@avoid`×4 · structured lookahead
`>+>`×16 `<-<`×6 `>->`×5 `<+<`×0 · gates `>s<`×62 `<s>`×29 `>n<`×17 `<n>`×8 ·
`---(…)` exclusion ×11 · `@splitBefore`×5 · `@builder`×9.

## Annotation → predicate family (one line each)

- `atStartOf*` / `canParse*` commitment points → **structured lookahead** `>+> >-> <+< <-<`
  + structural fixes. The "◐ slightly off" rows are where the grammar parses the
  construct but the *commitment* still leaks a second reading — this is the residual
  reject/ambiguity frontier.
- position / tightness predicates (tight `(`, line-leading, no-newline `[`) → **gates**
  `>s< <s> >n< <n>`.
- same-span / extent forks (`preferRegexOverBinaryOperator`, metatype, arrays/dicts,
  accessors) → **`@prefer` / `@longest` / `@shortest`**.
- the ~80 contextual keywords (adjacent pillar) → **`---(…)`** exclusion.

## Correlation

Legend: ✅ complete (cited / faithfully modeled) · ◐ slightly off (construct present,
commitment leaks) · ✗ missing (construct absent).

### Types
| swift-syntax predicate | apus mechanism | status |
|---|---|---|
| `canParseType` | full `type` grammar; forks resolved structurally | ◐ |
| `canParseSimpleType` / `canParseTypeIdentifier` / `canParseTypeScalar` | `simpleType`/`typeIdentifier` | ✅ |
| `canParseSimpleOrCompositionType` | `compositionType` + `@longest` on `any P & Q` | ✅ |
| `canParseAsGenericArgumentList` / `canParseGenericArgument` | cited; `<…>`-as-generics + `@longest genericIdentifier` | ✅ |
| `canParseFunctionTypeArrow` | `functionType` + `@prefer parenthesizedExpression` | ◐ |
| `canParseTupleBodyType` | `tupleType`; tuple-type vs tuple-expr overlap | ◐ |
| `canParseCollectionTypeBody` | `arrayType`/`dictionaryType` + `@prefer expression` | ◐ |
| `canParseInlineArrayTypeBody` / `canParseStartOfInlineArrayTypeBody` | `inlineArray` (`[N of T]`) | ◐ |
| `canParseTypeAttributeList` | `typeAttribute` (thin — 1 site) | ◐ |
| `canParseBaseTypeForQualifiedDeclName` | no dedicated qualified-decl-name base | ✗ |

### Attributes / specifiers
| predicate | apus mechanism | status |
|---|---|---|
| `atAttributeOrSpecifier` | `attributes` + tight-`(` rule | ◐ |
| `canParseCustomAttribute` | `customAttribute`/`attributes` | ◐ |
| `canParseNonisolatedAsSpecifierInExpressionContext` | 3 `nonisolated` arg-sets (SwiftSyntax Mapping.md) | ◐ |

### Patterns / closures / labels
| predicate | apus mechanism | status |
|---|---|---|
| `canParsePattern` / `canParsePatternTuple` | `pattern`/`tuplePattern` + `@prefer expressionPattern` | ✅ |
| `canParseClosureSignature` | `closureSignature`/`closureParameterClause` | ◐ |
| `canParseArgumentLabelList` | cited; label-vs-expr at `(name:` | ◐ |
| `atStartOfLabelledTrailingClosure` | cited; `trailingClosureLabel = … ---("default" …)` | ✅ |
| `canParseIntegerLiteral` | `@longest numericLiteral` (versions, `.0` indices) | ◐ |

### Statement / declaration / expression forks
| predicate | apus mechanism | status |
|---|---|---|
| `atStartOfDeclaration` | cited; `statement = @prefer declaration` | ✅ |
| `atStartOfStatement` | cited; `>->("(" "[" ".")` + `atContextualKeywordPrefixedSyntax` (preferPostfixExpr) | ✅ |
| `atStartOfGetSetAccessor` | cited; `@prefer "{" accessorClauseList "}"` | ✅ |
| `atStartOfConditionalStatementBody` | `@longest functionBody` (greedy `{`-is-body) | ◐ |
| `atStartOfExpression` | structural + the statement fork | ◐ |
| `atStartOfPostfixExprSuffix` | postfix grammar + `>n<` (no-newline `[`/`(`) | ◐ |
| `atStartOfSwitchCase` / `atStartOfConditionalSwitchCases` | `switchCase` | ◐ |
| `atStartOfFreestandingMacroExpansion` | `macroExpansion*` | ◐ |
| `isStartOfReturnExpr` | `returnStatement`; regex-vs-return via operator gates | ◐ |
| `atStartOfActor` | no `actor` declaration | ✗ |
| `atStartOfUsing` | no `using` declaration (Swift 6.2) | ✗ |

### Tally (≈32)
- **✅ complete: 8** — generics list, `any P&Q`, decl-vs-stmt, stmt-start/preferPostfixExpr,
  get/set accessors, labelled-trailing-closure, pattern-expr, simple types.
- **◐ slightly off: 21** — most type predicates, closure signature, argument labels,
  macro/switch/return/conditional-body starts.
- **✗ missing: 3** — `atStartOfActor`, `atStartOfUsing`, `canParseBaseTypeForQualifiedDeclName`.

**Headline:** the expression-level commitment predicates (decl/stmt/accessor/generics/
trailing-closure) are the well-covered core; the type-system `canParse*Type*` family is
uniformly "slightly off" (grammar parses them, commitment leaks); the only outright holes
are two newer declaration forms (`actor`, `using`) and one niche qualified-name base.

## Residual reject/ambiguity frontier (79 rejects, 1 residual ambiguity)

The Oracle is unambiguous by construction; the "79" are `RejectSyntaxTests/adventRejects`
— inputs swift-syntax rejects that Advent still accepts (over-generality = a commitment
leak). Guided by the ◐ rows above, the reduction work is per-predicate: tighten each
"slightly off" construct so its second reading is unreachable at swift's position.

_(Analysis of the 79, categorised by predicate family, below — appended as worked.)_
