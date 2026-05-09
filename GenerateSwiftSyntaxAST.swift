//
//  GenerateSwiftSyntaxAST.swift
//  Advent
//
//  Walks BSR yields on GrammarNodes to construct SwiftSyntax trees directly.
//  Assumes all ambiguity has been resolved by the Oracle — exactly one path
//  through the yields exists.
//

import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - SwiftSyntax Tree Generator

struct SwiftSyntaxGenerator {
    let grammar: Grammar
    let tokens: [Token]

    private var endCache = [NodePos: Set<TokenPosition>]()
    private var endGuard = Set<NodePos>()

    private struct NodePos: Hashable { let id: ObjectIdentifier; let from: TokenPosition }

    init(grammar: Grammar, tokens: [Token]) {
        self.grammar = grammar
        self.tokens = tokens
    }

    mutating func generate() -> SourceFileSyntax? {
        let n = TokenPosition(token: tokens.count - 1)
        guard grammar.root.yield.contains(where: { $0.i == .zero && $0.j == n }) else {
            return nil
        }
        let items = convertNonterminal(grammar.root, from: .zero, to: n)
        return SourceFileSyntax(
            statements: CodeBlockItemListSyntax(items.map { CodeBlockItemSyntax(item: $0) }),
            endOfFileToken: .endOfFileToken()
        )
    }

    // MARK: - BSR Navigation (decoupled from DerivationBuilder)

    private mutating func endPositions(_ sym: GrammarNode, from: TokenPosition) -> Set<TokenPosition> {
        let key = NodePos(id: ObjectIdentifier(sym), from: from)
        if let cached = endCache[key] { return cached }
        guard endGuard.insert(key).inserted else { return [] }
        defer { endGuard.remove(key) }

        let result: Set<TokenPosition>
        switch sym.kind {
        case .T, .TI, .C, .B:
            result = Set(sym.yield.lazy.filter { $0.k == from }.map(\.j))
        case .N:
            guard let lhs = sym.alt else { return [] }
            result = Set(lhs.yield.lazy.filter { $0.i == from }.map(\.j))
        case .DO, .OPT, .KLN, .POS:
            var positions = Set<TokenPosition>()
            if sym.kind == .KLN || sym.kind == .OPT { positions.insert(from) }
            if sym.kind.isClosure {
                var visited = Set<TokenPosition>()
                var queue = [from]
                var index = 0
                while index < queue.count {
                    let pos = queue[index]
                    index += 1
                    guard visited.insert(pos).inserted else { continue }
                    for end in iterationEndPositions(sym, from: pos) where end > pos {
                        positions.insert(end)
                        queue.append(end)
                    }
                }
            } else {
                positions.formUnion(iterationEndPositions(sym, from: from))
            }
            result = positions
        case .EPS:
            result = [from]
        default:
            result = []
        }
        endCache[key] = result
        return result
    }

    private mutating func iterationEndPositions(_ bracket: GrammarNode, from: TokenPosition) -> Set<TokenPosition> {
        var positions = Set<TokenPosition>()
        var alt = bracket.alt
        while let a = alt {
            var frontier: Set<TokenPosition> = [from]
            var consumedSymbol = false
            for sym in a.bodySymbols where sym.kind != .EPS {
                consumedSymbol = true
                frontier = frontier.reduce(into: Set()) { $0.formUnion(endPositions(sym, from: $1)) }
                if frontier.isEmpty { break }
            }
            positions.formUnion(consumedSymbol ? frontier : [from])
            alt = a.alt
        }
        return positions
    }

    /// Find the single matching alternate and tile its body over [from..to].
    /// Relies on the Oracle postcondition: exactly one alternate matches.
    private mutating func tileAlternate(_ node: GrammarNode, from: TokenPosition, to: TokenPosition) -> (alt: GrammarNode, spans: [(GrammarNode, TokenPosition, TokenPosition)])? {
        var alt = node.alt
        while let a = alt {
            defer { alt = a.alt }
            if let spans = tileBody(a.bodySymbols, from: from, to: to) {
                return (a, spans)
            }
        }
        return nil
    }

    private mutating func tileBody(_ symbols: [GrammarNode], from: TokenPosition, to: TokenPosition) -> [(GrammarNode, TokenPosition, TokenPosition)]? {
        var spans: [(GrammarNode, TokenPosition, TokenPosition)] = []
        return tileBody(symbols, index: 0, from: from, to: to, into: &spans) ? spans : nil
    }

    private mutating func tileBody(_ symbols: [GrammarNode], index: Int, from: TokenPosition, to: TokenPosition, into spans: inout [(GrammarNode, TokenPosition, TokenPosition)]) -> Bool {
        guard index < symbols.count else { return from == to }
        let symbol = symbols[index]
        if symbol.kind == .EPS {
            return tileBody(symbols, index: index + 1, from: from, to: to, into: &spans)
        }
        for mid in endPositions(symbol, from: from) where mid <= to {
            let restoreCount = spans.count
            spans.append((symbol, from, mid))
            if tileBody(symbols, index: index + 1, from: mid, to: to, into: &spans) {
                return true
            }
            spans.removeSubrange(restoreCount..<spans.count)
        }
        return false
    }

    /// Resolve a nonterminal reference (RHS .N) to its LHS definition.
    private func lhs(_ sym: GrammarNode) -> GrammarNode? {
        sym.kind == .N ? sym.alt : nil
    }

    /// Get token text at a position.
    private func tokenText(at pos: TokenPosition) -> String {
        guard tokens.indices.contains(pos.tokenIndex) else { return "" }
        return String(tokens[pos.tokenIndex].image)
    }

    // MARK: - Top-level dispatch

    /// Convert a nonterminal spanning [from..to] into CodeBlockItem elements.
    private mutating func convertNonterminal(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> [CodeBlockItemSyntax.Item] {
        let lhsNode = nt.kind == .N && nt.seq == nil ? nt : lhs(nt) ?? nt
        switch lhsNode.name {
        case "topLevelDeclaration":
            return convertTopLevelDeclaration(lhsNode, from: from, to: to)
        default:
            return []
        }
    }

    // MARK: - Statements

    private mutating func convertTopLevelDeclaration(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> [CodeBlockItemSyntax.Item] {
        // topLevelDeclaration = statements? .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let stmtsNT = find("statements", in: spans) else { return [] }
        return convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to)
    }

    private struct NTSpan {
        let nt: GrammarNode
        let from: TokenPosition
        let to: TokenPosition
    }

    /// Search through brackets to find a nonterminal by name within a span.
    /// Only digs through brackets (OPT, DO, KLN, POS), NOT through non-matching nonterminals.
    private mutating func findNonterminal(named name: String, sym: GrammarNode, from: TokenPosition, to: TokenPosition) -> NTSpan? {
        if from == to && (sym.kind == .OPT || sym.kind == .KLN) { return nil }
        switch sym.kind {
        case .N:
            let def = lhs(sym) ?? sym
            if def.name == name { return NTSpan(nt: def, from: from, to: to) }
        case .DO, .OPT, .KLN, .POS:
            if let (_, spans) = tileAlternate(sym, from: from, to: to) {
                return find(name, in: spans)
            }
        default:
            break
        }
        return nil
    }

    private mutating func find(_ name: String, in spans: [(GrammarNode, TokenPosition, TokenPosition)]) -> NTSpan? {
        for (sym, from, to) in spans {
            if let found = findNonterminal(named: name, sym: sym, from: from, to: to) {
                return found
            }
        }
        return nil
    }

    private mutating func convertStatements(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> [CodeBlockItemSyntax.Item] {
        // statements = statement statementSeparator statements? .
        // statements = statement .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else { return [] }
        var items: [CodeBlockItemSyntax.Item] = []
        if let stmtNT = find("statement", in: spans),
           let item = convertStatement(stmtNT.nt, from: stmtNT.from, to: stmtNT.to) {
            items.append(item)
        }
        if let stmtsNT = find("statements", in: spans) {
            items.append(contentsOf: convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to))
        }
        return items
    }

    private mutating func convertStatement(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> CodeBlockItemSyntax.Item? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else { return nil }
        if let declNT = find("declaration", in: spans),
           let decl = convertDeclaration(declNT.nt, from: declNT.from, to: declNT.to) {
            return .decl(decl)
        }
        if let exprNT = find("expression", in: spans) {
            return .expr(convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to))
        }
        return nil
    }

    // MARK: - Declarations

    private mutating func convertDeclaration(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> DeclSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else { return nil }
        if let constNT = find("constantDeclaration", in: spans) {
            return DeclSyntax(convertVarLetDecl(constNT.nt, from: constNT.from, to: constNT.to, isLet: true))
        }
        if let varNT = find("variableDeclaration", in: spans) {
            return DeclSyntax(convertVarLetDecl(varNT.nt, from: varNT.from, to: varNT.to, isLet: false))
        }
        return nil
    }

    private mutating func convertVarLetDecl(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition, isLet: Bool) -> VariableDeclSyntax {
        // constantDeclaration = attributes? declarationModifiers? "let" patternInitializerList .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return VariableDeclSyntax(bindingSpecifier: .keyword(isLet ? .let : .var), bindings: [])
        }
        let bindings = find("patternInitializerList", in: spans).map {
            convertPatternInitializerList($0.nt, from: $0.from, to: $0.to)
        } ?? []
        return VariableDeclSyntax(
            bindingSpecifier: .keyword(isLet ? .let : .var),
            bindings: PatternBindingListSyntax(bindings)
        )
    }

    private mutating func convertPatternInitializerList(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> [PatternBindingSyntax] {
        // patternInitializerList = patternInitializer | patternInitializer "," patternInitializerList .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else { return [] }
        var bindings: [PatternBindingSyntax] = []
        for (sym, f, t) in spans {
            let name = directName(sym)
            if name == "patternInitializer", let def = lhs(sym) {
                bindings.append(convertPatternInitializer(def, from: f, to: t))
            }
            if name == "patternInitializerList", let def = lhs(sym) {
                bindings.append(contentsOf: convertPatternInitializerList(def, from: f, to: t))
            }
        }
        if bindings.count > 1 {
            for i in 0..<bindings.count - 1 {
                bindings[i] = bindings[i].with(\.trailingComma, .commaToken())
            }
        }
        return bindings
    }

    /// Get the direct nonterminal name of a symbol (no recursive digging).
    private func directName(_ sym: GrammarNode) -> String? {
        if sym.kind == .N { return lhs(sym)?.name ?? sym.name }
        return nil
    }

    private mutating func convertPatternInitializer(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> PatternBindingSyntax {
        // patternInitializer = bindingPattern initializer? .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: .identifier("?")))
        }
        var pattern: PatternSyntax = PatternSyntax(IdentifierPatternSyntax(identifier: .identifier("?")))
        var typeAnnotation: TypeAnnotationSyntax? = nil
        var initializer: InitializerClauseSyntax? = nil

        if let bpNT = find("bindingPattern", in: spans) {
            let (pat, ta) = convertBindingPattern(bpNT.nt, from: bpNT.from, to: bpNT.to)
            pattern = pat
            typeAnnotation = ta
        }
        if let initNT = find("initializer", in: spans) {
            initializer = convertInitializer(initNT.nt, from: initNT.from, to: initNT.to)
        }
        return PatternBindingSyntax(
            pattern: pattern,
            typeAnnotation: typeAnnotation,
            initializer: initializer
        )
    }

    private mutating func convertBindingPattern(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> (PatternSyntax, TypeAnnotationSyntax?) {
        // bindingPattern = identifierPattern typeAnnotation? .
        // (also: wildcardPattern typeAnnotation?, tuplePattern typeAnnotation?)
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return (PatternSyntax(IdentifierPatternSyntax(identifier: .identifier("?"))), nil)
        }
        var pattern: PatternSyntax = PatternSyntax(IdentifierPatternSyntax(identifier: .identifier("?")))
        var typeAnnotation: TypeAnnotationSyntax? = nil

        if let idNT = find("identifierPattern", in: spans) {
            let name = collectTerminalText(from: idNT.from, to: idNT.to)
            pattern = PatternSyntax(IdentifierPatternSyntax(identifier: .identifier(name)))
        }
        if let taNT = find("typeAnnotation", in: spans) {
            typeAnnotation = convertTypeAnnotation(taNT.nt, from: taNT.from, to: taNT.to)
        }
        return (pattern, typeAnnotation)
    }

    private mutating func convertTypeAnnotation(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> TypeAnnotationSyntax? {
        // typeAnnotation = ":" attributes? "inout"? type .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let typeNT = find("type", in: spans) else { return nil }
        return TypeAnnotationSyntax(
            colon: .colonToken(),
            type: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
        )
    }

    private mutating func convertInitializer(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> InitializerClauseSyntax? {
        // initializer = "=" expression .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let exprNT = find("expression", in: spans) else { return nil }
        return InitializerClauseSyntax(
            equal: .equalToken(),
            value: convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
        )
    }

    // MARK: - Expressions

    private mutating func convertExpression(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> ExprSyntax {
        // expression = tryOperator? awaitOperator? prefixExpression infixExpressions? .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return ExprSyntax(MissingExprSyntax())
        }

        guard let prefNT = find("prefixExpression", in: spans) else {
            return ExprSyntax(MissingExprSyntax())
        }
        let operand = convertPrefixExpression(prefNT.nt, from: prefNT.from, to: prefNT.to)

        if let infSpan = find("infixExpressions", in: spans) {
            var elements: [ExprSyntax] = [operand]
            flattenInfixExpressions(infSpan.nt, from: infSpan.from, to: infSpan.to, into: &elements)
            return ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(elements)))
        }

        return operand
    }

    private mutating func flattenInfixExpressions(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition, into elements: inout [ExprSyntax]) {
        // infixExpressions = infixExpression infixExpressions? .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else { return }
        for (sym, f, t) in spans {
            if let ieNT = findNonterminal(named: "infixExpression", sym: sym, from: f, to: t) {
                flattenInfixExpression(ieNT.nt, from: ieNT.from, to: ieNT.to, into: &elements)
            }
            if let nextNT = findNonterminal(named: "infixExpressions", sym: sym, from: f, to: t) {
                flattenInfixExpressions(nextNT.nt, from: nextNT.from, to: nextNT.to, into: &elements)
            }
        }
    }

    private mutating func flattenInfixExpression(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition, into elements: inout [ExprSyntax]) {
        // infixExpression = infixOperator prefixExpression .
        // infixExpression = conditionalOperator .
        // infixExpression = typeCastingOperator .
        // infixExpression = assignmentOperator tryOperator? awaitOperator? prefixExpression .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else { return }

        for (sym, f, t) in spans {
            if let opNT = findNonterminal(named: "infixOperator", sym: sym, from: f, to: t) {
                let opText = collectTerminalText(from: opNT.from, to: opNT.to)
                elements.append(ExprSyntax(BinaryOperatorExprSyntax(operator: .binaryOperator(opText))))
            }
            if let condNT = findNonterminal(named: "conditionalOperator", sym: sym, from: f, to: t) {
                elements.append(convertConditionalOperator(condNT.nt, from: condNT.from, to: condNT.to))
            }
            if let castNT = findNonterminal(named: "typeCastingOperator", sym: sym, from: f, to: t) {
                convertTypeCastingOperator(castNT.nt, from: castNT.from, to: castNT.to, into: &elements)
            }
            if let prefNT = findNonterminal(named: "prefixExpression", sym: sym, from: f, to: t) {
                elements.append(convertPrefixExpression(prefNT.nt, from: prefNT.from, to: prefNT.to))
            }
        }
    }

    private mutating func convertConditionalOperator(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> ExprSyntax {
        // conditionalOperator = "?" expression ":" .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return ExprSyntax(MissingExprSyntax())
        }
        let thenExpr = find("expression", in: spans).map {
            convertExpression($0.nt, from: $0.from, to: $0.to)
        } ?? ExprSyntax(MissingExprSyntax())
        return ExprSyntax(UnresolvedTernaryExprSyntax(
            questionMark: .infixQuestionMarkToken(),
            thenExpression: thenExpr,
            colon: .colonToken()
        ))
    }

    private mutating func convertTypeCastingOperator(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition, into elements: inout [ExprSyntax]) {
        // typeCastingOperator = "is" type .
        // typeCastingOperator = "as" type .
        // typeCastingOperator = "as" "?" type .
        // typeCastingOperator = "as" "!" type .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else { return }

        let firstToken = tokenText(at: from)
        if firstToken == "as" {
            elements.append(ExprSyntax(UnresolvedAsExprSyntax(asKeyword: .keyword(.as))))
        } else if firstToken == "is" {
            elements.append(ExprSyntax(UnresolvedIsExprSyntax(isKeyword: .keyword(.is))))
        }

        if let typeNT = find("type", in: spans) {
            let type = convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
            elements.append(ExprSyntax(TypeExprSyntax(type: type)))
        }
    }

    private mutating func convertPrefixExpression(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> ExprSyntax {
        // prefixExpression = prefixOperator? postfixExpression .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return ExprSyntax(MissingExprSyntax())
        }

        var prefixOp: String? = nil

        for (sym, f, t) in spans {
            if sym.kind.isTerminal && f < t {
                let text = tokenText(at: f)
                if !text.isEmpty { prefixOp = text }
            }
            if sym.kind == .OPT && f < t {
                let text = collectTerminalText(from: f, to: t)
                if !text.isEmpty { prefixOp = text }
            }
        }

        guard let postNT = find("postfixExpression", in: spans) else {
            return ExprSyntax(MissingExprSyntax())
        }
        let operand = convertPostfixExpression(postNT.nt, from: postNT.from, to: postNT.to)

        if let op = prefixOp {
            return ExprSyntax(PrefixOperatorExprSyntax(
                operator: .prefixOperator(op),
                expression: operand
            ))
        }
        return operand
    }

    private mutating func convertPostfixExpression(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> ExprSyntax {
        // postfixExpression = primaryExpression postfixOperation* .
        // For Phase 1+2, just dig through to primaryExpression
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let primNT = find("primaryExpression", in: spans) else {
            return ExprSyntax(MissingExprSyntax())
        }
        return convertPrimaryExpression(primNT.nt, from: primNT.from, to: primNT.to)
    }

    private mutating func convertPrimaryExpression(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return ExprSyntax(MissingExprSyntax())
        }
        if let litNT = find("literalExpression", in: spans) {
            return convertLiteralExpression(litNT.nt, from: litNT.from, to: litNT.to)
        }
        if let idNT = find("identifier", in: spans) {
            let name = collectTerminalText(from: idNT.from, to: idNT.to)
            return ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
        }
        return ExprSyntax(MissingExprSyntax())
    }

    // MARK: - Literals

    private mutating func convertLiteralExpression(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let litNT = find("literal", in: spans) else {
            return ExprSyntax(MissingExprSyntax())
        }
        return convertLiteral(litNT.nt, from: litNT.from, to: litNT.to)
    }

    private mutating func convertLiteral(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return ExprSyntax(MissingExprSyntax())
        }
        if let numNT = find("numericLiteral", in: spans) {
            return convertNumericLiteral(numNT.nt, from: numNT.from, to: numNT.to)
        }
        if let boolNT = find("booleanLiteral", in: spans) {
            let text = collectTerminalText(from: boolNT.from, to: boolNT.to)
            return ExprSyntax(BooleanLiteralExprSyntax(
                literal: .keyword(text == "true" ? .true : .false)
            ))
        }
        if find("nilLiteral", in: spans) != nil {
            return ExprSyntax(NilLiteralExprSyntax())
        }
        if let strNT = find("stringLiteral", in: spans) {
            return convertStringLiteral(strNT.nt, from: strNT.from, to: strNT.to)
        }
        return ExprSyntax(MissingExprSyntax())
    }

    private mutating func convertNumericLiteral(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> ExprSyntax {
        // numericLiteral = signedIntegerLiteral | signedFloatingPointLiteral .
        // For now, collect all terminal text and decide based on content
        let text = collectTerminalText(from: from, to: to)
        if text.contains(".") || text.contains("e") || text.contains("E") || text.contains("p") || text.contains("P") {
            return ExprSyntax(FloatLiteralExprSyntax(literal: .floatLiteral(text)))
        }
        return ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral(text)))
    }

    private mutating func convertStringLiteral(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> ExprSyntax {
        // Collect all text between quotes
        let fullText = collectTerminalText(from: from, to: to)
        // SwiftSyntax models string literals with quote tokens and segment lists.
        // For simple single-line strings, build the full structure.
        if fullText.hasPrefix("\"") && fullText.hasSuffix("\"") {
            let content = String(fullText.dropFirst().dropLast())
            return ExprSyntax(StringLiteralExprSyntax(
                openingQuote: .stringQuoteToken(),
                segments: StringLiteralSegmentListSyntax([
                    .stringSegment(StringSegmentSyntax(
                        content: .stringSegment(content)
                    ))
                ]),
                closingQuote: .stringQuoteToken()
            ))
        }
        // Fallback: just use the raw text
        return ExprSyntax(StringLiteralExprSyntax(
            openingQuote: .stringQuoteToken(),
            segments: StringLiteralSegmentListSyntax([
                .stringSegment(StringSegmentSyntax(content: .stringSegment(fullText)))
            ]),
            closingQuote: .stringQuoteToken()
        ))
    }

    // MARK: - Types

    private mutating func convertType(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> TypeSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return TypeSyntax(MissingTypeSyntax())
        }
        if let optNT = find("optionalType", in: spans) {
            return convertOptionalType(optNT.nt, from: optNT.from, to: optNT.to)
        }
        if let typeIdNT = find("typeIdentifier", in: spans) {
            return convertTypeIdentifier(typeIdNT.nt, from: typeIdNT.from, to: typeIdNT.to)
        }
        let text = collectTerminalText(from: from, to: to)
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier(text)))
    }

    private mutating func convertTypeIdentifier(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> TypeSyntax {
        let name = collectTerminalText(from: from, to: to)
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier(name)))
    }

    private mutating func convertOptionalType(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition) -> TypeSyntax {
        // optionalType = type "?" .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let typeNT = find("type", in: spans) else {
            return TypeSyntax(MissingTypeSyntax())
        }
        return TypeSyntax(OptionalTypeSyntax(
            wrappedType: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to),
            questionMark: .postfixQuestionMarkToken()
        ))
    }

    // MARK: - Terminal Text Collection

    private func collectTerminalText(from: TokenPosition, to: TokenPosition) -> String {
        var texts: [String] = []
        var pos = from
        while pos < to {
            if tokens.indices.contains(pos.tokenIndex) {
                let text = String(tokens[pos.tokenIndex].image)
                if !text.isEmpty { texts.append(text) }
            }
            pos = TokenPosition(token: pos.tokenIndex + 1)
        }
        return texts.joined()
    }
}
