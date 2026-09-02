//
//  GenerateSwiftSyntaxAST.swift
//  Advent
//
//  Walks BSR yields to construct SwiftSyntax trees directly.
//  Assumes all ambiguity has been resolved by the Oracle — exactly one path
//  through the yields exists.
//

import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - SwiftSyntax Tree Generator

/// A place where the converter could not build the faithful node and fell back
/// to a `Missing…` placeholder or a raw-text approximation.
///
/// The two kinds must stay apart. `.unhandled` is a construct the converter
/// knowingly does not implement yet — expected, and the work queue for the next
/// phase. `.lookupFailed` is a rule the converter CLAIMS to handle failing to
/// yield the child it expected — a bug, in practice almost always a rule comment
/// that has drifted from `Swift.apus` (`optionalType = type "?"` vs the real
/// `optionalType = simpleType >s< optionalMark`).
///
/// Without the distinction a `MissingType` means either "not yet" or "wrong",
/// and the ~1617 `trees differ` labels can only be triaged by eyeball.
struct GeneratorDiagnostic: CustomStringConvertible {
    enum Kind: String { case unhandled, lookupFailed }
    let kind: Kind
    let function: String
    let reason: String
    let text: String

    var description: String { "\(kind.rawValue) in \(function): \(reason) — «\(text)»" }
}

struct SwiftSyntaxGenerator {
    let parser: MessageParser
    let grammar: Grammar
    let input: String

    /// Fallback sites hit during the last `generate()`. Empty means every node
    /// on the path was built from a rule the converter actually understands —
    /// which is NOT the same as the tree matching swift-syntax, but a non-empty
    /// list explains exactly why a tree cannot match.
    private(set) var diagnostics: [GeneratorDiagnostic] = []

    private var endCache = [NodePos: Set<CharPosition>]()
    private var endGuard = Set<NodePos>()

    private struct NodePos: Hashable { let id: ObjectIdentifier; let from: CharPosition }

    init(parser: MessageParser, input: String) {
        self.parser = parser
        self.grammar = parser.grammar
        self.input = input
    }

    mutating func generate() -> SourceFileSyntax? {
        diagnostics.removeAll()
        let n = input.endIndex
        let origin = input.startIndex
        guard parser.yield(of: grammar.root).contains(where: { $0.i == origin && $0.j == n }) else {
            return nil
        }
        let items = convertNonterminal(grammar.root, from: origin, to: n)
        return SourceFileSyntax(
            statements: CodeBlockItemListSyntax(items.map { CodeBlockItemSyntax(item: $0) }),
            endOfFileToken: .endOfFileToken()
        )
    }

    // MARK: - Fallback recording

    private mutating func record(
        _ kind: GeneratorDiagnostic.Kind,
        _ reason: String,
        from: CharPosition,
        to: CharPosition,
        function: String = #function
    ) {
        diagnostics.append(GeneratorDiagnostic(
            kind: kind,
            function: function,
            reason: reason,
            text: String(input[from..<to])
        ))
    }

    private mutating func missingExpr(
        _ kind: GeneratorDiagnostic.Kind,
        _ reason: String,
        from: CharPosition,
        to: CharPosition,
        function: String = #function
    ) -> ExprSyntax {
        record(kind, reason, from: from, to: to, function: function)
        return ExprSyntax(MissingExprSyntax())
    }

    private mutating func missingType(
        _ kind: GeneratorDiagnostic.Kind,
        _ reason: String,
        from: CharPosition,
        to: CharPosition,
        function: String = #function
    ) -> TypeSyntax {
        record(kind, reason, from: from, to: to, function: function)
        return TypeSyntax(MissingTypeSyntax())
    }

    /// Placeholder pattern for a binding whose pattern could not be built.
    private mutating func missingPattern(
        _ kind: GeneratorDiagnostic.Kind,
        _ reason: String,
        from: CharPosition,
        to: CharPosition,
        function: String = #function
    ) -> PatternSyntax {
        record(kind, reason, from: from, to: to, function: function)
        return PatternSyntax(IdentifierPatternSyntax(identifier: .identifier("?")))
    }

    // MARK: - BSR Navigation (decoupled from DerivationBuilder)

    private mutating func endPositions(_ sym: GrammarNode, from: CharPosition) -> Set<CharPosition> {
        let key = NodePos(id: ObjectIdentifier(sym), from: from)
        if let cached = endCache[key] { return cached }
        guard endGuard.insert(key).inserted else { return [] }
        defer { endGuard.remove(key) }

        let result: Set<CharPosition>
        switch sym.kind {
        case .T, .TI, .C, .B:
            result = Set(parser.yield(of: sym).lazy.filter { $0.k == from }.map(\.j))
        case .N:
            if sym.isRHS {
                guard let lhs = sym.alt else { return [] }
                let occurrenceEnds = Set(parser.yield(of: sym).lazy.filter { $0.k == from }.map(\.j))
                let lhsEnds = Set(parser.yield(of: lhs).lazy.filter { $0.i == from }.map(\.j))
                result = occurrenceEnds.intersection(lhsEnds)
            } else {
                result = Set(parser.yield(of: sym).lazy.filter { $0.i == from }.map(\.j))
            }
        case .DO, .OPT, .KLN, .POS:
            var positions = Set<CharPosition>()
            if sym.kind == .KLN || sym.kind == .OPT { positions.insert(from) }
            if sym.kind.isClosure {
                var visited = Set<CharPosition>()
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

    private mutating func iterationEndPositions(_ bracket: GrammarNode, from: CharPosition) -> Set<CharPosition> {
        var positions = Set<CharPosition>()
        var alt = bracket.alt
        while let a = alt {
            var frontier: Set<CharPosition> = [from]
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
    private mutating func tileAlternate(_ node: GrammarNode, from: CharPosition, to: CharPosition) -> (alt: GrammarNode, spans: [(GrammarNode, CharPosition, CharPosition)])? {
        var alt = node.alt
        while let a = alt {
            defer { alt = a.alt }
            if let spans = tileBody(a.bodySymbols, from: from, to: to) {
                return (a, spans)
            }
        }
        return nil
    }

    private mutating func tileBody(_ symbols: [GrammarNode], from: CharPosition, to: CharPosition) -> [(GrammarNode, CharPosition, CharPosition)]? {
        var spans: [(GrammarNode, CharPosition, CharPosition)] = []
        return tileBody(symbols, index: 0, from: from, to: to, into: &spans) ? spans : nil
    }

    private mutating func tileBody(_ symbols: [GrammarNode], index: Int, from: CharPosition, to: CharPosition, into spans: inout [(GrammarNode, CharPosition, CharPosition)]) -> Bool {
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

    /// Exact source text of the terminal that the parser committed starting
    /// at `pos`. Returns the empty string if no terminal started there (e.g.
    /// the position is inside trivia, or no parse reached it). The boundaries
    /// come from the parser's commit log — no whitespace heuristics, no
    /// language-specific assumptions.
    private func tokenText(at pos: CharPosition) -> String {
        guard let image = parser.terminalImage(startingAt: pos) else { return "" }
        return String(image)
    }

    // MARK: - Top-level dispatch

    /// Convert a nonterminal spanning [from..to] into CodeBlockItem elements.
    private mutating func convertNonterminal(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> [CodeBlockItemSyntax.Item] {
        let lhsNode = nt.kind == .N && nt.seq == nil ? nt : lhs(nt) ?? nt
        switch lhsNode.name {
        case "topLevelDeclaration":
            return convertTopLevelDeclaration(lhsNode, from: from, to: to)
        default:
            record(.unhandled, "root nonterminal '\(lhsNode.name)' has no converter", from: from, to: to)
            return []
        }
    }

    // MARK: - Statements

    private mutating func convertTopLevelDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> [CodeBlockItemSyntax.Item] {
        // topLevelDeclaration = shebang? statements? .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return []
        }
        guard let stmtsNT = find("statements", in: spans) else {
            // An empty source (or comment-only source) legitimately has no `statements`.
            if !input[from..<to].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                record(.lookupFailed, "no statements child", from: from, to: to)
            }
            return []
        }
        return convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to)
    }

    private struct NTSpan {
        let nt: GrammarNode
        let from: CharPosition
        let to: CharPosition
    }

    /// Search through brackets to find a nonterminal by name within a span.
    /// Only digs through brackets (OPT, DO, KLN, POS), NOT through non-matching nonterminals.
    private mutating func findNonterminal(named name: String, sym: GrammarNode, from: CharPosition, to: CharPosition) -> NTSpan? {
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

    private mutating func find(_ name: String, in spans: [(GrammarNode, CharPosition, CharPosition)]) -> NTSpan? {
        for (sym, from, to) in spans {
            if let found = findNonterminal(named: name, sym: sym, from: from, to: to) {
                return found
            }
        }
        return nil
    }

    /// First of `names` present in `spans`. `find(a) ?? find(b)` does not compile —
    /// the `??` autoclosure cannot capture a mutating `self` — and fallback chains
    /// recur across the converter, so they go through here.
    private mutating func find(firstOf names: [String], in spans: [(GrammarNode, CharPosition, CharPosition)]) -> NTSpan? {
        for name in names {
            if let found = find(name, in: spans) { return found }
        }
        return nil
    }

    private mutating func convertStatements(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> [CodeBlockItemSyntax.Item] {
        // statements = statement ";"? .
        // statements = statement statementSeparator statements .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return []
        }
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

    /// statement = >->(declaration attributes) expression .  |  @prefer declaration .
    /// plus loop/branch/labeled/controlTransfer/defer/do/compilerControl/yield/discard —
    /// none of which have a converter yet (Phase 3).
    private mutating func convertStatement(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> CodeBlockItemSyntax.Item? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        if let declNT = find("declaration", in: spans),
           let decl = convertDeclaration(declNT.nt, from: declNT.from, to: declNT.to) {
            return .decl(decl)
        }
        if let exprNT = find("expression", in: spans) {
            return .expr(convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to))
        }
        record(.unhandled, "statement is neither declaration nor expression", from: from, to: to)
        return nil
    }

    // MARK: - Declarations

    /// declaration = importDeclaration | constantDeclaration | variableDeclaration
    ///             | typealiasDeclaration | functionDeclaration | … (21 alternates).
    /// Only the two binding forms are converted; the rest are Phase 3/4.
    private mutating func convertDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> DeclSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        if let constNT = find("constantDeclaration", in: spans) {
            return DeclSyntax(convertVarLetDecl(constNT.nt, from: constNT.from, to: constNT.to, isLet: true))
        }
        if let varNT = find("variableDeclaration", in: spans) {
            return DeclSyntax(convertVarLetDecl(varNT.nt, from: varNT.from, to: varNT.to, isLet: false))
        }
        record(.unhandled, "declaration kind has no converter", from: from, to: to)
        return nil
    }

    private mutating func convertVarLetDecl(_ nt: GrammarNode, from: CharPosition, to: CharPosition, isLet: Bool) -> VariableDeclSyntax {
        // constantDeclaration = attributes? declarationModifiers? "let" patternInitializerList .
        // variableDeclaration = variableDeclarationHead patternInitializerList .
        //   (the getter/setter and willSet/didSet variableDeclaration alternates carry
        //    `variableName typeAnnotation …` instead, and are not converted here)
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return VariableDeclSyntax(bindingSpecifier: .keyword(isLet ? .let : .var), bindings: [])
        }
        var bindings: [PatternBindingSyntax] = []
        if let listNT = find("patternInitializerList", in: spans) {
            bindings = convertPatternInitializerList(listNT.nt, from: listNT.from, to: listNT.to)
        } else {
            record(.unhandled, "binding decl without patternInitializerList (accessor form?)", from: from, to: to)
        }
        return VariableDeclSyntax(
            bindingSpecifier: .keyword(isLet ? .let : .var),
            bindings: PatternBindingListSyntax(bindings)
        )
    }

    private mutating func convertPatternInitializerList(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> [PatternBindingSyntax] {
        // patternInitializerList = patternInitializer | patternInitializer "," patternInitializerList .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return []
        }
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

    private mutating func convertPatternInitializer(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> PatternBindingSyntax {
        // patternInitializer = bindingPattern initializer? .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return PatternBindingSyntax(
                pattern: missingPattern(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            )
        }
        var pattern: PatternSyntax
        var typeAnnotation: TypeAnnotationSyntax? = nil
        var initializer: InitializerClauseSyntax? = nil

        if let bpNT = find("bindingPattern", in: spans) {
            let (pat, ta) = convertBindingPattern(bpNT.nt, from: bpNT.from, to: bpNT.to)
            pattern = pat
            typeAnnotation = ta
        } else {
            pattern = missingPattern(.lookupFailed, "no bindingPattern child", from: from, to: to)
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

    private mutating func convertBindingPattern(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> (PatternSyntax, TypeAnnotationSyntax?) {
        // bindingPattern = wildcardPattern typeAnnotation?
        //                | identifierPattern typeAnnotation?
        //                | tupleBindingPattern typeAnnotation? .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return (missingPattern(.lookupFailed, "no alternate tiles the span", from: from, to: to), nil)
        }
        var pattern: PatternSyntax
        var typeAnnotation: TypeAnnotationSyntax? = nil

        if let idNT = find("identifierPattern", in: spans) {
            let name = collectTerminalText(from: idNT.from, to: idNT.to)
            pattern = PatternSyntax(IdentifierPatternSyntax(identifier: .identifier(name)))
        } else {
            // wildcardPattern / tupleBindingPattern have no converter yet.
            pattern = missingPattern(.unhandled, "binding pattern is not an identifierPattern", from: from, to: to)
        }
        if let taNT = find("typeAnnotation", in: spans) {
            typeAnnotation = convertTypeAnnotation(taNT.nt, from: taNT.from, to: taNT.to)
        }
        return (pattern, typeAnnotation)
    }

    private mutating func convertTypeAnnotation(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> TypeAnnotationSyntax? {
        // typeAnnotation = ":" type .   (specifiers/attributes are carried by `type`)
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        guard let typeNT = find("type", in: spans) else {
            record(.lookupFailed, "no type child", from: from, to: to)
            return nil
        }
        return TypeAnnotationSyntax(
            colon: .colonToken(),
            type: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
        )
    }

    private mutating func convertInitializer(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> InitializerClauseSyntax? {
        // initializer = assignmentOperator expression .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        guard let exprNT = find("expression", in: spans) else {
            record(.lookupFailed, "no expression child", from: from, to: to)
            return nil
        }
        return InitializerClauseSyntax(
            equal: .equalToken(),
            value: convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
        )
    }

    // MARK: - Expressions

    private mutating func convertExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // expression = tryOperator? awaitOperator? conditionalExpression coercingOperator? .
        // expression = tryOperator? awaitOperator? prefixExpression infixExpressions? .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }

        guard let prefNT = find("prefixExpression", in: spans) else {
            // The conditionalExpression alternate (if/switch expression) is Phase 3.
            return missingExpr(.unhandled, "expression without prefixExpression child", from: from, to: to)
        }
        let operand = convertPrefixExpression(prefNT.nt, from: prefNT.from, to: prefNT.to)

        if let infSpan = find("infixExpressions", in: spans) {
            var elements: [ExprSyntax] = [operand]
            flattenInfixExpressions(infSpan.nt, from: infSpan.from, to: infSpan.to, into: &elements)
            return ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(elements)))
        }

        return operand
    }

    private mutating func flattenInfixExpressions(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [ExprSyntax]) {
        // infixExpressions = infixExpression infixExpressions? .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        for (sym, f, t) in spans {
            if let ieNT = findNonterminal(named: "infixExpression", sym: sym, from: f, to: t) {
                flattenInfixExpression(ieNT.nt, from: ieNT.from, to: ieNT.to, into: &elements)
            }
            if let nextNT = findNonterminal(named: "infixExpressions", sym: sym, from: f, to: t) {
                flattenInfixExpressions(nextNT.nt, from: nextNT.from, to: nextNT.to, into: &elements)
            }
        }
    }

    private mutating func flattenInfixExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [ExprSyntax]) {
        // infixExpression = >s< ( >->( regularExpressionLiteral ) postfixOperatorToken | dotOperator | "&" ) >s< tryOperator? awaitOperator? prefixExpression .
        // infixExpression = <s> infixOperator <s> tryOperator? awaitOperator? prefixExpression .
        // infixExpression = arrowExpr tryOperator? awaitOperator? prefixExpression .
        // infixExpression = assignmentOperator expression .
        // infixExpression = conditionalOperator expression .
        // infixExpression = typeCastingOperator .
        //
        // NOTE (found by the rule-comment sweep, 2026-09-02): the assignment and
        // conditional alternates take a full `expression`, NOT `prefixExpression`, and
        // neither `assignmentOperator` nor the trailing `expression` is handled below —
        // so `x = 1` and the ternary false-branch lose their right-hand side. Phase 2 work;
        // the `.unhandled` record below is what will surface it in the triage list.
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        let before = elements.count

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
        if elements.count == before {
            record(.unhandled, "infixExpression alternate contributed no element", from: from, to: to)
        }
    }

    private mutating func convertConditionalOperator(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // conditionalOperator = <s> "?" expression ":" .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        let thenExpr: ExprSyntax
        if let exprNT = find("expression", in: spans) {
            thenExpr = convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
        } else {
            thenExpr = missingExpr(.lookupFailed, "no expression child (then-branch)", from: from, to: to)
        }
        return ExprSyntax(UnresolvedTernaryExprSyntax(
            questionMark: .infixQuestionMarkToken(),
            thenExpression: thenExpr,
            colon: .colonToken()
        ))
    }

    private mutating func convertTypeCastingOperator(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [ExprSyntax]) {
        // typeCastingOperator = "is" type .
        // typeCastingOperator = "as" type .
        // typeCastingOperator = "as" >s< "?" type .
        // typeCastingOperator = "as" >s< "!" type .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }

        let firstToken = tokenText(at: from)
        if firstToken == "as" {
            elements.append(ExprSyntax(UnresolvedAsExprSyntax(asKeyword: .keyword(.as))))
        } else if firstToken == "is" {
            elements.append(ExprSyntax(UnresolvedIsExprSyntax(isKeyword: .keyword(.is))))
        }

        if let typeNT = find("type", in: spans) {
            let type = convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
            elements.append(ExprSyntax(TypeExprSyntax(type: type)))
        } else {
            record(.lookupFailed, "no type child", from: from, to: to)
        }
    }

    private mutating func convertPrefixExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // prefixExpression = @shortest [ prefixOperator >s< ] postfixExpression .
        // prefixExpression = "!" >s< postfixExpression .
        // prefixExpression = inOutExpression .
        // prefixExpression = @prefer ("consume"|"borrow"|"copy"|"unsafe") <s> >n< prefixExpression .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
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
            // inOutExpression and the consume/borrow/copy/unsafe forms land here.
            return missingExpr(.unhandled, "prefixExpression without postfixExpression child", from: from, to: to)
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

    private mutating func convertPostfixExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // postfixExpression = primaryExpression .
        // postfixExpression = functionCallExpression | initializerExpression
        //                   | explicitMemberExpression | subscriptExpression
        //                   | forcedValueExpression | optionalChainingExpression
        //                   | @prefer >->( keyPathExpression ) postfixExpression >s< postfixOperator <s> …
        // Only the bare primaryExpression alternate is converted; the rest are Phase 2/3.
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        guard let primNT = find("primaryExpression", in: spans) else {
            return missingExpr(.unhandled, "postfix form has no converter", from: from, to: to)
        }
        return convertPrimaryExpression(primNT.nt, from: primNT.from, to: primNT.to)
    }

    /// primaryExpression = genericIdentifier | literalExpression | selfExpression
    ///                   | superclassExpression | closureExpression | tupleExpression
    ///                   | … (24 alternates in Swift.apus).
    private mutating func convertPrimaryExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        if let litNT = find("literalExpression", in: spans) {
            return convertLiteralExpression(litNT.nt, from: litNT.from, to: litNT.to)
        }
        if let idNT = find("identifier", in: spans) {
            let name = collectTerminalText(from: idNT.from, to: idNT.to)
            return ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
        }
        // `primaryExpression = genericIdentifier` → `genericIdentifier = hardIdentifier …`
        // → `hardIdentifier = identifier`. The branch above can never fire for this path:
        // `identifier` is a TERMINAL, and `findNonterminal` digs only through brackets, not
        // through non-matching nonterminals. So a bare identifier reference produced
        // `MissingExpr`. Handled here by descending the two named levels explicitly.
        //
        // A `genericArgumentClause` (`f<Int>`) is NOT handled yet — fall through to
        // `MissingExpr` rather than silently dropping the type arguments.
        if let genNT = find("genericIdentifier", in: spans),
           let (_, genSpans) = tileAlternate(genNT.nt, from: genNT.from, to: genNT.to),
           find("genericArgumentClause", in: genSpans) == nil,
           let hardNT = find("hardIdentifier", in: genSpans) {
            let name = collectTerminalText(from: hardNT.from, to: hardNT.to)
            if !name.isEmpty {
                return ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
            }
        }
        return missingExpr(.unhandled, "primaryExpression form has no converter", from: from, to: to)
    }

    // MARK: - Literals

    /// literalExpression = literal | arrayLiteral | dictionaryLiteral .
    private mutating func convertLiteralExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        guard let litNT = find("literal", in: spans) else {
            return missingExpr(.unhandled, "array/dictionary literal has no converter", from: from, to: to)
        }
        return convertLiteral(litNT.nt, from: litNT.from, to: litNT.to)
    }

    /// literal = numericLiteral | stringLiteral | regularExpressionLiteral | booleanLiteral | nilLiteral .
    private mutating func convertLiteral(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
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
        // regularExpressionLiteral → RegexLiteralExpr is not converted yet.
        return missingExpr(.unhandled, "literal kind has no converter", from: from, to: to)
    }

    private mutating func convertNumericLiteral(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // numericLiteral = signedIntegerLiteral | signedFloatingPointLiteral .
        // For now, collect all terminal text and decide based on content
        let text = collectTerminalText(from: from, to: to)
        if text.contains(".") || text.contains("e") || text.contains("E") || text.contains("p") || text.contains("P") {
            return ExprSyntax(FloatLiteralExprSyntax(literal: .floatLiteral(text)))
        }
        return ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral(text)))
    }

    private mutating func convertStringLiteral(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // stringLiteral = staticStringLiteral | interpolatedStringLiteral .
        // interpolatedStringLiteral = @excludedFrom(availableAttribute) singleLineInterpolatedStringLiteral .
        // interpolatedStringLiteral = @excludedFrom(availableAttribute) multilineInterpolatedStringLiteral .
        // `find` digs through brackets but not through nonterminals, so descend both levels.
        if let (_, spans) = tileAlternate(nt, from: from, to: to),
           let interp = find("interpolatedStringLiteral", in: spans),
           let (_, interpSpans) = tileAlternate(interp.nt, from: interp.from, to: interp.to),
           let single = find("singleLineInterpolatedStringLiteral", in: interpSpans),
           let expr = convertInterpolatedStringLiteral(single.nt, from: single.from, to: single.to) {
            return expr
        }
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
        // Fallback: just use the raw text. Multiline (`"""`), raw (`#"…"#`) and any
        // interpolated form the reassembler above declined all land here with the wrong
        // quote tokens and a single unsplit segment.
        record(.unhandled, "string literal is not a simple single-line form", from: from, to: to)
        return ExprSyntax(StringLiteralExprSyntax(
            openingQuote: .stringQuoteToken(),
            segments: StringLiteralSegmentListSyntax([
                .stringSegment(StringSegmentSyntax(content: .stringSegment(fullText)))
            ]),
            closingQuote: .stringQuoteToken()
        ))
    }

    /// Interpolated string → swift-syntax's `StringLiteralExpr` shape.
    ///
    /// Probe-confirmed target (`_ = "\(x)"`): segments strictly ALTERNATE and always both start
    /// and end with a string segment, so N interpolations give N+1 string segments — including
    /// EMPTY ones. `"\(x)"` yields three segments: `""`, the expression, `""`.
    ///
    /// Our scanner fuses delimiters with content (see `SwiftSyntax Mapping.md`), which lines up
    /// exactly one segment per token:
    ///
    ///     Head = `"` + segment + `\(`      Part = `)` + segment + `\(`      Tail = `)` + segment + `"`
    ///
    /// so the tree can be reassembled here without splitting the tokens in the grammar — which
    /// would need a trivia-suppression mechanism, because `Lexer.lex` skips trivia
    /// unconditionally and would silently eat spaces inside string content (`"a\(b) c"`).
    ///
    /// LIMITED to the single-interpolation form: a non-empty `{ Part args }` returns nil and the
    /// caller falls back to the old one-segment tree. Extending this needs iteration over the KLN
    /// bracket, which is the obvious next step.
    private mutating func convertInterpolatedStringLiteral(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else { return nil }
        // Multi-interpolation (non-empty repetition bracket) — not handled yet.
        if spans.contains(where: { $0.0.kind == .KLN && $0.1 != $0.2 }) { return nil }
        guard let head = spans.first(where: { $0.0.name == "interpolatedStringLiteralHead" }),
              let tail = spans.first(where: { $0.0.name == "interpolatedStringLiteralTail" }),
              let args = find("functionCallArgumentList", in: spans)
        else { return nil }

        let headText = String(input[head.1..<head.2])      // `"abc\(`
        let tailText = String(input[tail.1..<tail.2])      // `)ghi"`
        guard headText.hasPrefix("\""), headText.hasSuffix("\\("),
              tailText.hasPrefix(")"), tailText.hasSuffix("\"")
        else { return nil }
        let leadingSegment  = String(headText.dropFirst().dropLast(2))
        let trailingSegment = String(tailText.dropFirst().dropLast())

        return ExprSyntax(StringLiteralExprSyntax(
            openingQuote: .stringQuoteToken(),
            segments: StringLiteralSegmentListSyntax([
                .stringSegment(StringSegmentSyntax(content: .stringSegment(leadingSegment))),
                .expressionSegment(ExpressionSegmentSyntax(
                    backslash: .backslashToken(),
                    leftParen: .leftParenToken(),
                    expressions: convertArgumentList(args.nt, from: args.from, to: args.to),
                    rightParen: .rightParenToken()
                )),
                .stringSegment(StringSegmentSyntax(content: .stringSegment(trailingSegment))),
            ]),
            closingQuote: .stringQuoteToken()
        ))
    }

    /// `functionCallArgumentList` → `LabeledExprListSyntax`. The list is right-recursive
    /// (`arg | arg "," list`), so this walks the tail and adds separating commas afterwards.
    private mutating func convertArgumentList(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> LabeledExprListSyntax {
        var items: [LabeledExprSyntax] = []
        collectArguments(nt, from: from, to: to, into: &items)
        return LabeledExprListSyntax(items.enumerated().map { index, item in
            index == items.count - 1 ? item : item.with(\.trailingComma, .commaToken())
        })
    }

    private mutating func collectArguments(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [LabeledExprSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let argNT = find("functionCallArgument", in: spans),
           let (_, argSpans) = tileAlternate(argNT.nt, from: argNT.from, to: argNT.to),
           let exprNT = find("expression", in: argSpans) {
            let expr = convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
            if let labelNT = find("argumentLabel", in: argSpans) {
                items.append(LabeledExprSyntax(
                    label: .identifier(collectTerminalText(from: labelNT.from, to: labelNT.to)),
                    colon: .colonToken(),
                    expression: expr
                ))
            } else {
                items.append(LabeledExprSyntax(expression: expr))
            }
        }
        if let restNT = find("functionCallArgumentList", in: spans) {
            collectArguments(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    // MARK: - Types

    private mutating func convertType(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> TypeSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return TypeSyntax(MissingTypeSyntax())
        }
        if let optNT = find("optionalType", in: spans) {
            return convertOptionalType(optNT.nt, from: optNT.from, to: optNT.to)
        }
        if let typeIdNT = find("typeIdentifier", in: spans) {
            return convertTypeIdentifier(typeIdNT.nt, from: typeIdNT.from, to: typeIdNT.to)
        }
        // `simpleType` is the postfix-bindable subset (`optionalType = simpleType >s< '?'`).
        // Its alternates are named exactly like `type`'s, so the same dispatch handles it.
        if let simpleNT = find("simpleType", in: spans) {
            return convertType(simpleNT.nt, from: simpleNT.from, to: simpleNT.to)
        }
        // Everything else (function, tuple, array, dictionary, composition, opaque,
        // metatype, …) degrades to a flat IdentifierType over the raw source text.
        let text = collectTerminalText(from: from, to: to)
        record(.unhandled, "type form has no converter; flattened to IdentifierType", from: from, to: to)
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier(text)))
    }

    private mutating func convertTypeIdentifier(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> TypeSyntax {
        let name = collectTerminalText(from: from, to: to)
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier(name)))
    }

    private mutating func convertOptionalType(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> TypeSyntax {
        // optionalType = simpleType >s< optionalMark .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingType(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        guard let typeNT = find(firstOf: ["simpleType", "type"], in: spans) else {
            return missingType(.lookupFailed, "no simpleType/type child", from: from, to: to)
        }
        return TypeSyntax(OptionalTypeSyntax(
            wrappedType: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to),
            questionMark: .postfixQuestionMarkToken()
        ))
    }

    // MARK: - Terminal Text Collection

    /// Collect the concatenated text of every terminal that committed in
    /// the span `[from, to)`. Walks the parser's commit log — boundaries are
    /// grammar-defined, trivia (whatever lies between consecutive commits)
    /// is dropped. Order is by start position.
    ///
    /// The commit log records EVERY terminal the parser tried, including ones
    /// belonging to derivations that later died, so commits can overlap: on
    /// `1.5` the scanner commits the float `1.5` at the `1` and also `.5` at the
    /// `.`, which naively concatenated reads `1.5.5`. Only commits that start at
    /// or after the previous commit's content end are taken, and one that runs
    /// past `to` is skipped as belonging to a wider (dead) reading.
    private func collectTerminalText(from: CharPosition, to: CharPosition) -> String {
        let starts = parser.commitsByStart.keys
            .filter { $0 >= from && $0 < to }
            .sorted()
        var result = ""
        var cursor = from
        for s in starts where s >= cursor {
            guard let img = parser.terminalImage(startingAt: s), img.endIndex <= to else { continue }
            result += img
            cursor = img.endIndex
        }
        return result
    }
}
