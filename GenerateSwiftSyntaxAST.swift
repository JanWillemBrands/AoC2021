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

    /// Why the last `tiledText` walk gave up, for the fallback diagnostic.
    private var tiledFailure: String? = nil

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

    /// Locate a named TERMINAL in `spans`. `find`/`findNonterminal` match `.N` nodes
    /// only, so a rule referencing a named terminal (`decimalDigits - /[0-9]+/`) is
    /// invisible to them — which is exactly how `x.0` broke when `decimalDigits`
    /// changed from `=` to `-`. Digs through brackets the same way `find` does.
    private mutating func findTerminal(named name: String, in spans: [(GrammarNode, CharPosition, CharPosition)]) -> NTSpan? {
        for (sym, f, t) in spans {
            if sym.kind.isTerminal, sym.name == name, f < t {
                return NTSpan(nt: sym, from: f, to: t)
            }
            if sym.kind.isBracket, f < t,
               let (_, inner) = tileAlternate(sym, from: f, to: t),
               let found = findTerminal(named: name, in: inner) {
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
        if let ctNT = find("controlTransferStatement", in: spans),
           let stmt = convertControlTransferStatement(ctNT.nt, from: ctNT.from, to: ctNT.to) {
            return .stmt(stmt)
        }
        if let lNT = find("loopStatement", in: spans),
           let stmt = convertLoopStatement(lNT.nt, from: lNT.from, to: lNT.to) {
            return .stmt(stmt)
        }
        if let dNT = find("doStatement", in: spans) {
            return .stmt(convertDoStatement(dNT.nt, from: dNT.from, to: dNT.to))
        }
        // branchStatement = guardStatement .   (`if` is an EXPRESSION in swift-syntax and
        // reaches the converter through `expression` below, not through here.)
        if let bNT = find("branchStatement", in: spans),
           let (_, bSpans) = tileAlternate(bNT.nt, from: bNT.from, to: bNT.to),
           let gNT = find("guardStatement", in: bSpans) {
            return .stmt(convertGuardStatement(gNT.nt, from: gNT.from, to: gNT.to))
        }
        if let exprNT = find("expression", in: spans) {
            let expr = convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
            // `if`/`switch` are expressions in swift-syntax, but in STATEMENT position it
            // wraps them in an `ExpressionStmt` — whereas in expression position
            // (`let a = if c { 1 } else { 2 }`) the bare `IfExpr` is the initializer value.
            if expr.is(IfExprSyntax.self) || expr.is(SwitchExprSyntax.self) {
                return .stmt(StmtSyntax(ExpressionStmtSyntax(expression: expr)))
            }
            return .expr(expr)
        }
        record(.unhandled, "statement kind has no converter: \(alternateKind(spans))", from: from, to: to)
        return nil
    }

    /// controlTransferStatement = breakStatement | continueStatement
    ///                          | fallthroughStatement | returnStatement | throwStatement .
    private mutating func convertControlTransferStatement(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> StmtSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        // breakStatement = "break" labelName .  /  continueStatement = "continue" labelName? .
        if let d = find("breakStatement", in: spans) {
            return StmtSyntax(BreakStmtSyntax(breakKeyword: .keyword(.break), label: labelToken(d)))
        }
        if let d = find("continueStatement", in: spans) {
            return StmtSyntax(ContinueStmtSyntax(continueKeyword: .keyword(.continue), label: labelToken(d)))
        }
        // fallthroughStatement = "fallthrough" .
        if find("fallthroughStatement", in: spans) != nil {
            return StmtSyntax(FallThroughStmtSyntax(fallthroughKeyword: .keyword(.fallthrough)))
        }
        // returnStatement = "return" expression? .
        if let d = find("returnStatement", in: spans) {
            var value: ExprSyntax? = nil
            if let (_, rSpans) = tileAlternate(d.nt, from: d.from, to: d.to),
               let exprNT = find("expression", in: rSpans) {
                value = convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
            }
            return StmtSyntax(ReturnStmtSyntax(returnKeyword: .keyword(.return), expression: value))
        }
        // throwStatement = "throw" expression .
        if let d = find("throwStatement", in: spans) {
            guard let (_, tSpans) = tileAlternate(d.nt, from: d.from, to: d.to),
                  let exprNT = find("expression", in: tSpans) else {
                record(.lookupFailed, "throw without expression", from: d.from, to: d.to)
                return nil
            }
            return StmtSyntax(ThrowStmtSyntax(
                throwKeyword: .keyword(.throw),
                expression: convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
            ))
        }
        record(.unhandled, "control transfer kind has no converter: \(alternateKind(spans))", from: from, to: to)
        return nil
    }

    /// The optional `labelName` of a break/continue. `labelName = hardIdentifier .`
    private mutating func labelToken(_ span: NTSpan) -> TokenSyntax? {
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to),
              let labelNT = find("labelName", in: spans) else { return nil }
        return .identifier(collectTerminalText(labelNT.nt, from: labelNT.from, to: labelNT.to))
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
        if let funcNT = find("functionDeclaration", in: spans) {
            return DeclSyntax(convertFunctionDeclaration(funcNT.nt, from: funcNT.from, to: funcNT.to))
        }
        if let d = find("structDeclaration", in: spans) {
            let (name, attrs, modifiers, generics, inherit, members) = nominalParts(d, nameRule: "structName", bodyRule: "structBody", membersRule: "structMembers", memberRule: "structMember")
            return DeclSyntax(StructDeclSyntax(attributes: attrs, modifiers: modifiers, name: name,
                                             genericParameterClause: generics,
                                             inheritanceClause: inherit, memberBlock: members))
        }
        if let d = find("classDeclaration", in: spans) {
            let (name, attrs, modifiers, generics, inherit, members) = nominalParts(d, nameRule: "className", bodyRule: "classBody", membersRule: "classMembers", memberRule: "classMember")
            return DeclSyntax(ClassDeclSyntax(attributes: attrs, modifiers: modifiers, name: name,
                                             genericParameterClause: generics,
                                             inheritanceClause: inherit, memberBlock: members))
        }
        if let d = find("enumDeclaration", in: spans) {
            // enumDeclaration inlines its braces — no body nonterminal.
            let (name, attrs, modifiers, generics, inherit, members) = nominalParts(d, nameRule: "enumName", bodyRule: nil, membersRule: "enumMembers", memberRule: "enumMember")
            return DeclSyntax(EnumDeclSyntax(attributes: attrs, modifiers: modifiers, name: name,
                                             genericParameterClause: generics,
                                             inheritanceClause: inherit, memberBlock: members))
        }
        if let d = find("protocolDeclaration", in: spans) {
            let (name, attrs, modifiers, generics, inherit, members) = nominalParts(d, nameRule: "protocolName", bodyRule: "protocolBody", membersRule: "protocolMembers", memberRule: "protocolMember")
            if generics != nil { record(.unhandled, "protocol primaryAssociatedTypeClause not converted", from: d.from, to: d.to) }
            return DeclSyntax(ProtocolDeclSyntax(attributes: attrs, modifiers: modifiers, name: name,
                                             inheritanceClause: inherit, memberBlock: members))
        }
        if let d = find("extensionDeclaration", in: spans) {
            return DeclSyntax(convertExtensionDeclaration(d.nt, from: d.from, to: d.to))
        }
        if let d = find("enumCaseDeclaration", in: spans) {
            return DeclSyntax(convertEnumCaseDeclaration(d.nt, from: d.from, to: d.to))
        }
        if let d = find(firstOf: ["initializerDeclaration", "bodylessInitializerDeclaration"], in: spans) {
            return DeclSyntax(convertInitializerDeclaration(d.nt, from: d.from, to: d.to))
        }
        if let d = find("operatorDeclaration", in: spans) {
            return DeclSyntax(convertOperatorDeclaration(d.nt, from: d.from, to: d.to))
        }
        if let d = find("typealiasDeclaration", in: spans) {
            return DeclSyntax(convertTypealiasDeclaration(d.nt, from: d.from, to: d.to))
        }
        if let d = find("deinitializerDeclaration", in: spans) {
            return DeclSyntax(convertDeinitializerDeclaration(d.nt, from: d.from, to: d.to))
        }
        if let d = find("subscriptDeclaration", in: spans) {
            return DeclSyntax(convertSubscriptDeclaration(d.nt, from: d.from, to: d.to))
        }
        record(.unhandled, "declaration kind has no converter: \(alternateKind(spans))", from: from, to: to)
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
        // `constantDeclaration` carries attributes/modifiers directly; `variableDeclaration`
        // hides them one level down inside `variableDeclarationHead`. Look in both.
        var headSpans = spans
        if let headNT = find("variableDeclarationHead", in: spans),
           let (_, inner) = tileAlternate(headNT.nt, from: headNT.from, to: headNT.to) {
            headSpans = inner
        }
        var attributes = AttributeListSyntax([])
        if let attrNT = find("attributes", in: headSpans) {
            attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
        }
        var modifiers = DeclModifierListSyntax([])
        if let modsNT = find("declarationModifiers", in: headSpans) {
            modifiers = convertDeclarationModifiers(modsNT.nt, from: modsNT.from, to: modsNT.to)
        }
        var bindings: [PatternBindingSyntax] = []
        if let listNT = find("patternInitializerList", in: spans) {
            bindings = convertPatternInitializerList(listNT.nt, from: listNT.from, to: listNT.to)
        } else if let nameNT = find("variableName", in: spans) {
            // The COMPUTED-property alternates spell the binding inline instead of going through
            // `patternInitializerList`:
            //   variableDeclaration = variableDeclarationHead variableName typeAnnotation getterSetterBlock .
            //   variableDeclaration = variableDeclarationHead variableName typeAnnotation? initializer? willSetDidSetBlock .
            // swift-syntax still models them as ONE PatternBinding, with the accessors in
            // `accessorBlock` — so the pieces are reassembled into that shape here.
            let name = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
            var typeAnnotation: TypeAnnotationSyntax? = nil
            if let taNT = find("typeAnnotation", in: spans) {
                typeAnnotation = convertTypeAnnotation(taNT.nt, from: taNT.from, to: taNT.to)
            }
            var initializer: InitializerClauseSyntax? = nil
            if let initNT = find("initializer", in: spans) {
                initializer = convertInitializer(initNT.nt, from: initNT.from, to: initNT.to)
            }
            var accessorBlock: AccessorBlockSyntax? = nil
            if let gsNT = find("getterSetterBlock", in: spans) {
                accessorBlock = convertGetterSetterBlock(gsNT.nt, from: gsNT.from, to: gsNT.to)
            } else if find(firstOf: ["willSetDidSetBlock", "initializedAccessorBlock"], in: spans) != nil {
                record(.unhandled, "willSet/didSet or init-accessor block not converted", from: from, to: to)
            }
            bindings = [PatternBindingSyntax(
                pattern: IdentifierPatternSyntax(
                    identifier: name == "_" ? .wildcardToken() : .identifier(name)
                ),
                typeAnnotation: typeAnnotation,
                initializer: initializer,
                accessorBlock: accessorBlock
            )]
        } else {
            record(.unhandled, "binding decl with neither patternInitializerList nor variableName", from: from, to: to)
        }
        return VariableDeclSyntax(
            attributes: attributes,
            modifiers: modifiers,
            bindingSpecifier: .keyword(isLet ? .let : .var),
            bindings: PatternBindingListSyntax(bindings)
        )
    }

    // MARK: - Nominal type declarations
    //
    // struct/class/enum/protocol/extension share one shape in Swift.apus:
    //   <kind>Declaration = attributes? accessLevelModifier? … "<kw>" <kind>Name
    //                       genericParameterClause? typeInheritanceClause? genericWhereClause? <body>
    //   <body>    = "{" <kind>Members? "}" .          (enum inlines the braces)
    //   <kind>Members = <kind>Member ";"? | <kind>Member statementSeparator <kind>Members .
    //   <kind>Member  = memberDeclaration | compilerControlStatement .
    // so one parameterised walk serves all of them.

    private mutating func nominalParts(
        _ span: NTSpan,
        nameRule: String,
        bodyRule: String?,
        membersRule: String,
        memberRule: String
    ) -> (name: TokenSyntax, attributes: AttributeListSyntax, modifiers: DeclModifierListSyntax,
          generics: GenericParameterClauseSyntax?, inheritance: InheritanceClauseSyntax?, members: MemberBlockSyntax) {
        let empty = MemberBlockSyntax(members: [])
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to) else {
            record(.lookupFailed, "no alternate tiles the span", from: span.from, to: span.to)
            return (.identifier("?"), AttributeListSyntax([]), DeclModifierListSyntax([]), nil, nil, empty)
        }
        let modifiers = declHeadModifiers(spans, from: span.from, to: span.to)
        var attributes = AttributeListSyntax([])
        if let attrNT = find("attributes", in: spans) {
            attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
        }
        var generics: GenericParameterClauseSyntax? = nil
        if let gpNT = find("genericParameterClause", in: spans) {
            generics = convertGenericParameterClause(gpNT.nt, from: gpNT.from, to: gpNT.to)
        }

        var name = TokenSyntax.identifier("?")
        if let nameNT = find(nameRule, in: spans) {
            name = .identifier(collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to))
        } else {
            record(.lookupFailed, "no \(nameRule) child", from: span.from, to: span.to)
        }

        var inheritance: InheritanceClauseSyntax? = nil
        if let inhNT = find("typeInheritanceClause", in: spans) {
            inheritance = convertInheritanceClause(inhNT.nt, from: inhNT.from, to: inhNT.to)
        }

        // The member list sits under the body nonterminal, except for enum which
        // inlines its braces into the declaration rule.
        var memberSpans = spans
        if let bodyRule {
            guard let bodyNT = find(bodyRule, in: spans),
                  let (_, bodySpans) = tileAlternate(bodyNT.nt, from: bodyNT.from, to: bodyNT.to)
            else {
                record(.lookupFailed, "no \(bodyRule) child", from: span.from, to: span.to)
                return (name, attributes, modifiers, generics, inheritance, empty)
            }
            memberSpans = bodySpans
        }

        var items: [MemberBlockItemSyntax] = []
        if let listNT = find(membersRule, in: memberSpans) {
            collectMembers(listNT.nt, from: listNT.from, to: listNT.to,
                           membersRule: membersRule, memberRule: memberRule, into: &items)
        }
        let block = MemberBlockSyntax(
            leftBrace: .leftBraceToken(),
            members: MemberBlockItemListSyntax(items),
            rightBrace: .rightBraceToken()
        )
        return (name, attributes, modifiers, generics, inheritance, block)
    }

    private mutating func convertExtensionDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExtensionDeclSyntax {
        // extensionDeclaration = attributes? accessLevelModifier? "extension" typeIdentifier
        //                        typeInheritanceClause? genericWhereClause? extensionBody .
        let empty = MemberBlockSyntax(members: [])
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return ExtensionDeclSyntax(extendedType: MissingTypeSyntax(), memberBlock: empty)
        }
        let modifiers = declHeadModifiers(spans, from: from, to: to)
        var attributes = AttributeListSyntax([])
        if let attrNT = find("attributes", in: spans) {
            attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
        }

        var extended: TypeSyntax = TypeSyntax(MissingTypeSyntax())
        if let tiNT = find("typeIdentifier", in: spans) {
            extended = convertTypeIdentifier(tiNT.nt, from: tiNT.from, to: tiNT.to)
        } else {
            record(.lookupFailed, "no typeIdentifier child", from: from, to: to)
        }

        var inheritance: InheritanceClauseSyntax? = nil
        if let inhNT = find("typeInheritanceClause", in: spans) {
            inheritance = convertInheritanceClause(inhNT.nt, from: inhNT.from, to: inhNT.to)
        }

        var items: [MemberBlockItemSyntax] = []
        if let bodyNT = find("extensionBody", in: spans),
           let (_, bodySpans) = tileAlternate(bodyNT.nt, from: bodyNT.from, to: bodyNT.to),
           let listNT = find("extensionMembers", in: bodySpans) {
            collectMembers(listNT.nt, from: listNT.from, to: listNT.to,
                           membersRule: "extensionMembers", memberRule: "extensionMember", into: &items)
        }
        return ExtensionDeclSyntax(
            attributes: attributes,
            modifiers: modifiers,
            extendedType: extended,
            inheritanceClause: inheritance,
            memberBlock: MemberBlockSyntax(
                leftBrace: .leftBraceToken(),
                members: MemberBlockItemListSyntax(items),
                rightBrace: .rightBraceToken()
            )
        )
    }

    /// The modifier list of a nominal-type declaration head, in SOURCE ORDER.
    ///
    /// Unlike functions, these rules do not use `declarationModifiers`: they spell
    /// `attributes? accessLevelModifier? "final"? "class" …`, and `classDeclaration` has a second
    /// alternate with `"final"` BEFORE the access level. So the modifiers cannot be looked up by
    /// name and concatenated — they are collected by walking the alternate's spans in order.
    ///
    /// Attributes and generic clauses are still unconverted; emitting an empty `AttributeList`
    /// where swift-syntax has entries WILL mismatch, so that is recorded rather than hidden.
    private mutating func declHeadModifiers(_ spans: [(GrammarNode, CharPosition, CharPosition)], from: CharPosition, to: CharPosition) -> DeclModifierListSyntax {
        if find("genericWhereClause", in: spans) != nil {
            record(.unhandled, "genericWhereClause not converted", from: from, to: to)
        }

        var items: [DeclModifierSyntax] = []
        for (sym, f, t) in spans where f < t {
            if let accNT = findNonterminal(named: "accessLevelModifier", sym: sym, from: f, to: t) {
                let text = collectTerminalText(accNT.nt, from: accNT.from, to: accNT.to)
                if let open = text.firstIndex(of: "(") {
                    items.append(DeclModifierSyntax(
                        name: modifierToken(String(text[text.startIndex..<open])),
                        detail: DeclModifierDetailSyntax(detail: .identifier(String(text[text.index(after: open)...].dropLast())))
                    ))
                } else {
                    items.append(DeclModifierSyntax(name: modifierToken(text)))
                }
                continue
            }
            // Bare `final` / `indirect` sit in the body as keyword terminals under an OPT.
            if sym.kind.isTerminal || sym.kind == .OPT || sym.kind == .DO {
                var text = ""
                if tiledText(sym, from: f, to: t, into: &text), text == "final" || text == "indirect" {
                    items.append(DeclModifierSyntax(name: modifierToken(text)))
                }
            }
        }
        return DeclModifierListSyntax(items)
    }

    private mutating func convertInheritanceClause(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> InheritanceClauseSyntax? {
        // typeInheritanceClause = ":" typeInheritanceList .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let listNT = find("typeInheritanceList", in: spans) else {
            record(.lookupFailed, "no typeInheritanceList child", from: from, to: to)
            return nil
        }
        var types: [InheritedTypeSyntax] = []
        collectInheritedTypes(listNT.nt, from: listNT.from, to: listNT.to, into: &types)
        if types.count > 1 {
            for i in 0..<types.count - 1 {
                types[i] = types[i].with(\.trailingComma, .commaToken())
            }
        }
        return InheritanceClauseSyntax(
            colon: .colonToken(),
            inheritedTypes: InheritedTypeListSyntax(types)
        )
    }

    private mutating func collectInheritedTypes(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into types: inout [InheritedTypeSyntax]) {
        // typeInheritanceList = attributes? "~"? "nonisolated"? typeIdentifier [ "," typeInheritanceList ] .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if find("attributes", in: spans) != nil || spansContainKeyword(spans, "~") || spansContainKeyword(spans, "nonisolated") {
            record(.unhandled, "inherited type with attributes/~/nonisolated not converted", from: from, to: to)
        }
        if let tiNT = find("typeIdentifier", in: spans) {
            types.append(InheritedTypeSyntax(type: convertTypeIdentifier(tiNT.nt, from: tiNT.from, to: tiNT.to)))
        }
        if let restNT = find("typeInheritanceList", in: spans) {
            collectInheritedTypes(restNT.nt, from: restNT.from, to: restNT.to, into: &types)
        }
    }

    private mutating func collectMembers(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition,
        membersRule: String, memberRule: String,
        into items: inout [MemberBlockItemSyntax]
    ) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let memberNT = find(memberRule, in: spans),
           let (_, memberSpans) = tileAlternate(memberNT.nt, from: memberNT.from, to: memberNT.to) {
            // <kind>Member = memberDeclaration | compilerControlStatement .
            if let mdNT = find("memberDeclaration", in: memberSpans),
               let (_, mdSpans) = tileAlternate(mdNT.nt, from: mdNT.from, to: mdNT.to) {
                if let declNT = find("declaration", in: mdSpans),
                   let decl = convertDeclaration(declNT.nt, from: declNT.from, to: declNT.to) {
                    items.append(MemberBlockItemSyntax(decl: decl))
                } else {
                    record(.unhandled, "member declaration has no converter", from: memberNT.from, to: memberNT.to)
                }
            } else {
                record(.unhandled, "compilerControlStatement member not converted", from: memberNT.from, to: memberNT.to)
            }
        }
        if let restNT = find(membersRule, in: spans) {
            collectMembers(restNT.nt, from: restNT.from, to: restNT.to,
                           membersRule: membersRule, memberRule: memberRule, into: &items)
        }
    }

    // MARK: - if / switch expressions, conditions, match patterns
    //
    // swift-syntax models `if` and `switch` as EXPRESSIONS (`IfExprSyntax` / `SwitchExprSyntax`)
    // in both statement and expression position, so one converter serves both.

    /// conditionalExpression = ifExpression | switchExpression .
    private mutating func convertConditionalExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        if let d = find("ifExpression", in: spans) {
            return ExprSyntax(convertIfExpression(d.nt, from: d.from, to: d.to))
        }
        if let d = find("switchExpression", in: spans) {
            return ExprSyntax(convertSwitchExpression(d.nt, from: d.from, to: d.to))
        }
        return missingExpr(.unhandled, "conditional expression form has no converter: \(alternateKind(spans))", from: from, to: to)
    }

    /// ifExpression = "if" >->( "{" ) conditionList codeBlock elseClause? .
    /// elseClause   = "else" codeBlock | "else" ifExpression .
    private mutating func convertIfExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> IfExprSyntax {
        let empty = CodeBlockSyntax(statements: [])
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return IfExprSyntax(conditions: [], body: empty)
        }
        var conditions = ConditionElementListSyntax([])
        if let clNT = find("conditionList", in: spans) {
            conditions = convertConditionList(clNT.nt, from: clNT.from, to: clNT.to)
        } else {
            record(.lookupFailed, "no conditionList child", from: from, to: to)
        }
        var body = empty
        if let cbNT = find("codeBlock", in: spans) {
            body = convertCodeBlock(cbNT.nt, from: cbNT.from, to: cbNT.to)
        } else {
            record(.lookupFailed, "no codeBlock child", from: from, to: to)
        }

        var elseKeyword: TokenSyntax? = nil
        var elseBody: IfExprSyntax.ElseBody? = nil
        if let ecNT = find("elseClause", in: spans),
           let (_, ecSpans) = tileAlternate(ecNT.nt, from: ecNT.from, to: ecNT.to) {
            elseKeyword = .keyword(.else)
            if let nestedNT = find("ifExpression", in: ecSpans) {
                // `else if` nests as an IfExpr, not as a code block.
                elseBody = .ifExpr(convertIfExpression(nestedNT.nt, from: nestedNT.from, to: nestedNT.to))
            } else if let cbNT = find("codeBlock", in: ecSpans) {
                elseBody = .codeBlock(convertCodeBlock(cbNT.nt, from: cbNT.from, to: cbNT.to))
            } else {
                record(.lookupFailed, "elseClause with neither codeBlock nor ifExpression", from: ecNT.from, to: ecNT.to)
                elseKeyword = nil
            }
        }

        return IfExprSyntax(
            ifKeyword: .keyword(.if),
            conditions: conditions,
            body: body,
            elseKeyword: elseKeyword,
            elseBody: elseBody
        )
    }

    /// switchExpression = "switch" >->( "{" ) expression "{" switchCases? "}" .
    private mutating func convertSwitchExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> SwitchExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return SwitchExprSyntax(subject: MissingExprSyntax(), cases: [])
        }
        var subject: ExprSyntax = ExprSyntax(MissingExprSyntax())
        if let exprNT = find("expression", in: spans) {
            subject = convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
        } else {
            record(.lookupFailed, "no subject expression child", from: from, to: to)
        }
        var cases: [SwitchCaseSyntax] = []
        if let scNT = find("switchCases", in: spans) {
            collectSwitchCases(scNT.nt, from: scNT.from, to: scNT.to, into: &cases)
        }
        return SwitchExprSyntax(
            switchKeyword: .keyword(.switch),
            subject: subject,
            leftBrace: .leftBraceToken(),
            cases: SwitchCaseListSyntax(cases.map { .switchCase($0) }),
            rightBrace: .rightBraceToken()
        )
    }

    /// switchCases  = switchCase switchCases? .
    /// switchCase   = caseLabel statements | defaultLabel statements | conditionalSwitchCase .
    /// caseLabel    = switchCaseAttribute? "case" caseItemList ":" .
    /// defaultLabel = switchCaseAttribute? "default" ":" .
    private mutating func collectSwitchCases(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into cases: inout [SwitchCaseSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let scNT = find("switchCase", in: spans),
           let (_, scSpans) = tileAlternate(scNT.nt, from: scNT.from, to: scNT.to) {
            if find("switchCaseAttribute", in: scSpans) != nil {
                record(.unhandled, "switch case attribute not converted", from: scNT.from, to: scNT.to)
            }
            var label: SwitchCaseSyntax.Label? = nil
            if let clNT = find("caseLabel", in: scSpans),
               let (_, clSpans) = tileAlternate(clNT.nt, from: clNT.from, to: clNT.to) {
                var items: [SwitchCaseItemSyntax] = []
                if let cilNT = find("caseItemList", in: clSpans) {
                    collectCaseItems(cilNT.nt, from: cilNT.from, to: cilNT.to, into: &items)
                }
                if items.count > 1 {
                    for i in 0..<items.count - 1 {
                        items[i] = items[i].with(\.trailingComma, .commaToken())
                    }
                }
                label = .case(SwitchCaseLabelSyntax(
                    caseKeyword: .keyword(.case),
                    caseItems: SwitchCaseItemListSyntax(items),
                    colon: .colonToken()
                ))
            } else if find("defaultLabel", in: scSpans) != nil {
                label = .default(SwitchDefaultLabelSyntax(
                    defaultKeyword: .keyword(.default),
                    colon: .colonToken()
                ))
            }

            if let label {
                var items: [CodeBlockItemSyntax.Item] = []
                if let stmtsNT = find("statements", in: scSpans) {
                    items = convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to)
                }
                cases.append(SwitchCaseSyntax(
                    label: label,
                    statements: CodeBlockItemListSyntax(items.map { CodeBlockItemSyntax(item: $0) })
                ))
            } else {
                record(.unhandled, "switch case form has no converter: \(alternateKind(scSpans))", from: scNT.from, to: scNT.to)
            }
        }
        if let restNT = find("switchCases", in: spans) {
            collectSwitchCases(restNT.nt, from: restNT.from, to: restNT.to, into: &cases)
        }
    }

    /// caseItemList = matchPattern whereClause? | matchPattern whereClause? "," caseItemList .
    private mutating func collectCaseItems(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [SwitchCaseItemSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let mpNT = find("matchPattern", in: spans) {
            // whereClause     = "where" whereExpression .
            // whereExpression = conditionExpression .   ← NOT `expression`
            var whereClause: WhereClauseSyntax? = nil
            if let wcNT = find("whereClause", in: spans) {
                if let (_, wcSpans) = tileAlternate(wcNT.nt, from: wcNT.from, to: wcNT.to),
                   let weNT = find("whereExpression", in: wcSpans),
                   let (_, weSpans) = tileAlternate(weNT.nt, from: weNT.from, to: weNT.to),
                   let ceNT = find(firstOf: ["conditionExpression", "expression"], in: weSpans) {
                    var elements: [ExprSyntax] = []
                    flattenExpression(ceNT.nt, from: ceNT.from, to: ceNT.to, into: &elements)
                    let condition: ExprSyntax = elements.count == 1
                        ? elements[0]
                        : ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(elements)))
                    whereClause = WhereClauseSyntax(whereKeyword: .keyword(.where), condition: condition)
                } else {
                    // Chained `if let`s with no `else` are how a where-clause went missing
                    // from the tree with nothing recorded. Every step gets a diagnostic now.
                    record(.lookupFailed, "whereClause present but its condition could not be resolved",
                           from: wcNT.from, to: wcNT.to)
                }
            }
            items.append(SwitchCaseItemSyntax(
                pattern: convertMatchPattern(mpNT.nt, from: mpNT.from, to: mpNT.to),
                whereClause: whereClause
            ))
        }
        if let restNT = find("caseItemList", in: spans) {
            collectCaseItems(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    /// matchPattern = wildcardPattern | identifierPattern | valueBindingPattern
    ///              | tupleMatchPattern | enumCasePattern | optionalPattern
    ///              | typeCastingPattern | @prefer expressionPattern .
    ///
    /// Only the forms with a settled shape are converted; the rest record `.unhandled`.
    ///
    /// `binding` = we are inside a `valueBindingPattern` (`case let y`). That changes the
    /// answer for a bare identifier: swift-syntax makes it an `IdentifierPattern` (it BINDS a
    /// new name), whereas in a plain match position the same spelling is an `ExpressionPattern`
    /// (it COMPARES against an existing value). Our grammar can't express the distinction —
    /// `matchPattern = @prefer expressionPattern` prunes the identifierPattern alternate before
    /// the converter sees it — so the binding context is re-applied here.
    private mutating func convertMatchPattern(_ nt: GrammarNode, from: CharPosition, to: CharPosition, binding: Bool = false) -> PatternSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingPattern(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        if find("wildcardPattern", in: spans) != nil {
            return PatternSyntax(WildcardPatternSyntax(wildcard: .wildcardToken()))
        }
        if let d = find("identifierPattern", in: spans) {
            let name = collectTerminalText(d.nt, from: d.from, to: d.to)
            return PatternSyntax(IdentifierPatternSyntax(identifier: .identifier(name)))
        }
        // expressionPattern = expression .  (`case 1:`, `case .foo:` — swift-syntax
        // wraps the expression in ExpressionPatternSyntax.)
        if let d = find("expressionPattern", in: spans),
           let (_, epSpans) = tileAlternate(d.nt, from: d.from, to: d.to),
           let exprNT = find("expression", in: epSpans) {
            let expr = convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
            if binding, let ref = expr.as(DeclReferenceExprSyntax.self), ref.argumentNames == nil,
               case .identifier(let name) = ref.baseName.tokenKind {
                return PatternSyntax(IdentifierPatternSyntax(identifier: .identifier(name)))
            }
            return PatternSyntax(ExpressionPatternSyntax(expression: expr))
        }
        // valueBindingPattern = ("let"|"var"|…) matchPattern .
        if let d = find("valueBindingPattern", in: spans),
           let (_, vbSpans) = tileAlternate(d.nt, from: d.from, to: d.to),
           let innerNT = find("matchPattern", in: vbSpans) {
            let text = collectTerminalText(d.nt, from: d.from, to: d.to)
            let specifier: TokenSyntax = text.hasPrefix("var") ? .keyword(.var) : .keyword(.let)
            if !text.hasPrefix("var") && !text.hasPrefix("let") {
                record(.unhandled, "borrowing/consuming value-binding pattern not converted", from: from, to: to)
            }
            return PatternSyntax(ValueBindingPatternSyntax(
                bindingSpecifier: specifier,
                pattern: convertMatchPattern(innerNT.nt, from: innerNT.from, to: innerNT.to, binding: true)
            ))
        }
        return missingPattern(.unhandled, "match pattern form has no converter: \(alternateKind(spans))", from: from, to: to)
    }

    /// conditionList = condition | condition "," conditionList .
    /// condition     = conditionExpression | availabilityCondition | caseCondition
    ///               | optionalBindingCondition .
    private mutating func convertConditionList(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ConditionElementListSyntax {
        var items: [ConditionElementSyntax] = []
        collectConditions(nt, from: from, to: to, into: &items)
        if items.count > 1 {
            for i in 0..<items.count - 1 {
                items[i] = items[i].with(\.trailingComma, .commaToken())
            }
        }
        return ConditionElementListSyntax(items)
    }

    private mutating func collectConditions(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [ConditionElementSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let cNT = find("condition", in: spans),
           let (_, cSpans) = tileAlternate(cNT.nt, from: cNT.from, to: cNT.to) {
            if let obNT = find("optionalBindingCondition", in: cSpans) {
                items.append(ConditionElementSyntax(condition: .optionalBinding(
                    convertOptionalBinding(obNT.nt, from: obNT.from, to: obNT.to)
                )))
            } else if let ceNT = find("conditionExpression", in: cSpans) {
                // conditionExpression mirrors `expression` (same two alternates), so the
                // flat-sequence builder handles it — just without the assignment alternate.
                var elements: [ExprSyntax] = []
                flattenExpression(ceNT.nt, from: ceNT.from, to: ceNT.to, into: &elements)
                let expr: ExprSyntax = elements.count == 1
                    ? elements[0]
                    : ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(elements)))
                items.append(ConditionElementSyntax(condition: .expression(expr)))
            } else if let acNT = find("availabilityCondition", in: cSpans) {
                items.append(ConditionElementSyntax(condition: .availability(
                    convertAvailabilityCondition(acNT.nt, from: acNT.from, to: acNT.to)
                )))
            } else {
                record(.unhandled, "condition kind has no converter: \(alternateKind(cSpans))", from: cNT.from, to: cNT.to)
            }
        }
        if let restNT = find("conditionList", in: spans) {
            collectConditions(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    /// availabilityCondition = "#available" "(" availabilityArguments ")" .
    /// availabilityCondition = "#unavailable" "(" availabilityArguments ")" .
    ///
    /// The CONDITION form takes only platform-version pairs and `*` — the labelled arguments
    /// (`message:`, `introduced:`) are attribute-only, which is why `@available` needed its own
    /// `availabilityAttributeArguments`. The element shapes are shared, so the same collector runs
    /// over both: `availabilityArgument` has the same alternate names minus the labelled one.
    private mutating func convertAvailabilityCondition(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> AvailabilityConditionSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return AvailabilityConditionSyntax(availabilityKeyword: .poundAvailableToken(), availabilityArguments: [])
        }
        let isUnavailable = spansContainKeyword(spans, "#unavailable")
        var args: [AvailabilityArgumentSyntax] = []
        if let listNT = find("availabilityArguments", in: spans) {
            collectAvailabilityArguments(listNT.nt, from: listNT.from, to: listNT.to, into: &args)
        } else {
            record(.lookupFailed, "no availabilityArguments child", from: from, to: to)
        }
        if args.count > 1 {
            for i in 0..<args.count - 1 {
                args[i] = args[i].with(\.trailingComma, .commaToken())
            }
        }
        return AvailabilityConditionSyntax(
            availabilityKeyword: isUnavailable ? .poundUnavailableToken() : .poundAvailableToken(),
            leftParen: .leftParenToken(),
            availabilityArguments: AvailabilityArgumentListSyntax(args),
            rightParen: .rightParenToken()
        )
    }

    /// optionalBindingCondition = "let" bindingPattern initializer? | "var" bindingPattern initializer? .
    private mutating func convertOptionalBinding(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> OptionalBindingConditionSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return OptionalBindingConditionSyntax(bindingSpecifier: .keyword(.let), pattern: MissingPatternSyntax())
        }
        let isVar = spansContainKeyword(spans, "var")
        var pattern: PatternSyntax = PatternSyntax(MissingPatternSyntax())
        var typeAnnotation: TypeAnnotationSyntax? = nil
        if let bpNT = find("bindingPattern", in: spans) {
            (pattern, typeAnnotation) = convertBindingPattern(bpNT.nt, from: bpNT.from, to: bpNT.to)
        } else {
            record(.lookupFailed, "no bindingPattern child", from: from, to: to)
        }
        var initializer: InitializerClauseSyntax? = nil
        if let initNT = find("initializer", in: spans) {
            initializer = convertInitializer(initNT.nt, from: initNT.from, to: initNT.to)
        }
        return OptionalBindingConditionSyntax(
            bindingSpecifier: .keyword(isVar ? .var : .let),
            pattern: pattern,
            typeAnnotation: typeAnnotation,
            initializer: initializer
        )
    }

    /// guardStatement = "guard" >->( "{" ) conditionList "else" codeBlock .
    private mutating func convertGuardStatement(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> StmtSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return StmtSyntax(GuardStmtSyntax(conditions: [], body: CodeBlockSyntax(statements: [])))
        }
        var conditions = ConditionElementListSyntax([])
        if let clNT = find("conditionList", in: spans) {
            conditions = convertConditionList(clNT.nt, from: clNT.from, to: clNT.to)
        } else {
            record(.lookupFailed, "no conditionList child", from: from, to: to)
        }
        var body = CodeBlockSyntax(statements: [])
        if let cbNT = find("codeBlock", in: spans) {
            body = convertCodeBlock(cbNT.nt, from: cbNT.from, to: cbNT.to)
        } else {
            record(.lookupFailed, "no codeBlock child", from: from, to: to)
        }
        return StmtSyntax(GuardStmtSyntax(
            guardKeyword: .keyword(.guard),
            conditions: conditions,
            elseKeyword: .keyword(.else),
            body: body
        ))
    }

    // MARK: - Loop and do statements

    /// loopStatement        = forInStatement | whileStatement | repeatWhileStatement .
    /// forInStatement       = "for" "try"? "await"? "unsafe"? "case"? pattern "in" expression whereClause? codeBlock .
    /// whileStatement       = "while" >->( "{" ) conditionList codeBlock .
    /// repeatWhileStatement = "repeat" codeBlock "while" >->( "{" ) conditionExpression .
    private mutating func convertLoopStatement(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> StmtSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        if let d = find("forInStatement", in: spans) {
            return convertForInStatement(d.nt, from: d.from, to: d.to)
        }
        if let d = find("whileStatement", in: spans),
           let (_, wSpans) = tileAlternate(d.nt, from: d.from, to: d.to) {
            var conditions = ConditionElementListSyntax([])
            if let clNT = find("conditionList", in: wSpans) {
                conditions = convertConditionList(clNT.nt, from: clNT.from, to: clNT.to)
            }
            var body = CodeBlockSyntax(statements: [])
            if let cbNT = find("codeBlock", in: wSpans) {
                body = convertCodeBlock(cbNT.nt, from: cbNT.from, to: cbNT.to)
            }
            return StmtSyntax(WhileStmtSyntax(
                whileKeyword: .keyword(.while), conditions: conditions, body: body
            ))
        }
        if let d = find("repeatWhileStatement", in: spans),
           let (_, rSpans) = tileAlternate(d.nt, from: d.from, to: d.to) {
            var body = CodeBlockSyntax(statements: [])
            if let cbNT = find("codeBlock", in: rSpans) {
                body = convertCodeBlock(cbNT.nt, from: cbNT.from, to: cbNT.to)
            }
            var condition: ExprSyntax = ExprSyntax(MissingExprSyntax())
            if let ceNT = find("conditionExpression", in: rSpans) {
                var elements: [ExprSyntax] = []
                flattenExpression(ceNT.nt, from: ceNT.from, to: ceNT.to, into: &elements)
                condition = elements.count == 1
                    ? elements[0]
                    : ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(elements)))
            }
            return StmtSyntax(RepeatStmtSyntax(
                repeatKeyword: .keyword(.repeat), body: body,
                whileKeyword: .keyword(.while), condition: condition
            ))
        }
        record(.unhandled, "loop kind has no converter: \(alternateKind(spans))", from: from, to: to)
        return nil
    }

    private mutating func convertForInStatement(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> StmtSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        if spansContainKeyword(spans, "try") || spansContainKeyword(spans, "await") || spansContainKeyword(spans, "unsafe") {
            record(.unhandled, "for-in with try/await/unsafe not converted", from: from, to: to)
        }
        let caseKeyword: TokenSyntax? = spansContainKeyword(spans, "case") ? .keyword(.case) : nil

        var pattern: PatternSyntax = PatternSyntax(MissingPatternSyntax())
        if let mpNT = find("matchPattern", in: spans) {
            pattern = convertMatchPattern(mpNT.nt, from: mpNT.from, to: mpNT.to)
        } else if let bpNT = find("bindingPattern", in: spans) {
            // for-in binds, so a bare identifier is an IdentifierPattern here.
            (pattern, _) = convertBindingPattern(bpNT.nt, from: bpNT.from, to: bpNT.to)
        } else {
            record(.lookupFailed, "no pattern child", from: from, to: to)
        }

        var sequence: ExprSyntax = ExprSyntax(MissingExprSyntax())
        if let exprNT = find("expression", in: spans) {
            sequence = convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
        } else {
            record(.lookupFailed, "no sequence expression child", from: from, to: to)
        }

        var whereClause: WhereClauseSyntax? = nil
        if let wcNT = find("whereClause", in: spans) {
            whereClause = convertWhereClause(wcNT.nt, from: wcNT.from, to: wcNT.to)
        }
        var body = CodeBlockSyntax(statements: [])
        if let cbNT = find("codeBlock", in: spans) {
            body = convertCodeBlock(cbNT.nt, from: cbNT.from, to: cbNT.to)
        }
        return StmtSyntax(ForStmtSyntax(
            forKeyword: .keyword(.for),
            caseKeyword: caseKeyword,
            pattern: pattern,
            inKeyword: .keyword(.in),
            sequence: sequence,
            whereClause: whereClause,
            body: body
        ))
    }

    /// whereClause     = "where" whereExpression .
    /// whereExpression = conditionExpression .
    private mutating func convertWhereClause(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> WhereClauseSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let weNT = find("whereExpression", in: spans),
              let (_, weSpans) = tileAlternate(weNT.nt, from: weNT.from, to: weNT.to),
              let ceNT = find(firstOf: ["conditionExpression", "expression"], in: weSpans) else {
            record(.lookupFailed, "whereClause condition could not be resolved", from: from, to: to)
            return nil
        }
        var elements: [ExprSyntax] = []
        flattenExpression(ceNT.nt, from: ceNT.from, to: ceNT.to, into: &elements)
        let condition: ExprSyntax = elements.count == 1
            ? elements[0]
            : ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(elements)))
        return WhereClauseSyntax(whereKeyword: .keyword(.where), condition: condition)
    }

    /// doStatement  = "do" throwsClause? codeBlock catchClauses? .
    /// catchClause  = "catch" catchPatternList? codeBlock .
    /// catchPattern = matchPattern whereClause? | whereClause .
    private mutating func convertDoStatement(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> StmtSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return StmtSyntax(DoStmtSyntax(body: CodeBlockSyntax(statements: [])))
        }
        var throwsClause: ThrowsClauseSyntax? = nil
        if find("throwsClause", in: spans) != nil {
            throwsClause = ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
        }
        var body = CodeBlockSyntax(statements: [])
        if let cbNT = find("codeBlock", in: spans) {
            body = convertCodeBlock(cbNT.nt, from: cbNT.from, to: cbNT.to)
        }
        var catches: [CatchClauseSyntax] = []
        if let ccNT = find("catchClauses", in: spans) {
            collectCatchClauses(ccNT.nt, from: ccNT.from, to: ccNT.to, into: &catches)
        }
        return StmtSyntax(DoStmtSyntax(
            doKeyword: .keyword(.do),
            throwsClause: throwsClause,
            body: body,
            catchClauses: CatchClauseListSyntax(catches)
        ))
    }

    private mutating func collectCatchClauses(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into catches: inout [CatchClauseSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let ccNT = find("catchClause", in: spans),
           let (_, cSpans) = tileAlternate(ccNT.nt, from: ccNT.from, to: ccNT.to) {
            var items: [CatchItemSyntax] = []
            if let listNT = find("catchPatternList", in: cSpans) {
                collectCatchItems(listNT.nt, from: listNT.from, to: listNT.to, into: &items)
            }
            if items.count > 1 {
                for i in 0..<items.count - 1 {
                    items[i] = items[i].with(\.trailingComma, .commaToken())
                }
            }
            var body = CodeBlockSyntax(statements: [])
            if let cbNT = find("codeBlock", in: cSpans) {
                body = convertCodeBlock(cbNT.nt, from: cbNT.from, to: cbNT.to)
            }
            catches.append(CatchClauseSyntax(
                catchKeyword: .keyword(.catch),
                catchItems: CatchItemListSyntax(items),
                body: body
            ))
        }
        if let restNT = find("catchClauses", in: spans) {
            collectCatchClauses(restNT.nt, from: restNT.from, to: restNT.to, into: &catches)
        }
    }

    private mutating func collectCatchItems(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [CatchItemSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let cpNT = find("catchPattern", in: spans),
           let (_, cpSpans) = tileAlternate(cpNT.nt, from: cpNT.from, to: cpNT.to) {
            var pattern: PatternSyntax? = nil
            if let mpNT = find("matchPattern", in: cpSpans) {
                pattern = convertMatchPattern(mpNT.nt, from: mpNT.from, to: mpNT.to)
            }
            var whereClause: WhereClauseSyntax? = nil
            if let wcNT = find("whereClause", in: cpSpans) {
                whereClause = convertWhereClause(wcNT.nt, from: wcNT.from, to: wcNT.to)
            }
            items.append(CatchItemSyntax(pattern: pattern, whereClause: whereClause))
        }
        if let restNT = find("catchPatternList", in: spans) {
            collectCatchItems(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    // MARK: - Deinitializer and subscript declarations

    /// deinitializerDeclaration = attributes? declarationModifiers? "deinit" "async"? codeBlock? .
    private mutating func convertDeinitializerDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> DeinitializerDeclSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return DeinitializerDeclSyntax()
        }
        var attributes = AttributeListSyntax([])
        if let attrNT = find("attributes", in: spans) {
            attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
        }
        var modifiers = DeclModifierListSyntax([])
        if let modsNT = find("declarationModifiers", in: spans) {
            modifiers = convertDeclarationModifiers(modsNT.nt, from: modsNT.from, to: modsNT.to)
        }
        // swift-syntax has FOUR distinct effect-specifier nodes, one per position:
        // FunctionEffectSpecifiers (decls), TypeEffectSpecifiers (function types / closures),
        // AccessorEffectSpecifiers, and this one. They carry the same words, not the same type.
        var effects: DeinitializerEffectSpecifiersSyntax? = nil
        if spansContainKeyword(spans, "async") {
            effects = DeinitializerEffectSpecifiersSyntax(asyncSpecifier: .keyword(.async))
        }
        var body: CodeBlockSyntax? = nil
        if let cbNT = find("codeBlock", in: spans) {
            body = convertCodeBlock(cbNT.nt, from: cbNT.from, to: cbNT.to)
        }
        return DeinitializerDeclSyntax(
            attributes: attributes,
            modifiers: modifiers,
            deinitKeyword: .keyword(.deinit),
            effectSpecifiers: effects,
            body: body
        )
    }

    /// subscriptDeclaration = subscriptHead subscriptResult genericWhereClause? getterSetterBlock .
    /// subscriptHead        = attributes? declarationModifiers? "subscript" genericParameterClause? parameterClause .
    /// subscriptResult      = "->" type .
    private mutating func convertSubscriptDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> SubscriptDeclSyntax {
        let emptyClause = FunctionParameterClauseSyntax(parameters: [])
        let emptyReturn = ReturnClauseSyntax(arrow: .arrowToken(), type: MissingTypeSyntax())
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return SubscriptDeclSyntax(parameterClause: emptyClause, returnClause: emptyReturn)
        }
        var attributes = AttributeListSyntax([])
        var modifiers = DeclModifierListSyntax([])
        var generics: GenericParameterClauseSyntax? = nil
        var parameterClause = emptyClause
        if let headNT = find("subscriptHead", in: spans),
           let (_, hSpans) = tileAlternate(headNT.nt, from: headNT.from, to: headNT.to) {
            if let attrNT = find("attributes", in: hSpans) {
                attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
            }
            if let modsNT = find("declarationModifiers", in: hSpans) {
                modifiers = convertDeclarationModifiers(modsNT.nt, from: modsNT.from, to: modsNT.to)
            }
            if let gpNT = find("genericParameterClause", in: hSpans) {
                generics = convertGenericParameterClause(gpNT.nt, from: gpNT.from, to: gpNT.to)
            }
            if let pcNT = find("parameterClause", in: hSpans) {
                parameterClause = convertParameterClause(pcNT.nt, from: pcNT.from, to: pcNT.to)
            }
        } else {
            record(.lookupFailed, "no subscriptHead child", from: from, to: to)
        }
        var returnClause = emptyReturn
        if let resNT = find("subscriptResult", in: spans),
           let (_, rSpans) = tileAlternate(resNT.nt, from: resNT.from, to: resNT.to),
           let typeNT = find("type", in: rSpans) {
            returnClause = ReturnClauseSyntax(
                arrow: .arrowToken(), type: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
            )
        } else {
            record(.lookupFailed, "no subscriptResult/type child", from: from, to: to)
        }
        if find("genericWhereClause", in: spans) != nil {
            record(.unhandled, "genericWhereClause not converted", from: from, to: to)
        }
        var accessorBlock: AccessorBlockSyntax? = nil
        if let gsNT = find("getterSetterBlock", in: spans) {
            accessorBlock = convertGetterSetterBlock(gsNT.nt, from: gsNT.from, to: gsNT.to)
        }
        return SubscriptDeclSyntax(
            attributes: attributes,
            modifiers: modifiers,
            subscriptKeyword: .keyword(.subscript),
            genericParameterClause: generics,
            parameterClause: parameterClause,
            returnClause: returnClause,
            accessorBlock: accessorBlock
        )
    }

    // MARK: - Accessor blocks

    /// getterSetterBlock  = codeBlock | @prefer accessorBlockBrace .
    /// accessorBlockBrace = "{" accessorClauseList "}" .
    ///
    /// swift-syntax's `AccessorBlock.accessors` is an either/or: a list of accessor declarations,
    /// OR — for the shorthand computed property `var x: Int { 0 }` — a plain code block.
    private mutating func convertGetterSetterBlock(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> AccessorBlockSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return AccessorBlockSyntax(accessors: .getter([]))
        }
        if let braceNT = find("accessorBlockBrace", in: spans),
           let (_, braceSpans) = tileAlternate(braceNT.nt, from: braceNT.from, to: braceNT.to) {
            var accessors: [AccessorDeclSyntax] = []
            if let listNT = find("accessorClauseList", in: braceSpans) {
                collectAccessorClauses(listNT.nt, from: listNT.from, to: listNT.to, into: &accessors)
            }
            return AccessorBlockSyntax(
                leftBrace: .leftBraceToken(),
                accessors: .accessors(AccessorDeclListSyntax(accessors)),
                rightBrace: .rightBraceToken()
            )
        }
        // The shorthand `{ 0 }` getter: swift-syntax keeps the statements directly.
        if let cbNT = find("codeBlock", in: spans),
           let (_, cbSpans) = tileAlternate(cbNT.nt, from: cbNT.from, to: cbNT.to) {
            var items: [CodeBlockItemSyntax.Item] = []
            if let stmtsNT = find("statements", in: cbSpans) {
                items = convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to)
            }
            return AccessorBlockSyntax(
                leftBrace: .leftBraceToken(),
                accessors: .getter(CodeBlockItemListSyntax(items.map { CodeBlockItemSyntax(item: $0) })),
                rightBrace: .rightBraceToken()
            )
        }
        record(.lookupFailed, "getterSetterBlock with neither brace nor codeBlock", from: from, to: to)
        return AccessorBlockSyntax(accessors: .getter([]))
    }

    /// accessorClauseList  = accessorClauseEntry accessorClauseList? .
    /// accessorClauseEntry = getterClause | setterClause | initAccessorClause | coroutineAccessorClause .
    /// getterClause        = attributes? accessorModifier? "get" accessorEffects? codeBlock? .
    /// setterClause        = attributes? accessorModifier? "set" setterName? accessorEffects? codeBlock? .
    private mutating func collectAccessorClauses(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into accessors: inout [AccessorDeclSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let entryNT = find("accessorClauseEntry", in: spans),
           let (_, eSpans) = tileAlternate(entryNT.nt, from: entryNT.from, to: entryNT.to) {
            if let clauseNT = find(firstOf: ["getterClause", "setterClause"], in: eSpans),
               let (_, cSpans) = tileAlternate(clauseNT.nt, from: clauseNT.from, to: clauseNT.to) {
                let isGetter = clauseNT.nt.name == "getterClause"
                var attributes = AttributeListSyntax([])
                if let attrNT = find("attributes", in: cSpans) {
                    attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
                }
                var modifier: DeclModifierSyntax? = nil
                if let modNT = find("accessorModifier", in: cSpans) {
                    modifier = DeclModifierSyntax(
                        name: modifierToken(collectTerminalText(modNT.nt, from: modNT.from, to: modNT.to))
                    )
                }
                var parameters: AccessorParametersSyntax? = nil
                if let snNT = find("setterName", in: cSpans),
                   let (_, snSpans) = tileAlternate(snNT.nt, from: snNT.from, to: snNT.to),
                   let idNT = find("hardIdentifier", in: snSpans) {
                    parameters = AccessorParametersSyntax(
                        name: .identifier(collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to))
                    )
                }
                var effects: AccessorEffectSpecifiersSyntax? = nil
                if let effNT = find("accessorEffects", in: cSpans) {
                    let text = collectTerminalText(effNT.nt, from: effNT.from, to: effNT.to)
                    effects = AccessorEffectSpecifiersSyntax(
                        asyncSpecifier: text.contains("async") ? .keyword(.async) : nil,
                        throwsClause: text.contains("throws")
                            ? ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws)) : nil
                    )
                }
                var body: CodeBlockSyntax? = nil
                if let cbNT = find("codeBlock", in: cSpans) {
                    body = convertCodeBlock(cbNT.nt, from: cbNT.from, to: cbNT.to)
                }
                accessors.append(AccessorDeclSyntax(
                    attributes: attributes,
                    modifier: modifier,
                    accessorSpecifier: isGetter ? .keyword(.get) : .keyword(.set),
                    parameters: parameters,
                    effectSpecifiers: effects,
                    body: body
                ))
            } else {
                record(.unhandled, "accessor kind has no converter: \(alternateKind(eSpans))", from: entryNT.from, to: entryNT.to)
            }
        }
        if let restNT = find("accessorClauseList", in: spans) {
            collectAccessorClauses(restNT.nt, from: restNT.from, to: restNT.to, into: &accessors)
        }
    }

    // MARK: - Attributes and generic parameter clauses

    /// attributes    = attribute attributes? | conditionalCompilationAttributes attributes? .
    /// attributeName = attributeHeadName typeGenericArgumentClause?
    ///               | attributeHeadName typeGenericArgumentClause? "." typeIdentifier | "rethrows" .
    ///
    /// swift-syntax: `AttributeListSyntax` of `AttributeSyntax(atSign:attributeName:…)`, where
    /// `attributeName` is a TYPE. Arguments are a large enum of specific shapes
    /// (`AttributeSyntax.Arguments`), but our grammar collects them as `balancedTokens` — an
    /// unstructured token soup — so an attribute WITH arguments cannot be converted faithfully
    /// here and records `.unhandled` instead of guessing.
    private mutating func convertAttributes(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> AttributeListSyntax {
        var items: [AttributeListSyntax.Element] = []
        collectAttributes(nt, from: from, to: to, into: &items)
        return AttributeListSyntax(items)
    }

    private mutating func collectAttributes(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [AttributeListSyntax.Element]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if find("conditionalCompilationAttributes", in: spans) != nil {
            record(.unhandled, "#if-conditional attributes not converted", from: from, to: to)
        } else if let attrNT = find("attribute", in: spans) {
            if let attribute = convertAttribute(attrNT.nt, from: attrNT.from, to: attrNT.to) {
                items.append(.attribute(attribute))
            }
        }
        if let restNT = find("attributes", in: spans) {
            collectAttributes(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    private mutating func convertAttribute(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> AttributeSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        // `@available` now has a real argument grammar, so it converts.
        if let availNT = find("availableAttribute", in: spans) {
            return convertAvailableAttribute(availNT.nt, from: availNT.from, to: availNT.to)
        }
        // Every OTHER argument form is still balanced-token soup at this level — see the note above.
        if find(firstOf: ["attributeArgumentClause", "attributeArgumentExprClause",
                          "macroRoleArguments", "abiDeclaration"], in: spans) != nil {
            // Name the attribute so the triage says WHICH argument shapes actually occur.
            let head = String(input[from..<to]).prefix(while: { $0 != "(" })
                .trimmingCharacters(in: .whitespacesAndNewlines)
            record(.unhandled, "attribute with an argument clause not converted: \(head)", from: from, to: to)
            return nil
        }
        // The special attributes with bespoke grammars — `@isolated(any)`, `@attached(…)`,
        // `@freestanding(…)` — spell their name as a bare LITERAL in the alternate, so there is
        // no `attributeName` child at all and no recognised argument-clause node either. That is
        // an unconverted FORM, not a failed lookup; classifying it as `.lookupFailed` wrongly
        // reported a converter bug.
        guard let nameNT = find("attributeName", in: spans),
              let (_, nameSpans) = tileAlternate(nameNT.nt, from: nameNT.from, to: nameNT.to) else {
            let head = String(input[from..<to]).prefix(while: { $0 != "(" })
                .trimmingCharacters(in: .whitespacesAndNewlines)
            record(.unhandled, "attribute with a bespoke argument grammar not converted: \(head)", from: from, to: to)
            return nil
        }
        if find("typeIdentifier", in: nameSpans) != nil {
            record(.unhandled, "dot-qualified attribute name not converted", from: from, to: to)
            return nil
        }
        guard let headNT = find("attributeHeadName", in: nameSpans) else {
            // The bare `@rethrows` alternate has no attributeHeadName.
            let text = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
            guard !text.isEmpty else {
                record(.lookupFailed, "attributeName resolved to no text", from: from, to: to)
                return nil
            }
            return AttributeSyntax(
                atSign: .atSignToken(),
                attributeName: IdentifierTypeSyntax(name: .identifier(text))
            )
        }
        var generics: GenericArgumentClauseSyntax? = nil
        if let gNT = find(firstOf: ["typeGenericArgumentClause", "genericArgumentClause"], in: nameSpans) {
            generics = convertGenericArgumentClause(gNT.nt, from: gNT.from, to: gNT.to)
        }
        let name = collectTerminalText(headNT.nt, from: headNT.from, to: headNT.to)
        return AttributeSyntax(
            atSign: .atSignToken(),
            attributeName: IdentifierTypeSyntax(name: .identifier(name), genericArgumentClause: generics)
        )
    }

    /// availableAttribute            = "@" >s< "available" >s< "(" availabilityAttributeArguments ")" .
    /// availabilityAttributeArgument = "*" | platformName platformVersion?
    ///                               | availabilityLabel ":" availabilityValue .
    private mutating func convertAvailableAttribute(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> AttributeSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        var args: [AvailabilityArgumentSyntax] = []
        if let listNT = find("availabilityAttributeArguments", in: spans) {
            collectAvailabilityArguments(listNT.nt, from: listNT.from, to: listNT.to, into: &args)
        } else {
            record(.lookupFailed, "no availabilityAttributeArguments child", from: from, to: to)
        }
        if args.count > 1 {
            for i in 0..<args.count - 1 {
                args[i] = args[i].with(\.trailingComma, .commaToken())
            }
        }
        return AttributeSyntax(
            atSign: .atSignToken(),
            attributeName: IdentifierTypeSyntax(name: .identifier("available")),
            leftParen: .leftParenToken(),
            arguments: .availability(AvailabilityArgumentListSyntax(args)),
            rightParen: .rightParenToken()
        )
    }

    private mutating func collectAvailabilityArguments(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into args: inout [AvailabilityArgumentSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let argNT = find(firstOf: ["availabilityAttributeArgument", "availabilityArgument"], in: spans),
           let (_, aSpans) = tileAlternate(argNT.nt, from: argNT.from, to: argNT.to) {
            if let labelNT = find("availabilityLabel", in: aSpans),
               let valueNT = find("availabilityValue", in: aSpans) {
                let label = collectTerminalText(labelNT.nt, from: labelNT.from, to: labelNT.to)
                if let value = availabilityValue(valueNT) {
                    args.append(AvailabilityArgumentSyntax(argument: .availabilityLabeledArgument(
                        AvailabilityLabeledArgumentSyntax(
                            label: availabilityToken(label), colon: .colonToken(), value: value
                        )
                    )))
                }
            } else if let platNT = find("platformName", in: aSpans) {
                let platform = collectTerminalText(platNT.nt, from: platNT.from, to: platNT.to)
                // WITH a version it is a version restriction; WITHOUT one it is a bare token —
                // `@available(*, deprecated)` gives `.token(keyword(deprecated))` and
                // `@available(macOS, introduced: …)` gives `.token(identifier("macOS"))`,
                // NOT a PlatformVersion with a nil version.
                if let verNT = find("platformVersion", in: aSpans) {
                    args.append(AvailabilityArgumentSyntax(argument: .availabilityVersionRestriction(
                        PlatformVersionSyntax(platform: .identifier(platform), version: versionTuple(verNT))
                    )))
                } else {
                    args.append(AvailabilityArgumentSyntax(argument: .token(availabilityToken(platform))))
                }
            } else {
                // The bare `*` wildcard.
                args.append(AvailabilityArgumentSyntax(argument: .token(.binaryOperator("*"))))
            }
        }
        if let restNT = find(firstOf: ["availabilityAttributeArguments", "availabilityArguments"], in: spans) {
            collectAvailabilityArguments(restNT.nt, from: restNT.from, to: restNT.to, into: &args)
        }
    }

    /// The availability spec words are KEYWORD tokens in swift-syntax, not identifiers — both as
    /// bare arguments (`deprecated`) and as labels (`message:`). Anything else (a platform name
    /// such as `macOS`) stays an identifier.
    private func availabilityToken(_ text: String) -> TokenSyntax {
        switch text {
        case "deprecated":  return .keyword(.deprecated)
        case "unavailable": return .keyword(.unavailable)
        case "introduced":  return .keyword(.introduced)
        case "obsoleted":   return .keyword(.obsoleted)
        case "message":     return .keyword(.message)
        case "renamed":     return .keyword(.renamed)
        case "noasync":     return .keyword(.noasync)
        default:            return .identifier(text)
        }
    }

    /// availabilityValue = platformVersion | staticStringLiteral | hardIdentifier .
    private mutating func availabilityValue(_ span: NTSpan) -> AvailabilityLabeledArgumentSyntax.Value? {
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to) else {
            record(.lookupFailed, "no alternate tiles the span", from: span.from, to: span.to)
            return nil
        }
        if let verNT = find("platformVersion", in: spans) {
            return .version(versionTuple(verNT))
        }
        let text = collectTerminalText(span.nt, from: span.from, to: span.to)
        if text.hasPrefix("\"") {
            // SimpleStringLiteralExpr, not StringLiteralExpr: an availability message cannot
            // contain interpolation, and swift-syntax gives it the restricted node type.
            return .string(SimpleStringLiteralExprSyntax(
                openingQuote: .stringQuoteToken(),
                segments: SimpleStringLiteralSegmentListSyntax([
                    StringSegmentSyntax(content: .stringSegment(String(text.dropFirst().dropLast())))
                ]),
                closingQuote: .stringQuoteToken()
            ))
        }
        record(.unhandled, "availability value is neither a version nor a string", from: span.from, to: span.to)
        return nil
    }

    /// platformVersion = decimalDigits [ "." decimalDigits [ "." decimalDigits ] ] .
    /// swift-syntax splits this into a major token plus a list of `.n` components.
    private mutating func versionTuple(_ span: NTSpan) -> VersionTupleSyntax {
        let text = collectTerminalText(span.nt, from: span.from, to: span.to)
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let components = parts.dropFirst().map {
            VersionComponentSyntax(period: .periodToken(), number: .integerLiteral($0))
        }
        return VersionTupleSyntax(
            major: .integerLiteral(parts.first ?? "0"),
            components: VersionComponentListSyntax(Array(components))
        )
    }

    /// genericParameterClause = openAngle genericParameterList ","? closeAngle .
    /// genericParameterList   = genericParameter | genericParameter "," genericParameterList .
    /// genericParameter       = attributes? typeName [ ":" "~"? ( typeIdentifier | protocolCompositionType ) ]
    ///                        | attributes? "let" typeName ":" type .
    private mutating func convertGenericParameterClause(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> GenericParameterClauseSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return GenericParameterClauseSyntax(parameters: [])
        }
        var params: [GenericParameterSyntax] = []
        if let listNT = find("genericParameterList", in: spans) {
            collectGenericParameters(listNT.nt, from: listNT.from, to: listNT.to, into: &params)
        }
        if params.count > 1 {
            for i in 0..<params.count - 1 {
                params[i] = params[i].with(\.trailingComma, .commaToken())
            }
        }
        return GenericParameterClauseSyntax(
            leftAngle: .leftAngleToken(),
            parameters: GenericParameterListSyntax(params),
            rightAngle: .rightAngleToken()
        )
    }

    private mutating func collectGenericParameters(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into params: inout [GenericParameterSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let gpNT = find("genericParameter", in: spans),
           let (_, gpSpans) = tileAlternate(gpNT.nt, from: gpNT.from, to: gpNT.to) {
            var attributes = AttributeListSyntax([])
            if let attrNT = find("attributes", in: gpSpans) {
                attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
            }
            if spansContainKeyword(gpSpans, "let") {
                record(.unhandled, "value generic parameter (`let N: Int`) not converted", from: gpNT.from, to: gpNT.to)
            }
            if spansContainKeyword(gpSpans, "~") {
                record(.unhandled, "inverse generic constraint (`~Copyable`) not converted", from: gpNT.from, to: gpNT.to)
            }
            guard let nameNT = find("typeName", in: gpSpans) else {
                record(.lookupFailed, "no typeName child", from: gpNT.from, to: gpNT.to)
                return
            }
            // `convertType` dispatches over `type`'s alternates; handing it a `typeIdentifier`
            // node makes it tile THAT node's alternates, find none of the names it knows, and
            // fall through to raw text. Call the right converter for the right level.
            var inherited: TypeSyntax? = nil
            if let tiNT = find("typeIdentifier", in: gpSpans) {
                inherited = convertTypeIdentifier(tiNT.nt, from: tiNT.from, to: tiNT.to)
            } else if let pcNT = find("protocolCompositionType", in: gpSpans) {
                inherited = convertType(pcNT.nt, from: pcNT.from, to: pcNT.to)
            }
            params.append(GenericParameterSyntax(
                attributes: attributes,
                name: .identifier(collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)),
                colon: inherited == nil ? nil : .colonToken(),
                inheritedType: inherited
            ))
        }
        if let restNT = find("genericParameterList", in: spans) {
            collectGenericParameters(restNT.nt, from: restNT.from, to: restNT.to, into: &params)
        }
    }

    // MARK: - Declaration modifiers

    /// declarationModifiers = declarationModifier declarationModifiers? .
    /// declarationModifier  = "class" | "final" | "static" | … | accessLevelModifier
    ///                      | mutationModifier | actorIsolationModifier .
    /// accessLevelModifier  = "private" | "private" "(" "set" ")" | … | "open" .
    /// actorIsolationModifier = "nonisolated" | "nonisolated" "(" "unsafe" ")" | … .
    ///
    /// swift-syntax: `DeclModifierListSyntax` of `DeclModifierSyntax(name:detail:)`, where the
    /// parenthesised argument of `private(set)` / `unowned(safe)` / `nonisolated(unsafe)` is a
    /// `DeclModifierDetailSyntax` rather than part of the name.
    private mutating func convertDeclarationModifiers(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> DeclModifierListSyntax {
        var items: [DeclModifierSyntax] = []
        collectDeclarationModifiers(nt, from: from, to: to, into: &items)
        return DeclModifierListSyntax(items)
    }

    private mutating func collectDeclarationModifiers(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [DeclModifierSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let modNT = find("declarationModifier", in: spans) {
            // The modifier's text is the whole `name` or `name(detail)`; every alternate is
            // built from bare keyword terminals, so the source text IS the spelling.
            let text = collectTerminalText(modNT.nt, from: modNT.from, to: modNT.to)
            if let open = text.firstIndex(of: "(") {
                let name = String(text[text.startIndex..<open])
                let detail = String(text[text.index(after: open)...].dropLast())
                items.append(DeclModifierSyntax(
                    name: modifierToken(name),
                    detail: DeclModifierDetailSyntax(detail: .identifier(detail))
                ))
            } else {
                items.append(DeclModifierSyntax(name: modifierToken(text)))
            }
        }
        if let restNT = find("declarationModifiers", in: spans) {
            collectDeclarationModifiers(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    /// A TYPE specifier's token kind. Overlaps `modifierToken` but is NOT the same set — `inout`
    /// is a type specifier and not a declaration modifier, so it is absent there and came out as a
    /// plain identifier. Falls through to the modifier map for the shared words
    /// (`borrowing`, `consuming`, `isolated`, `nonisolated`).
    private func typeSpecifierToken(_ name: String) -> TokenSyntax {
        switch name {
        case "inout":     return .keyword(.inout)
        case "sending":   return .keyword(.sending)
        case "__shared":  return .keyword(.__shared)
        case "__owned":   return .keyword(.__owned)
        case "_const":    return .keyword(._const)
        default:          return modifierToken(name)
        }
    }

    /// A declaration modifier's token kind. swift-syntax spells the lexer-classified ones as
    /// `keyword(...)` and the rest (the underscored SPI modifiers) as plain identifiers, and the
    /// dump distinguishes them — so this cannot just be `.identifier(text)`. Set taken from the
    /// `declarationModifier` / `accessLevelModifier` / `mutationModifier` /
    /// `actorIsolationModifier` alternates in Swift.apus.
    private func modifierToken(_ name: String) -> TokenSyntax {
        switch name {
        case "class":        return .keyword(.class)
        case "convenience":  return .keyword(.convenience)
        case "dynamic":      return .keyword(.dynamic)
        case "final":        return .keyword(.final)
        case "infix":        return .keyword(.infix)
        case "lazy":         return .keyword(.lazy)
        case "optional":     return .keyword(.optional)
        case "override":     return .keyword(.override)
        case "postfix":      return .keyword(.postfix)
        case "prefix":       return .keyword(.prefix)
        case "required":     return .keyword(.required)
        case "static":       return .keyword(.static)
        case "unowned":      return .keyword(.unowned)
        case "weak":         return .keyword(.weak)
        case "async":        return .keyword(.async)
        case "borrowing":    return .keyword(.borrowing)
        case "consuming":    return .keyword(.consuming)
        case "distributed":  return .keyword(.distributed)
        case "indirect":     return .keyword(.indirect)
        case "isolated":     return .keyword(.isolated)
        case "private":      return .keyword(.private)
        case "fileprivate":  return .keyword(.fileprivate)
        case "internal":     return .keyword(.internal)
        case "package":      return .keyword(.package)
        case "public":       return .keyword(.public)
        case "open":         return .keyword(.open)
        case "mutating":     return .keyword(.mutating)
        case "nonmutating":  return .keyword(.nonmutating)
        case "nonisolated":  return .keyword(.nonisolated)
        default:             return .identifier(name)
        }
    }

    /// typealiasDeclaration = attributes? accessLevelModifier? "typealias" typealiasName
    ///                        genericParameterClause? typealiasAssignment .
    /// typealiasAssignment  = assignmentOperator type .
    private mutating func convertTypealiasDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> TypeAliasDeclSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return TypeAliasDeclSyntax(name: .identifier("?"),
                                       initializer: TypeInitializerClauseSyntax(value: MissingTypeSyntax()))
        }
        let modifiers = declHeadModifiers(spans, from: from, to: to)
        var attributes = AttributeListSyntax([])
        if let attrNT = find("attributes", in: spans) {
            attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
        }
        var generics: GenericParameterClauseSyntax? = nil
        if let gpNT = find("genericParameterClause", in: spans) {
            generics = convertGenericParameterClause(gpNT.nt, from: gpNT.from, to: gpNT.to)
        }
        var name = TokenSyntax.identifier("?")
        if let nameNT = find("typealiasName", in: spans) {
            name = .identifier(collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to))
        } else {
            record(.lookupFailed, "no typealiasName child", from: from, to: to)
        }
        var value: TypeSyntax = TypeSyntax(MissingTypeSyntax())
        if let asgNT = find("typealiasAssignment", in: spans),
           let (_, asgSpans) = tileAlternate(asgNT.nt, from: asgNT.from, to: asgNT.to),
           let typeNT = find("type", in: asgSpans) {
            value = convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
        } else {
            record(.lookupFailed, "no typealiasAssignment/type child", from: from, to: to)
        }
        return TypeAliasDeclSyntax(
            attributes: attributes,
            modifiers: modifiers,
            typealiasKeyword: .keyword(.typealias),
            name: name,
            genericParameterClause: generics,
            initializer: TypeInitializerClauseSyntax(equal: .equalToken(), value: value)
        )
    }

    // MARK: - Initializer and operator declarations

    /// initializerDeclaration = initializerHead genericParameterClause? parameterClause "async"?
    ///                          declarationThrowsClause? functionResult? genericWhereClause? initializerBody .
    /// initializerHead        = attributes? declarationModifiers? "init" ( "?" | "!" )? .
    /// initializerBody        = codeBlock .
    private mutating func convertInitializerDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> InitializerDeclSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return InitializerDeclSyntax(signature: emptySignature())
        }
        var modifiers = DeclModifierListSyntax([])
        var optionalMark: TokenSyntax? = nil
        if let headNT = find("initializerHead", in: spans),
           let (_, headSpans) = tileAlternate(headNT.nt, from: headNT.from, to: headNT.to) {
            if find("attributes", in: headSpans) != nil {
                record(.unhandled, "initializer attributes not converted", from: headNT.from, to: headNT.to)
            }
            if let modsNT = find("declarationModifiers", in: headSpans) {
                modifiers = convertDeclarationModifiers(modsNT.nt, from: modsNT.from, to: modsNT.to)
            }
            // `init?` / `init!` — the mark is a token on the InitializerDecl, not part of the name.
            if spansContainKeyword(headSpans, "?") { optionalMark = .postfixQuestionMarkToken() }
            else if spansContainKeyword(headSpans, "!") { optionalMark = .exclamationMarkToken() }
        }
        if find("genericParameterClause", in: spans) != nil {
            record(.unhandled, "genericParameterClause not converted", from: from, to: to)
        }
        if find("genericWhereClause", in: spans) != nil {
            record(.unhandled, "genericWhereClause not converted", from: from, to: to)
        }

        // The signature is spelled inline here rather than via `functionSignature`, so it is
        // assembled from the same parts by hand.
        var parameterClause = FunctionParameterClauseSyntax(parameters: [])
        if let pcNT = find("parameterClause", in: spans) {
            parameterClause = convertParameterClause(pcNT.nt, from: pcNT.from, to: pcNT.to)
        } else {
            record(.lookupFailed, "no parameterClause child", from: from, to: to)
        }
        var effects: FunctionEffectSpecifiersSyntax? = nil
        let isAsync = spansContainKeyword(spans, "async")
        var throwsClause: ThrowsClauseSyntax? = nil
        if let dtcNT = find("declarationThrowsClause", in: spans),
           let (_, dtcSpans) = tileAlternate(dtcNT.nt, from: dtcNT.from, to: dtcNT.to) {
            throwsClause = ThrowsClauseSyntax(
                throwsSpecifier: find("throwsClause", in: dtcSpans) != nil ? .keyword(.throws) : .keyword(.rethrows)
            )
        }
        if isAsync || throwsClause != nil {
            effects = FunctionEffectSpecifiersSyntax(
                asyncSpecifier: isAsync ? .keyword(.async) : nil,
                throwsClause: throwsClause
            )
        }
        var returnClause: ReturnClauseSyntax? = nil
        if let resNT = find("functionResult", in: spans),
           let (_, resSpans) = tileAlternate(resNT.nt, from: resNT.from, to: resNT.to),
           let typeNT = find("type", in: resSpans) {
            returnClause = ReturnClauseSyntax(arrow: .arrowToken(), type: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to))
        }

        var body: CodeBlockSyntax? = nil
        if let bodyNT = find("initializerBody", in: spans),
           let (_, bodySpans) = tileAlternate(bodyNT.nt, from: bodyNT.from, to: bodyNT.to),
           let cbNT = find("codeBlock", in: bodySpans) {
            body = convertCodeBlock(cbNT.nt, from: cbNT.from, to: cbNT.to)
        }

        return InitializerDeclSyntax(
            modifiers: modifiers,
            initKeyword: .keyword(.`init`),
            optionalMark: optionalMark,
            signature: FunctionSignatureSyntax(
                parameterClause: parameterClause,
                effectSpecifiers: effects,
                returnClause: returnClause
            ),
            body: body
        )
    }

    /// operatorDeclaration = ( "prefix" | "postfix" | "infix" ) "operator" declaredOperator infixOperatorGroup? .
    /// infixOperatorGroup  = ":" precedenceGroupName designatedTypes? .
    private mutating func convertOperatorDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> OperatorDeclSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return OperatorDeclSyntax(fixitySpecifier: .keyword(.infix), name: .binaryOperator("?"))
        }
        // The fixity is a bare keyword terminal in a DO group, so match on its text.
        var fixity: TokenSyntax = .keyword(.infix)
        if spansContainKeyword(spans, "prefix") { fixity = .keyword(.prefix) }
        else if spansContainKeyword(spans, "postfix") { fixity = .keyword(.postfix) }

        var name: TokenSyntax = .binaryOperator("?")
        if let dNT = find("declaredOperator", in: spans) {
            name = .binaryOperator(collectTerminalText(dNT.nt, from: dNT.from, to: dNT.to))
        } else {
            record(.lookupFailed, "no declaredOperator child", from: from, to: to)
        }

        var precedenceGroup: OperatorPrecedenceAndTypesSyntax? = nil
        if let gNT = find("infixOperatorGroup", in: spans),
           let (_, gSpans) = tileAlternate(gNT.nt, from: gNT.from, to: gNT.to) {
            if find("designatedTypes", in: gSpans) != nil {
                record(.unhandled, "operator designatedTypes not converted", from: gNT.from, to: gNT.to)
            }
            if let pgNT = find("precedenceGroupName", in: gSpans) {
                precedenceGroup = OperatorPrecedenceAndTypesSyntax(
                    colon: .colonToken(),
                    precedenceGroup: .identifier(collectTerminalText(pgNT.nt, from: pgNT.from, to: pgNT.to)),
                    designatedTypes: DesignatedTypeListSyntax([])
                )
            } else {
                record(.lookupFailed, "infixOperatorGroup without precedenceGroupName", from: gNT.from, to: gNT.to)
            }
        }

        return OperatorDeclSyntax(
            fixitySpecifier: fixity,
            operatorKeyword: .keyword(.operator),
            name: name,
            operatorPrecedenceAndTypes: precedenceGroup
        )
    }

    // MARK: - Enum case declarations

    /// enumCaseDeclaration = attributes? "indirect"? "case" enumCaseElementList .
    /// enumCaseElementList = enumCaseElement | enumCaseElement "," enumCaseElementList .
    /// enumCaseElement     = enumCaseName associatedValues? enumCaseRawValueInitializer? .
    ///
    /// swift-syntax does NOT split union-style from raw-value-style enums: one
    /// `EnumCaseDeclSyntax` whose elements each carry an optional parameter clause AND an
    /// optional `= expression`. The grammar was already merged to match.
    private mutating func convertEnumCaseDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> EnumCaseDeclSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return EnumCaseDeclSyntax(elements: [])
        }
        if find("attributes", in: spans) != nil {
            record(.unhandled, "enum case attributes not converted", from: from, to: to)
        }
        if spansContainKeyword(spans, "indirect") {
            record(.unhandled, "indirect enum case modifier not converted", from: from, to: to)
        }
        var elements: [EnumCaseElementSyntax] = []
        if let listNT = find("enumCaseElementList", in: spans) {
            collectEnumCaseElements(listNT.nt, from: listNT.from, to: listNT.to, into: &elements)
        } else {
            record(.lookupFailed, "no enumCaseElementList child", from: from, to: to)
        }
        if elements.count > 1 {
            for i in 0..<elements.count - 1 {
                elements[i] = elements[i].with(\.trailingComma, .commaToken())
            }
        }
        return EnumCaseDeclSyntax(
            caseKeyword: .keyword(.case),
            elements: EnumCaseElementListSyntax(elements)
        )
    }

    private mutating func collectEnumCaseElements(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [EnumCaseElementSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let elNT = find("enumCaseElement", in: spans),
           let (_, elSpans) = tileAlternate(elNT.nt, from: elNT.from, to: elNT.to) {
            var name = TokenSyntax.identifier("?")
            if let nameNT = find("enumCaseName", in: elSpans) {
                name = .identifier(collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to))
            } else {
                record(.lookupFailed, "no enumCaseName child", from: elNT.from, to: elNT.to)
            }

            var parameterClause: EnumCaseParameterClauseSyntax? = nil
            if let avNT = find("associatedValues", in: elSpans) {
                parameterClause = convertAssociatedValues(avNT.nt, from: avNT.from, to: avNT.to)
            }

            var rawValue: InitializerClauseSyntax? = nil
            if let rvNT = find("enumCaseRawValueInitializer", in: elSpans),
               let (_, rvSpans) = tileAlternate(rvNT.nt, from: rvNT.from, to: rvNT.to),
               let exprNT = find("expression", in: rvSpans) {
                rawValue = InitializerClauseSyntax(
                    equal: .equalToken(),
                    value: convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
                )
            }

            elements.append(EnumCaseElementSyntax(
                name: name,
                parameterClause: parameterClause,
                rawValue: rawValue
            ))
        }
        if let restNT = find("enumCaseElementList", in: spans) {
            collectEnumCaseElements(restNT.nt, from: restNT.from, to: restNT.to, into: &elements)
        }
    }

    /// associatedValues      = "(" enumCaseParameterList ")" .
    /// enumCaseParameterList = enumCaseParameter | enumCaseParameter "," enumCaseParameterList .
    /// enumCaseParameter     = type defaultArgumentClause? .
    /// enumCaseParameter     = parameterModifiers? externalArgumentLabel? localArgumentLabel typeAnnotation defaultArgumentClause? .
    ///
    /// Associated values are `EnumCaseParameterList`, NOT tuple-type elements — swift-syntax
    /// `parseEnumCaseParameter` gives them function-parameter-like optional first/second names.
    private mutating func convertAssociatedValues(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> EnumCaseParameterClauseSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return EnumCaseParameterClauseSyntax(parameters: [])
        }
        var params: [EnumCaseParameterSyntax] = []
        if let listNT = find("enumCaseParameterList", in: spans) {
            collectEnumCaseParameters(listNT.nt, from: listNT.from, to: listNT.to, into: &params)
        }
        if params.count > 1 {
            for i in 0..<params.count - 1 {
                params[i] = params[i].with(\.trailingComma, .commaToken())
            }
        }
        return EnumCaseParameterClauseSyntax(
            leftParen: .leftParenToken(),
            parameters: EnumCaseParameterListSyntax(params),
            rightParen: .rightParenToken()
        )
    }

    private mutating func collectEnumCaseParameters(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into params: inout [EnumCaseParameterSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let pNT = find("enumCaseParameter", in: spans),
           let (_, pSpans) = tileAlternate(pNT.nt, from: pNT.from, to: pNT.to) {
            if find("parameterModifiers", in: pSpans) != nil {
                record(.unhandled, "enum case parameter modifiers not converted", from: pNT.from, to: pNT.to)
            }
            var first: TokenSyntax? = nil
            var second: TokenSyntax? = nil
            var type: TypeSyntax = TypeSyntax(MissingTypeSyntax())

            if let taNT = find("typeAnnotation", in: pSpans) {
                // Labelled form: externalArgumentLabel? localArgumentLabel typeAnnotation
                let ext = find("externalArgumentLabel", in: pSpans)
                let local = find("localArgumentLabel", in: pSpans)
                if let ext, let local {
                    first = .identifier(collectTerminalText(ext.nt, from: ext.from, to: ext.to))
                    second = .identifier(collectTerminalText(local.nt, from: local.from, to: local.to))
                } else if let only = local ?? ext {
                    first = .identifier(collectTerminalText(only.nt, from: only.from, to: only.to))
                }
                if let (_, taSpans) = tileAlternate(taNT.nt, from: taNT.from, to: taNT.to),
                   let typeNT = find("type", in: taSpans) {
                    type = convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
                } else {
                    record(.lookupFailed, "typeAnnotation without type", from: pNT.from, to: pNT.to)
                }
            } else if let typeNT = find("type", in: pSpans) {
                // Bare form: just a type, no labels.
                type = convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
            } else {
                record(.lookupFailed, "enum case parameter without a type", from: pNT.from, to: pNT.to)
            }

            var defaultValue: InitializerClauseSyntax? = nil
            if let defNT = find("defaultArgumentClause", in: pSpans),
               let (_, defSpans) = tileAlternate(defNT.nt, from: defNT.from, to: defNT.to),
               let exprNT = find("expression", in: defSpans) {
                defaultValue = InitializerClauseSyntax(
                    equal: .equalToken(),
                    value: convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
                )
            }

            params.append(EnumCaseParameterSyntax(
                firstName: first,
                secondName: second,
                colon: first == nil ? nil : .colonToken(),
                type: type,
                defaultValue: defaultValue
            ))
        }
        if let restNT = find("enumCaseParameterList", in: spans) {
            collectEnumCaseParameters(restNT.nt, from: restNT.from, to: restNT.to, into: &params)
        }
    }

    // MARK: - Function declarations

    private mutating func convertFunctionDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> FunctionDeclSyntax {
        // functionDeclaration = functionHead functionName genericParameterClause? functionSignature genericWhereClause? functionBody? .
        // functionHead = attributes? declarationModifiers? "func" .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return FunctionDeclSyntax(name: .identifier("?"), signature: emptySignature())
        }

        // `attributes` / `declarationModifiers` inside functionHead have no converter yet;
        // emitting an empty list where swift-syntax has entries WILL mismatch, so say so.
        var attributes = AttributeListSyntax([])
        var modifiers = DeclModifierListSyntax([])
        if let headNT = find("functionHead", in: spans),
           let (_, headSpans) = tileAlternate(headNT.nt, from: headNT.from, to: headNT.to) {
            if let attrNT = find("attributes", in: headSpans) {
                attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
            }
            if let modsNT = find("declarationModifiers", in: headSpans) {
                modifiers = convertDeclarationModifiers(modsNT.nt, from: modsNT.from, to: modsNT.to)
            }
        }
        var genericParameterClause: GenericParameterClauseSyntax? = nil
        if let gpNT = find("genericParameterClause", in: spans) {
            genericParameterClause = convertGenericParameterClause(gpNT.nt, from: gpNT.from, to: gpNT.to)
        }
        if find("genericWhereClause", in: spans) != nil {
            record(.unhandled, "genericWhereClause not converted", from: from, to: to)
        }

        var name = "?"
        if let nameNT = find("functionName", in: spans) {
            name = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
        } else {
            record(.lookupFailed, "no functionName child", from: from, to: to)
        }

        var signature = emptySignature()
        if let sigNT = find("functionSignature", in: spans) {
            signature = convertFunctionSignature(sigNT.nt, from: sigNT.from, to: sigNT.to)
        } else {
            record(.lookupFailed, "no functionSignature child", from: from, to: to)
        }

        var body: CodeBlockSyntax? = nil
        if let bodyNT = find("functionBody", in: spans),
           let (_, bodySpans) = tileAlternate(bodyNT.nt, from: bodyNT.from, to: bodyNT.to),
           let blockNT = find("codeBlock", in: bodySpans) {
            body = convertCodeBlock(blockNT.nt, from: blockNT.from, to: blockNT.to)
        }

        return FunctionDeclSyntax(
            attributes: attributes,
            modifiers: modifiers,
            name: .identifier(name),
            genericParameterClause: genericParameterClause,
            signature: signature,
            body: body
        )
    }

    private func emptySignature() -> FunctionSignatureSyntax {
        FunctionSignatureSyntax(parameterClause: FunctionParameterClauseSyntax(parameters: []))
    }

    private mutating func convertFunctionSignature(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> FunctionSignatureSyntax {
        // functionSignature = parameterClause "async"? throwsClause? functionResult? .
        // functionSignature = parameterClause "async"? "rethrows" functionResult? .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return emptySignature()
        }

        var parameterClause = FunctionParameterClauseSyntax(parameters: [])
        if let pcNT = find("parameterClause", in: spans) {
            parameterClause = convertParameterClause(pcNT.nt, from: pcNT.from, to: pcNT.to)
        } else {
            record(.lookupFailed, "no parameterClause child", from: from, to: to)
        }

        // `async` is a bare terminal in the rule, so match its text rather than a
        // nonterminal. `declarationThrowsClause = throwsClause | "rethrows"` mirrors
        // swift-syntax's single `ThrowsClauseSyntax.throwsSpecifier`, so there is one
        // nonterminal to find here rather than a per-alternate keyword probe.
        var effects: FunctionEffectSpecifiersSyntax? = nil
        let isAsync = spansContainKeyword(spans, "async")
        var throwsClause: ThrowsClauseSyntax? = nil
        if let dtcNT = find("declarationThrowsClause", in: spans),
           let (_, dtcSpans) = tileAlternate(dtcNT.nt, from: dtcNT.from, to: dtcNT.to) {
            if let thNT = find("throwsClause", in: dtcSpans) {
                if let (_, thSpans) = tileAlternate(thNT.nt, from: thNT.from, to: thNT.to),
                   find("type", in: thSpans) != nil {
                    record(.unhandled, "typed throws clause not converted", from: thNT.from, to: thNT.to)
                }
                throwsClause = ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
            } else {
                throwsClause = ThrowsClauseSyntax(throwsSpecifier: .keyword(.rethrows))
            }
        }
        if isAsync || throwsClause != nil {
            effects = FunctionEffectSpecifiersSyntax(
                asyncSpecifier: isAsync ? .keyword(.async) : nil,
                throwsClause: throwsClause
            )
        }

        var returnClause: ReturnClauseSyntax? = nil
        if let resNT = find("functionResult", in: spans),
           let (_, resSpans) = tileAlternate(resNT.nt, from: resNT.from, to: resNT.to),
           let typeNT = find("type", in: resSpans) {
            returnClause = ReturnClauseSyntax(
                arrow: .arrowToken(),
                type: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
            )
        }

        return FunctionSignatureSyntax(
            parameterClause: parameterClause,
            effectSpecifiers: effects,
            returnClause: returnClause
        )
    }

    /// True when one of the alternate's own TERMINAL slots committed `keyword`.
    /// Bare keyword terminals carry no nonterminal name, so `find` cannot see them.
    private mutating func spansContainKeyword(_ spans: [(GrammarNode, CharPosition, CharPosition)], _ keyword: String) -> Bool {
        for (sym, f, t) in spans where f < t {
            if sym.kind.isTerminal || sym.kind == .OPT || sym.kind == .DO {
                var text = ""
                if tiledText(sym, from: f, to: t, into: &text), text == keyword { return true }
            }
        }
        return false
    }

    private mutating func convertParameterClause(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> FunctionParameterClauseSyntax {
        // parameterClause = "(" ")" | "(" parameterList ","? ")" .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return FunctionParameterClauseSyntax(parameters: [])
        }
        var params: [FunctionParameterSyntax] = []
        if let listNT = find("parameterList", in: spans) {
            collectParameters(listNT.nt, from: listNT.from, to: listNT.to, into: &params)
        }
        // Right-recursive list; swift-syntax hangs the comma off the preceding element.
        if params.count > 1 {
            for i in 0..<params.count - 1 {
                params[i] = params[i].with(\.trailingComma, .commaToken())
            }
        }
        return FunctionParameterClauseSyntax(parameters: FunctionParameterListSyntax(params))
    }

    private mutating func collectParameters(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into params: inout [FunctionParameterSyntax]) {
        // parameterList = parameter | parameter "," parameterList .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let pNT = find("parameter", in: spans) {
            params.append(convertParameter(pNT.nt, from: pNT.from, to: pNT.to))
        }
        if let restNT = find("parameterList", in: spans) {
            collectParameters(restNT.nt, from: restNT.from, to: restNT.to, into: &params)
        }
    }

    private mutating func convertParameter(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> FunctionParameterSyntax {
        // parameter = attributes? @shortest [ parameterDeclarationModifiers ] parameterNames typeAnnotation defaultArgumentClause? .
        // parameter = attributes? @shortest [ parameterDeclarationModifiers ] parameterNames typeAnnotation "..." .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return FunctionParameterSyntax(firstName: .wildcardToken(), type: MissingTypeSyntax())
        }
        if find("attributes", in: spans) != nil {
            record(.unhandled, "parameter attributes not converted", from: from, to: to)
        }
        if find("parameterDeclarationModifiers", in: spans) != nil {
            record(.unhandled, "parameter declaration modifiers not converted", from: from, to: to)
        }

        // parameterNames = externalParameterName localParameterName | localParameterName .
        // swift-syntax: one name → firstName only; two names → firstName + secondName.
        var firstName = TokenSyntax.wildcardToken()
        var secondName: TokenSyntax? = nil
        if let namesNT = find("parameterNames", in: spans),
           let (_, nameSpans) = tileAlternate(namesNT.nt, from: namesNT.from, to: namesNT.to) {
            let external = find("externalParameterName", in: nameSpans)
            let local = find("localParameterName", in: nameSpans)
            if let external, let local {
                firstName = parameterNameToken(external)
                secondName = parameterNameToken(local)
            } else if let only = local ?? external {
                firstName = parameterNameToken(only)
            } else {
                record(.lookupFailed, "parameterNames yielded no name", from: from, to: to)
            }
        } else {
            record(.lookupFailed, "no parameterNames child", from: from, to: to)
        }

        var type: TypeSyntax = TypeSyntax(MissingTypeSyntax())
        if let taNT = find("typeAnnotation", in: spans),
           let (_, taSpans) = tileAlternate(taNT.nt, from: taNT.from, to: taNT.to),
           let typeNT = find("type", in: taSpans) {
            type = convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
        } else {
            record(.lookupFailed, "no typeAnnotation/type child", from: from, to: to)
        }

        var defaultValue: InitializerClauseSyntax? = nil
        if let defNT = find("defaultArgumentClause", in: spans),
           let (_, defSpans) = tileAlternate(defNT.nt, from: defNT.from, to: defNT.to),
           let exprNT = find("expression", in: defSpans) {
            defaultValue = InitializerClauseSyntax(
                equal: .equalToken(),
                value: convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
            )
        }

        return FunctionParameterSyntax(
            firstName: firstName,
            secondName: secondName,
            colon: .colonToken(),
            type: type,
            defaultValue: defaultValue
        )
    }

    private mutating func parameterNameToken(_ span: NTSpan) -> TokenSyntax {
        let text = collectTerminalText(span.nt, from: span.from, to: span.to)
        return text == "_" ? .wildcardToken() : .identifier(text)
    }

    private mutating func convertCodeBlock(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> CodeBlockSyntax {
        // codeBlock = "{" statements? "}" .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return CodeBlockSyntax(statements: [])
        }
        var items: [CodeBlockItemSyntax.Item] = []
        if let stmtsNT = find("statements", in: spans) {
            items = convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to)
        }
        return CodeBlockSyntax(
            leftBrace: .leftBraceToken(),
            statements: CodeBlockItemListSyntax(items.map { CodeBlockItemSyntax(item: $0) }),
            rightBrace: .rightBraceToken()
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

    /// Name the alternate that matched, for triage: the first nonterminal in its
    /// body, which for a dispatch rule like `declaration = importDeclaration | …`
    /// IS the kind. Turns one undifferentiated bucket into a ranked work queue.
    private func alternateKind(_ spans: [(GrammarNode, CharPosition, CharPosition)]) -> String {
        for (sym, _, _) in spans {
            if let name = directName(sym) { return name }
        }
        return "<no nonterminal in alternate>"
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
            let name = collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)
            pattern = PatternSyntax(IdentifierPatternSyntax(identifier: .identifier(name)))
        } else if find("wildcardPattern", in: spans) != nil {
            // wildcardPattern = "_" .
            pattern = PatternSyntax(WildcardPatternSyntax(wildcard: .wildcardToken()))
        } else if let tupNT = find("tupleBindingPattern", in: spans) {
            pattern = convertTupleBindingPattern(tupNT.nt, from: tupNT.from, to: tupNT.to)
        } else {
            pattern = missingPattern(.unhandled, "binding pattern kind has no converter: \(alternateKind(spans))", from: from, to: to)
        }
        if let taNT = find("typeAnnotation", in: spans) {
            typeAnnotation = convertTypeAnnotation(taNT.nt, from: taNT.from, to: taNT.to)
        }
        return (pattern, typeAnnotation)
    }

    /// tupleBindingPattern     = "(" tupleBindingElementList? ")" .
    /// tupleBindingElementList = tupleBindingElement | tupleBindingElement "," tupleBindingElementList .
    /// tupleBindingElement     = bindingSubpattern | softIdentifier ":" bindingSubpattern .
    /// bindingSubpattern       = wildcardPattern | identifierPattern | tupleBindingPattern .
    private mutating func convertTupleBindingPattern(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> PatternSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingPattern(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        var elements: [TuplePatternElementSyntax] = []
        if let listNT = find("tupleBindingElementList", in: spans) {
            collectTupleBindingElements(listNT.nt, from: listNT.from, to: listNT.to, into: &elements)
        }
        if elements.count > 1 {
            for i in 0..<elements.count - 1 {
                elements[i] = elements[i].with(\.trailingComma, .commaToken())
            }
        }
        return PatternSyntax(TuplePatternSyntax(
            leftParen: .leftParenToken(),
            elements: TuplePatternElementListSyntax(elements),
            rightParen: .rightParenToken()
        ))
    }

    private mutating func collectTupleBindingElements(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [TuplePatternElementSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let elNT = find("tupleBindingElement", in: spans),
           let (_, elSpans) = tileAlternate(elNT.nt, from: elNT.from, to: elNT.to),
           let subNT = find("bindingSubpattern", in: elSpans) {
            let label = find("softIdentifier", in: elSpans)
            elements.append(TuplePatternElementSyntax(
                label: label.map { .identifier(collectTerminalText($0.nt, from: $0.from, to: $0.to)) },
                colon: label == nil ? nil : .colonToken(),
                pattern: convertBindingSubpattern(subNT.nt, from: subNT.from, to: subNT.to)
            ))
        }
        if let restNT = find("tupleBindingElementList", in: spans) {
            collectTupleBindingElements(restNT.nt, from: restNT.from, to: restNT.to, into: &elements)
        }
    }

    private mutating func convertBindingSubpattern(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> PatternSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingPattern(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        if find("wildcardPattern", in: spans) != nil {
            return PatternSyntax(WildcardPatternSyntax(wildcard: .wildcardToken()))
        }
        if let idNT = find("identifierPattern", in: spans) {
            let name = collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)
            return PatternSyntax(IdentifierPatternSyntax(identifier: .identifier(name)))
        }
        if let tupNT = find("tupleBindingPattern", in: spans) {
            return convertTupleBindingPattern(tupNT.nt, from: tupNT.from, to: tupNT.to)
        }
        return missingPattern(.unhandled, "binding subpattern has no converter: \(alternateKind(spans))", from: from, to: to)
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

        _ = spans
        var elements: [ExprSyntax] = []
        flattenExpression(nt, from: from, to: to, into: &elements)
        if elements.isEmpty {
            return ExprSyntax(MissingExprSyntax())
        }
        // swift-syntax only wraps in SequenceExpr when there is more than one element.
        return elements.count == 1
            ? elements[0]
            : ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(elements)))
    }

    /// Append `expression`'s elements to a FLAT sequence rather than wrapping them.
    ///
    /// This is what makes the nested-vs-flat mismatch go away. Advent nests: the
    /// `assignmentOperator expression` and `conditionalOperator expression` alternates
    /// of `infixExpression` take a whole `expression` on the right, so `a = b + c` puts
    /// `b + c` under the `=`. swift-syntax's `SequenceExpr` is ONE flat list
    /// (`[a, AssignmentExpr, b, BinaryOperator, c]`), so the nested expression's
    /// elements must be SPLICED into the parent, not converted as a sub-expression.
    private mutating func flattenExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [ExprSyntax]) {
        // expression = tryOperator? awaitOperator? conditionalExpression coercingOperator? .
        // expression = tryOperator? awaitOperator? prefixExpression infixExpressions? .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        // expression = tryOperator? awaitOperator? conditionalExpression coercingOperator? .
        // conditionalExpression = ifExpression | switchExpression .
        if let condNT = find("conditionalExpression", in: spans) {
            if find("coercingOperator", in: spans) != nil {
                record(.unhandled, "coercingOperator on an if/switch expression not converted", from: from, to: to)
            }
            elements.append(convertConditionalExpression(condNT.nt, from: condNT.from, to: condNT.to))
            return
        }
        guard let prefNT = find("prefixExpression", in: spans) else {
            elements.append(missingExpr(.unhandled, "expression without prefixExpression child", from: from, to: to))
            return
        }
        // `try` / `await` wrap ONLY the first operand, and the wrapped node is then one
        // element of the flat sequence. Probe-verified against swift-syntax:
        // `try f() + 1` → SequenceExpr[TryExpr(f()), BinaryOperator(+), 1] — NOT
        // TryExpr(SequenceExpr(…)), even though that is what the expression MEANS. The
        // unfolded tree defers that; `OperatorTable.foldAll()` reassociates later.
        // tryOperator = "try" | "try" >s< "?" | "try" >s< "!" .   awaitOperator = "await" .
        var operand = convertPrefixExpression(prefNT.nt, from: prefNT.from, to: prefNT.to)
        // Innermost first: `try await x` is TryExpr(AwaitExpr(x)).
        if find("awaitOperator", in: spans) != nil {
            operand = ExprSyntax(AwaitExprSyntax(awaitKeyword: .keyword(.await), expression: operand))
        }
        if let tryNT = find("tryOperator", in: spans) {
            let text = collectTerminalText(tryNT.nt, from: tryNT.from, to: tryNT.to)
            var mark: TokenSyntax? = nil
            if text.hasSuffix("?") { mark = .postfixQuestionMarkToken() }
            else if text.hasSuffix("!") { mark = .exclamationMarkToken() }
            operand = ExprSyntax(TryExprSyntax(
                tryKeyword: .keyword(.try),
                questionOrExclamationMark: mark,
                expression: operand
            ))
        }
        elements.append(operand)
        // `conditionExpression` is a PARALLEL copy of `expression` that swaps in its own
        // infix family (`conditionInfixExpressions`, which omits the assignment alternate —
        // assignment returns Void and is not a condition). Looking only for `infixExpressions`
        // silently dropped the tail, so `if let x = y, x > 0` lost its `> 0`.
        if let infSpan = find(firstOf: ["infixExpressions", "conditionInfixExpressions"], in: spans) {
            flattenInfixExpressions(infSpan.nt, from: infSpan.from, to: infSpan.to, into: &elements)
        }
    }

    private mutating func flattenInfixExpressions(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [ExprSyntax]) {
        // infixExpressions          = infixExpression infixExpressions? .
        // conditionInfixExpressions = conditionInfixExpression conditionInfixExpressions? .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        for (sym, f, t) in spans {
            for name in ["infixExpression", "conditionInfixExpression"] {
                if let ieNT = findNonterminal(named: name, sym: sym, from: f, to: t) {
                    flattenInfixExpression(ieNT.nt, from: ieNT.from, to: ieNT.to, into: &elements)
                }
            }
            for name in ["infixExpressions", "conditionInfixExpressions"] {
                if let nextNT = findNonterminal(named: name, sym: sym, from: f, to: t) {
                    flattenInfixExpressions(nextNT.nt, from: nextNT.from, to: nextNT.to, into: &elements)
                }
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

        // The operator element, one per alternate.
        if let opNT = find("infixOperator", in: spans) {
            let opText = collectTerminalText(opNT.nt, from: opNT.from, to: opNT.to)
            elements.append(ExprSyntax(BinaryOperatorExprSyntax(operator: .binaryOperator(opText))))
        } else if find("assignmentOperator", in: spans) != nil {
            elements.append(ExprSyntax(AssignmentExprSyntax(equal: .equalToken())))
        } else if let condNT = find("conditionalOperator", in: spans) {
            // UnresolvedTernaryExpr carries `? then :` and sits as ONE element between
            // the condition and the false-branch — which lines up with Advent's
            // `conditionalOperator = <s> "?" expression ":"` holding the then-branch.
            elements.append(convertConditionalOperator(condNT.nt, from: condNT.from, to: condNT.to))
        } else if let castNT = find("typeCastingOperator", in: spans) {
            convertTypeCastingOperator(castNT.nt, from: castNT.from, to: castNT.to, into: &elements)
        } else if let arrowNT = find("arrowExpr", in: spans) {
            // arrowExpr = typeEffectSpecifiers? "->" >->( … ) .
            // swift-syntax: ArrowExpr, one element of the flat sequence, carrying the
            // effect specifiers that precede the arrow.
            var effects: TypeEffectSpecifiersSyntax? = nil
            if let (_, aSpans) = tileAlternate(arrowNT.nt, from: arrowNT.from, to: arrowNT.to),
               let teNT = find("typeEffectSpecifiers", in: aSpans),
               let (_, teSpans) = tileAlternate(teNT.nt, from: teNT.from, to: teNT.to) {
                let isAsync = spansContainKeyword(teSpans, "async")
                let throwsClause = find("throwsClause", in: teSpans) != nil
                    ? ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws)) : nil
                effects = TypeEffectSpecifiersSyntax(
                    asyncSpecifier: isAsync ? .keyword(.async) : nil,
                    throwsClause: throwsClause
                )
            }
            elements.append(ExprSyntax(ArrowExprSyntax(effectSpecifiers: effects, arrow: .arrowToken())))
        }

        // The right-hand operand. `assignmentOperator expression` and
        // `conditionalOperator expression` take a whole expression — SPLICE its
        // elements in rather than nesting a SequenceExpr inside this one.
        if let exprNT = find("expression", in: spans) {
            flattenExpression(exprNT.nt, from: exprNT.from, to: exprNT.to, into: &elements)
        } else if let prefNT = find("prefixExpression", in: spans) {
            elements.append(convertPrefixExpression(prefNT.nt, from: prefNT.from, to: prefNT.to))
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
            // `as?` / `as!` keep the mark on the UnresolvedAsExpr itself.
            var mark: TokenSyntax? = nil
            if spansContainKeyword(spans, "?") { mark = .postfixQuestionMarkToken() }
            else if spansContainKeyword(spans, "!") { mark = .exclamationMarkToken() }
            elements.append(ExprSyntax(UnresolvedAsExprSyntax(
                asKeyword: .keyword(.as),
                questionOrExclamationMark: mark
            )))
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
                let text = collectTerminalText(sym, from: f, to: t)
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
        // `nonLiteralPrimary` is `primaryExpression` minus the bare-literal alternates (it exists
        // so a trailing-closure-only call cannot have a literal callee). Its alternates carry the
        // same child names, and the converter dispatches by name, so one function serves both.
        if let primNT = find(firstOf: ["primaryExpression", "nonLiteralPrimary"], in: spans) {
            return convertPrimaryExpression(primNT.nt, from: primNT.from, to: primNT.to)
        }
        // The postfix rules are LEFT-recursive on `postfixExpression`, which maps
        // straight onto swift-syntax's nested base/expression fields — no flattening
        // needed here (unlike the infix side).
        if let d = find("explicitMemberExpression", in: spans) {
            return convertExplicitMemberExpression(d.nt, from: d.from, to: d.to)
        }
        if let d = find("functionCallExpression", in: spans) {
            return convertFunctionCallExpression(d.nt, from: d.from, to: d.to)
        }
        if let d = find("subscriptExpression", in: spans) {
            return convertSubscriptExpression(d.nt, from: d.from, to: d.to)
        }
        if let d = find("forcedValueExpression", in: spans) {
            // forcedValueExpression = postfixExpression >s< forceMark .
            guard let base = postfixBase(d) else {
                return missingExpr(.lookupFailed, "no postfixExpression base", from: d.from, to: d.to)
            }
            return ExprSyntax(ForceUnwrapExprSyntax(expression: base, exclamationMark: .exclamationMarkToken()))
        }
        if let d = find("optionalChainingExpression", in: spans) {
            // optionalChainingExpression = postfixExpression >s< optionalMark .
            guard let base = postfixBase(d) else {
                return missingExpr(.lookupFailed, "no postfixExpression base", from: d.from, to: d.to)
            }
            return ExprSyntax(OptionalChainingExprSyntax(expression: base, questionMark: .postfixQuestionMarkToken()))
        }
        return missingExpr(.unhandled, "postfix form has no converter: \(alternateKind(spans))", from: from, to: to)
    }

    /// labeledTrailingClosures = labeledTrailingClosure labeledTrailingClosures? .
    /// labeledTrailingClosure  = trailingClosureLabel ":" closureExpression .
    private mutating func collectLabeledTrailingClosures(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [MultipleTrailingClosureElementSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let ltcNT = find("labeledTrailingClosure", in: spans),
           let (_, lSpans) = tileAlternate(ltcNT.nt, from: ltcNT.from, to: ltcNT.to),
           let labelNT = find("trailingClosureLabel", in: lSpans),
           let closNT = find("closureExpression", in: lSpans) {
            let label = collectTerminalText(labelNT.nt, from: labelNT.from, to: labelNT.to)
            items.append(MultipleTrailingClosureElementSyntax(
                label: label == "_" ? .wildcardToken() : .identifier(label),
                colon: .colonToken(),
                closure: convertClosureExpression(closNT.nt, from: closNT.from, to: closNT.to)
            ))
        }
        if let restNT = find("labeledTrailingClosures", in: spans) {
            collectLabeledTrailingClosures(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    // MARK: - Closures

    /// closureExpression = "{" >n< closureSignature? statements? "}" .
    /// closureExpression = @excludedFrom(…) newlineOpenedClosure .
    private mutating func convertClosureExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ClosureExprSyntax {
        guard let (_, outer) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return ClosureExprSyntax(statements: [])
        }
        // The `newlineOpenedClosure` alternate is the same shape one level down — it exists only
        // to carry the `@excludedFrom` partition, so unwrap it and convert the inner closure.
        var spans = outer
        if let inner = find("newlineOpenedClosure", in: outer) {
            guard let (_, innerSpans) = tileAlternate(inner.nt, from: inner.from, to: inner.to) else {
                record(.lookupFailed, "no alternate tiles newlineOpenedClosure", from: inner.from, to: inner.to)
                return ClosureExprSyntax(statements: [])
            }
            spans = innerSpans
        }

        var signature: ClosureSignatureSyntax? = nil
        if let sigNT = find("closureSignature", in: spans) {
            signature = convertClosureSignature(sigNT.nt, from: sigNT.from, to: sigNT.to)
        }
        var items: [CodeBlockItemSyntax.Item] = []
        if let stmtsNT = find("statements", in: spans) {
            items = convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to)
        }
        return ClosureExprSyntax(
            leftBrace: .leftBraceToken(),
            signature: signature,
            statements: CodeBlockItemListSyntax(items.map { CodeBlockItemSyntax(item: $0) }),
            rightBrace: .rightBraceToken()
        )
    }

    /// closureSignature = attributes? captureList? closureParameterClause "async"? throwsClause? functionResult? "in" .
    /// closureSignature = attributes? captureList "in" .
    /// closureSignature = attributes "in" .
    private mutating func convertClosureSignature(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ClosureSignatureSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return ClosureSignatureSyntax(inKeyword: .keyword(.in))
        }
        if find("attributes", in: spans) != nil {
            record(.unhandled, "closure attributes not converted", from: from, to: to)
        }

        var capture: ClosureCaptureClauseSyntax? = nil
        if let capNT = find("captureList", in: spans) {
            capture = convertCaptureList(capNT.nt, from: capNT.from, to: capNT.to)
        }

        var parameterClause: ClosureSignatureSyntax.ParameterClause? = nil
        if let pcNT = find("closureParameterClause", in: spans) {
            parameterClause = convertClosureParameterClause(pcNT.nt, from: pcNT.from, to: pcNT.to)
        }

        var effects: TypeEffectSpecifiersSyntax? = nil
        let isAsync = spansContainKeyword(spans, "async")
        var throwsClause: ThrowsClauseSyntax? = nil
        if find("throwsClause", in: spans) != nil {
            throwsClause = ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
        }
        if isAsync || throwsClause != nil {
            effects = TypeEffectSpecifiersSyntax(
                asyncSpecifier: isAsync ? .keyword(.async) : nil,
                throwsClause: throwsClause
            )
        }

        var returnClause: ReturnClauseSyntax? = nil
        if let resNT = find("functionResult", in: spans),
           let (_, resSpans) = tileAlternate(resNT.nt, from: resNT.from, to: resNT.to),
           let typeNT = find("type", in: resSpans) {
            returnClause = ReturnClauseSyntax(arrow: .arrowToken(), type: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to))
        }

        return ClosureSignatureSyntax(
            capture: capture,
            parameterClause: parameterClause,
            effectSpecifiers: effects,
            returnClause: returnClause,
            inKeyword: .keyword(.in)
        )
    }

    /// closureParameterClause = "(" ")" | "(" closureParameterList ","? ")" | identifierList .
    ///
    /// swift-syntax has TWO shapes here: the shorthand `{ x, y in }` is a
    /// `ClosureShorthandParameterList`, while the parenthesised form is a
    /// `ClosureParameterClause` with typed parameters.
    private mutating func convertClosureParameterClause(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ClosureSignatureSyntax.ParameterClause? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        if let idsNT = find("closureShorthandNameList", in: spans) {
            var names: [ClosureShorthandParameterSyntax] = []
            collectShorthandClosureParameters(idsNT.nt, from: idsNT.from, to: idsNT.to, into: &names)
            if names.count > 1 {
                for i in 0..<names.count - 1 {
                    names[i] = names[i].with(\.trailingComma, .commaToken())
                }
            }
            return .simpleInput(ClosureShorthandParameterListSyntax(names))
        }
        var params: [ClosureParameterSyntax] = []
        if let listNT = find("closureParameterList", in: spans) {
            collectClosureParameters(listNT.nt, from: listNT.from, to: listNT.to, into: &params)
        }
        if params.count > 1 {
            for i in 0..<params.count - 1 {
                params[i] = params[i].with(\.trailingComma, .commaToken())
            }
        }
        return .parameterClause(ClosureParameterClauseSyntax(
            leftParen: .leftParenToken(),
            parameters: ClosureParameterListSyntax(params),
            rightParen: .rightParenToken()
        ))
    }

    private mutating func collectShorthandClosureParameters(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into names: inout [ClosureShorthandParameterSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        for (sym, f, t) in spans where f < t {
            if let idNT = findNonterminal(named: "closureShorthandNameList", sym: sym, from: f, to: t) {
                collectShorthandClosureParameters(idNT.nt, from: idNT.from, to: idNT.to, into: &names)
            } else if sym.kind.isTerminal || sym.kind == .N {
                var text = ""
                if tiledText(sym, from: f, to: t, into: &text), text != "," , !text.isEmpty {
                    names.append(ClosureShorthandParameterSyntax(
                        name: text == "_" ? .wildcardToken() : .identifier(text)
                    ))
                }
            }
        }
    }

    /// closureParameter      = attributes? [ parameterDeclarationModifiers ] closureParameterNames typeAnnotation? .
    /// closureParameterNames = externalParameterName closureParameterName | closureParameterName .
    private mutating func collectClosureParameters(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into params: inout [ClosureParameterSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let pNT = find("closureParameter", in: spans),
           let (_, pSpans) = tileAlternate(pNT.nt, from: pNT.from, to: pNT.to) {
            if find("attributes", in: pSpans) != nil {
                record(.unhandled, "closure parameter attributes not converted", from: pNT.from, to: pNT.to)
            }
            var first = TokenSyntax.wildcardToken()
            var second: TokenSyntax? = nil
            if let namesNT = find("closureParameterNames", in: pSpans),
               let (_, nameSpans) = tileAlternate(namesNT.nt, from: namesNT.from, to: namesNT.to) {
                let ext = find("externalParameterName", in: nameSpans)
                let local = find("closureParameterName", in: nameSpans)
                if let ext, let local {
                    first = closureNameToken(ext)
                    second = closureNameToken(local)
                } else if let only = local ?? ext {
                    first = closureNameToken(only)
                }
            } else {
                record(.lookupFailed, "no closureParameterNames child", from: pNT.from, to: pNT.to)
            }
            var type: TypeSyntax? = nil
            if let taNT = find("typeAnnotation", in: pSpans),
               let (_, taSpans) = tileAlternate(taNT.nt, from: taNT.from, to: taNT.to),
               let typeNT = find("type", in: taSpans) {
                type = convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
            }
            params.append(ClosureParameterSyntax(
                firstName: first,
                secondName: second,
                colon: type == nil ? nil : .colonToken(),
                type: type
            ))
        }
        if let restNT = find("closureParameterList", in: spans) {
            collectClosureParameters(restNT.nt, from: restNT.from, to: restNT.to, into: &params)
        }
    }

    private mutating func closureNameToken(_ span: NTSpan) -> TokenSyntax {
        let text = collectTerminalText(span.nt, from: span.from, to: span.to)
        return text == "_" ? .wildcardToken() : .identifier(text)
    }

    /// captureList     = "[" "]" | "[" captureListItems ","? "]" .
    /// captureListItem = captureSpecifier? hardIdentifier [ assignmentOperator expression ]
    ///                 | captureSpecifier? selfExpression .
    private mutating func convertCaptureList(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ClosureCaptureClauseSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return ClosureCaptureClauseSyntax(items: [])
        }
        var items: [ClosureCaptureSyntax] = []
        if let listNT = find("captureListItems", in: spans) {
            collectCaptureItems(listNT.nt, from: listNT.from, to: listNT.to, into: &items)
        }
        if items.count > 1 {
            for i in 0..<items.count - 1 {
                items[i] = items[i].with(\.trailingComma, .commaToken())
            }
        }
        return ClosureCaptureClauseSyntax(
            leftSquare: .leftSquareToken(),
            items: ClosureCaptureListSyntax(items),
            rightSquare: .rightSquareToken()
        )
    }

    private mutating func collectCaptureItems(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [ClosureCaptureSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let itemNT = find("captureListItem", in: spans),
           let (_, iSpans) = tileAlternate(itemNT.nt, from: itemNT.from, to: itemNT.to) {
            var specifier: ClosureCaptureSpecifierSyntax? = nil
            if let specNT = find("captureSpecifier", in: iSpans) {
                let text = collectTerminalText(specNT.nt, from: specNT.from, to: specNT.to)
                if let open = text.firstIndex(of: "(") {
                    specifier = ClosureCaptureSpecifierSyntax(
                        specifier: modifierToken(String(text[text.startIndex..<open])),
                        detail: .identifier(String(text[text.index(after: open)...].dropLast()))
                    )
                } else {
                    specifier = ClosureCaptureSpecifierSyntax(specifier: modifierToken(text))
                }
            }
            // swift-syntax carries a capture as a NAME TOKEN (`ClosureCapture.name`), not as a
            // wrapped DeclReferenceExpr — the `expression:` initializer is the legacy shape and
            // produces a visibly different tree.
            if find("selfExpression", in: iSpans) != nil {
                items.append(ClosureCaptureSyntax(specifier: specifier, name: .keyword(.self)))
            } else if let idNT = find("hardIdentifier", in: iSpans) {
                let name = collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)
                if let exprNT = find("expression", in: iSpans) {
                    // `[x = y]` — swift-syntax keeps the name plus an initializer clause.
                    items.append(ClosureCaptureSyntax(
                        specifier: specifier,
                        name: .identifier(name),
                        initializer: InitializerClauseSyntax(
                            equal: .equalToken(),
                            value: convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
                        )
                    ))
                } else {
                    items.append(ClosureCaptureSyntax(specifier: specifier, name: .identifier(name)))
                }
            } else {
                record(.lookupFailed, "capture item with neither self nor identifier", from: itemNT.from, to: itemNT.to)
            }
        }
        if let restNT = find("captureListItems", in: spans) {
            collectCaptureItems(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    // MARK: - Collection literals, tuples, implicit members

    private mutating func convertArrayLiteral(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // arrayLiteral = "[" arrayLiteralItems? ","? "]" .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        var elements: [ArrayElementSyntax] = []
        if let itemsNT = find("arrayLiteralItems", in: spans) {
            collectArrayItems(itemsNT.nt, from: itemsNT.from, to: itemsNT.to, into: &elements)
        }
        if elements.count > 1 {
            for i in 0..<elements.count - 1 {
                elements[i] = elements[i].with(\.trailingComma, .commaToken())
            }
        }
        return ExprSyntax(ArrayExprSyntax(
            leftSquare: .leftSquareToken(),
            elements: ArrayElementListSyntax(elements),
            rightSquare: .rightSquareToken()
        ))
    }

    private mutating func collectArrayItems(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [ArrayElementSyntax]) {
        // arrayLiteralItems = arrayLiteralItem | arrayLiteralItem "," arrayLiteralItems .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let itemNT = find("arrayLiteralItem", in: spans),
           let (_, itemSpans) = tileAlternate(itemNT.nt, from: itemNT.from, to: itemNT.to) {
            // arrayLiteralItem = @prefer expression . | typeExpression .
            if let exprNT = find("expression", in: itemSpans) {
                elements.append(ArrayElementSyntax(expression: convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)))
            } else {
                record(.unhandled, "typeExpression array element not converted", from: itemNT.from, to: itemNT.to)
            }
        }
        if let restNT = find("arrayLiteralItems", in: spans) {
            collectArrayItems(restNT.nt, from: restNT.from, to: restNT.to, into: &elements)
        }
    }

    private mutating func convertDictionaryLiteral(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // dictionaryLiteral = "[" dictionaryLiteralItems ","? "]" | "[" ":" "]" .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        guard let itemsNT = find("dictionaryLiteralItems", in: spans) else {
            // The empty `[:]` form: swift-syntax puts a lone colon in `content`.
            return ExprSyntax(DictionaryExprSyntax(
                leftSquare: .leftSquareToken(),
                content: .colon(.colonToken()),
                rightSquare: .rightSquareToken()
            ))
        }
        var elements: [DictionaryElementSyntax] = []
        collectDictionaryItems(itemsNT.nt, from: itemsNT.from, to: itemsNT.to, into: &elements)
        if elements.count > 1 {
            for i in 0..<elements.count - 1 {
                elements[i] = elements[i].with(\.trailingComma, .commaToken())
            }
        }
        return ExprSyntax(DictionaryExprSyntax(
            leftSquare: .leftSquareToken(),
            content: .elements(DictionaryElementListSyntax(elements)),
            rightSquare: .rightSquareToken()
        ))
    }

    private mutating func collectDictionaryItems(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [DictionaryElementSyntax]) {
        // dictionaryLiteralItems = dictionaryLiteralItem | dictionaryLiteralItem "," dictionaryLiteralItems .
        // dictionaryLiteralItem  = dictionaryLiteralElement ":" dictionaryLiteralElement .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let itemNT = find("dictionaryLiteralItem", in: spans),
           let (_, itemSpans) = tileAlternate(itemNT.nt, from: itemNT.from, to: itemNT.to) {
            var values: [ExprSyntax] = []
            for (sym, f, t) in itemSpans {
                if let elNT = findNonterminal(named: "dictionaryLiteralElement", sym: sym, from: f, to: t),
                   let (_, elSpans) = tileAlternate(elNT.nt, from: elNT.from, to: elNT.to),
                   let exprNT = find("expression", in: elSpans) {
                    values.append(convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to))
                }
            }
            if values.count == 2 {
                elements.append(DictionaryElementSyntax(key: values[0], colon: .colonToken(), value: values[1]))
            } else {
                record(.unhandled, "dictionary item did not yield a key/value pair", from: itemNT.from, to: itemNT.to)
            }
        }
        if let restNT = find("dictionaryLiteralItems", in: spans) {
            collectDictionaryItems(restNT.nt, from: restNT.from, to: restNT.to, into: &elements)
        }
    }

    private mutating func convertTupleExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // tupleExpression = "(" ")" | "(" tupleElement "," tupleElementList ","? ")" .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        var elements: [LabeledExprSyntax] = []
        if let firstNT = find("tupleElement", in: spans) {
            appendTupleElement(firstNT, into: &elements)
        }
        if let listNT = find("tupleElementList", in: spans) {
            collectTupleElements(listNT.nt, from: listNT.from, to: listNT.to, into: &elements)
        }
        if elements.count > 1 {
            for i in 0..<elements.count - 1 {
                elements[i] = elements[i].with(\.trailingComma, .commaToken())
            }
        }
        return ExprSyntax(TupleExprSyntax(
            leftParen: .leftParenToken(),
            elements: LabeledExprListSyntax(elements),
            rightParen: .rightParenToken()
        ))
    }

    private mutating func collectTupleElements(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [LabeledExprSyntax]) {
        // tupleElementList = tupleElement | tupleElement "," tupleElementList .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let elNT = find("tupleElement", in: spans) {
            appendTupleElement(elNT, into: &elements)
        }
        if let restNT = find("tupleElementList", in: spans) {
            collectTupleElements(restNT.nt, from: restNT.from, to: restNT.to, into: &elements)
        }
    }

    private mutating func appendTupleElement(_ span: NTSpan, into elements: inout [LabeledExprSyntax]) {
        // tupleElement = expression | softIdentifier ":" expression .
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to),
              let exprNT = find("expression", in: spans) else {
            record(.lookupFailed, "tuple element without expression", from: span.from, to: span.to)
            return
        }
        let expr = convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
        if let labelNT = find("softIdentifier", in: spans) {
            elements.append(LabeledExprSyntax(
                label: .identifier(collectTerminalText(labelNT.nt, from: labelNT.from, to: labelNT.to)),
                colon: .colonToken(),
                expression: expr
            ))
        } else {
            elements.append(LabeledExprSyntax(expression: expr))
        }
    }

    private mutating func convertImplicitMemberExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // implicitMemberExpression = "." moduleSelector? softIdentifier .
        // implicitMemberExpression = "." moduleSelector? softIdentifier "." postfixExpression .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        if find("moduleSelector", in: spans) != nil {
            record(.unhandled, "moduleSelector implicit member not converted", from: from, to: to)
        }
        if find("postfixExpression", in: spans) != nil {
            return missingExpr(.unhandled, "chained implicit member (.a.b) not converted", from: from, to: to)
        }
        guard let nameNT = find("softIdentifier", in: spans) else {
            return missingExpr(.lookupFailed, "no softIdentifier child", from: from, to: to)
        }
        let name = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
        return ExprSyntax(MemberAccessExprSyntax(
            period: .periodToken(),
            declName: DeclReferenceExprSyntax(baseName: .identifier(name))
        ))
    }

    // MARK: - Postfix expressions

    /// The `postfixExpression` base of a left-recursive postfix rule, already converted.
    private mutating func postfixBase(_ span: NTSpan) -> ExprSyntax? {
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to),
              let baseNT = find("postfixExpression", in: spans) else { return nil }
        return convertPostfixExpression(baseNT.nt, from: baseNT.from, to: baseNT.to)
    }

    private mutating func convertExplicitMemberExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // explicitMemberExpression = postfixExpression "." decimalDigits .
        // explicitMemberExpression = postfixExpression "." moduleSelector? softIdentifier .
        // explicitMemberExpression = @prefer postfixExpression "." moduleSelector? softIdentifier genericArgumentClause .
        // explicitMemberExpression = postfixExpression "." moduleSelector? softIdentifier "(" argumentNames ")" .
        // explicitMemberExpression = postfixExpression postfixConditionalCompilationBlock .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        guard let baseNT = find("postfixExpression", in: spans) else {
            return missingExpr(.lookupFailed, "no postfixExpression base", from: from, to: to)
        }
        let base = convertPostfixExpression(baseNT.nt, from: baseNT.from, to: baseNT.to)

        if find("moduleSelector", in: spans) != nil {
            record(.unhandled, "moduleSelector member access not converted", from: from, to: to)
        }
        if find("genericArgumentClause", in: spans) != nil {
            record(.unhandled, "member access with generic arguments not converted", from: from, to: to)
        }
        if find("argumentNames", in: spans) != nil {
            record(.unhandled, "member access with argument names not converted", from: from, to: to)
        }
        if find("postfixConditionalCompilationBlock", in: spans) != nil {
            return missingExpr(.unhandled, "postfix #if member access not converted", from: from, to: to)
        }

        // `softIdentifier` is a nonterminal; `decimalDigits` is a named TERMINAL
        // (single-regex productions must be `-`, see Swift.apus), so each needs its
        // own lookup — `find` cannot see terminals.
        var nameSpan = find("softIdentifier", in: spans)
        if nameSpan == nil { nameSpan = findTerminal(named: "decimalDigits", in: spans) }
        guard let nameSpan else {
            return missingExpr(.lookupFailed, "no member name child: \(alternateKind(spans))", from: from, to: to)
        }
        let name = collectTerminalText(nameSpan.nt, from: nameSpan.from, to: nameSpan.to)
        if name.isEmpty {
            record(.lookupFailed, "member name resolved to empty text", from: nameSpan.from, to: nameSpan.to)
        }
        return ExprSyntax(MemberAccessExprSyntax(
            base: base,
            period: .periodToken(),
            declName: DeclReferenceExprSyntax(baseName: declNameToken(name))
        ))
    }

    /// The token inside a `DeclReferenceExpr` used as a member name. The spelling alone
    /// does not fix the token KIND, and swift-syntax is specific about it:
    ///   `x.0`    → integerLiteral (tuple-element access, not an identifier)
    ///   `T.self` → keyword(self)  (likewise `.Self`)
    /// Getting this wrong produces a tree that reads identically in a dump but differs.
    private func declNameToken(_ name: String) -> TokenSyntax {
        if !name.isEmpty && name.allSatisfy(\.isNumber) { return .integerLiteral(name) }
        switch name {
        case "self": return .keyword(.self)
        case "Self": return .keyword(.Self)
        default:     return .identifier(name)
        }
    }

    private mutating func convertFunctionCallExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // functionCallExpression = postfixExpression >n< functionCallArgumentClause .
        // functionCallExpression = @prefer postfixExpression functionCallArgumentClause trailingClosures
        //                        | nonLiteralPostfix trailingClosures .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        guard let baseNT = find(firstOf: ["postfixExpression", "nonLiteralPostfix"], in: spans) else {
            return missingExpr(.lookupFailed, "no callee child", from: from, to: to)
        }
        let callee = convertPostfixExpression(baseNT.nt, from: baseNT.from, to: baseNT.to)

        // trailingClosures = closureExpression labeledTrailingClosures? .
        // swift-syntax puts the FIRST trailing closure in `trailingClosure` and any further
        // labelled ones in `additionalTrailingClosures`. The `f {…}` form has no parens at all,
        // so leftParen/rightParen must be nil rather than empty tokens.
        var trailing: ClosureExprSyntax? = nil
        var additional = MultipleTrailingClosureElementListSyntax([])
        if let tcNT = find("trailingClosures", in: spans),
           let (_, tcSpans) = tileAlternate(tcNT.nt, from: tcNT.from, to: tcNT.to) {
            if let closNT = find("closureExpression", in: tcSpans) {
                trailing = convertClosureExpression(closNT.nt, from: closNT.from, to: closNT.to)
            } else {
                record(.lookupFailed, "trailingClosures without a closureExpression", from: tcNT.from, to: tcNT.to)
            }
            if let labelledNT = find("labeledTrailingClosures", in: tcSpans) {
                var extra: [MultipleTrailingClosureElementSyntax] = []
                collectLabeledTrailingClosures(labelledNT.nt, from: labelledNT.from, to: labelledNT.to, into: &extra)
                additional = MultipleTrailingClosureElementListSyntax(extra)
            }
        }

        // functionCallArgumentClause = "(" ")" | "(" functionCallArgumentList ","? ")" .
        var args = LabeledExprListSyntax([])
        var hasParens = false
        if let clauseNT = find("functionCallArgumentClause", in: spans),
           let (_, clauseSpans) = tileAlternate(clauseNT.nt, from: clauseNT.from, to: clauseNT.to) {
            hasParens = true
            if let listNT = find("functionCallArgumentList", in: clauseSpans) {
                args = convertArgumentList(listNT.nt, from: listNT.from, to: listNT.to)
            }
        } else if trailing == nil {
            return missingExpr(.lookupFailed, "call with neither argument clause nor trailing closure", from: from, to: to)
        }

        return ExprSyntax(FunctionCallExprSyntax(
            calledExpression: callee,
            leftParen: hasParens ? .leftParenToken() : nil,
            arguments: args,
            rightParen: hasParens ? .rightParenToken() : nil,
            trailingClosure: trailing,
            additionalTrailingClosures: additional
        ))
    }

    private mutating func convertSubscriptExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // subscriptExpression = postfixExpression >n< "[" functionCallArgumentList? "]" .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        guard let baseNT = find("postfixExpression", in: spans) else {
            return missingExpr(.lookupFailed, "no postfixExpression base", from: from, to: to)
        }
        let base = convertPostfixExpression(baseNT.nt, from: baseNT.from, to: baseNT.to)
        var args = LabeledExprListSyntax([])
        if let listNT = find("functionCallArgumentList", in: spans) {
            args = convertArgumentList(listNT.nt, from: listNT.from, to: listNT.to)
        }
        return ExprSyntax(SubscriptCallExprSyntax(
            calledExpression: base,
            leftSquare: .leftSquareToken(),
            arguments: args,
            rightSquare: .rightSquareToken()
        ))
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
        // selfExpression = "self" .  superclassExpression = "super" … — swift-syntax
        // models `self` as a DeclReferenceExpr but `super` as its own SuperExpr node.
        if find("selfExpression", in: spans) != nil {
            return ExprSyntax(DeclReferenceExprSyntax(baseName: .keyword(.self)))
        }
        if let d = find("closureExpression", in: spans) {
            return ExprSyntax(convertClosureExpression(d.nt, from: d.from, to: d.to))
        }
        // parenthesizedExpression = "(" expression ")" .
        if let parenNT = find("parenthesizedExpression", in: spans),
           let (_, parenSpans) = tileAlternate(parenNT.nt, from: parenNT.from, to: parenNT.to),
           let exprNT = find("expression", in: parenSpans) {
            return ExprSyntax(TupleExprSyntax(
                leftParen: .leftParenToken(),
                elements: LabeledExprListSyntax([
                    LabeledExprSyntax(expression: convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to))
                ]),
                rightParen: .rightParenToken()
            ))
        }
        if find("wildcardExpression", in: spans) != nil {
            return ExprSyntax(DiscardAssignmentExprSyntax(wildcard: .wildcardToken()))
        }
        // implicitParameterName - /\$[0-9]+/ .  A named TERMINAL, so `find` cannot see it.
        if let dollarNT = findTerminal(named: "implicitParameterName", in: spans) {
            let text = collectTerminalText(dollarNT.nt, from: dollarNT.from, to: dollarNT.to)
            return ExprSyntax(DeclReferenceExprSyntax(baseName: .dollarIdentifier(text)))
        }
        // superclassExpression = "super" .
        if find("superclassExpression", in: spans) != nil {
            return ExprSyntax(SuperExprSyntax(superKeyword: .keyword(.super)))
        }
        // implicitMemberExpression = "." moduleSelector? softIdentifier .
        // implicitMemberExpression = "." moduleSelector? softIdentifier "." postfixExpression .
        if let imNT = find("implicitMemberExpression", in: spans) {
            return convertImplicitMemberExpression(imNT.nt, from: imNT.from, to: imNT.to)
        }
        // tupleExpression = "(" ")" | "(" tupleElement "," tupleElementList ","? ")" .
        if let tupNT = find("tupleExpression", in: spans) {
            return convertTupleExpression(tupNT.nt, from: tupNT.from, to: tupNT.to)
        }
        if let idNT = find("identifier", in: spans) {
            let name = collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)
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
        // genericIdentifier = hardIdentifier | hardIdentifier genericArgumentClause .
        // With type arguments swift-syntax wraps the reference in a GenericSpecializationExpr
        // (`f<Int>` is a specialisation of the reference, not a differently-named reference).
        if let genNT = find("genericIdentifier", in: spans),
           let (_, genSpans) = tileAlternate(genNT.nt, from: genNT.from, to: genNT.to),
           let hardNT = find("hardIdentifier", in: genSpans) {
            let name = collectTerminalText(hardNT.nt, from: hardNT.from, to: hardNT.to)
            if !name.isEmpty {
                let reference = ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
                if let gcNT = find("genericArgumentClause", in: genSpans) {
                    return ExprSyntax(GenericSpecializationExprSyntax(
                        expression: reference,
                        genericArgumentClause: convertGenericArgumentClause(gcNT.nt, from: gcNT.from, to: gcNT.to)
                    ))
                }
                return reference
            }
        }
        return missingExpr(.unhandled, "primaryExpression form has no converter: \(alternateKind(spans))", from: from, to: to)
    }

    // MARK: - Literals

    /// literalExpression = literal | arrayLiteral | dictionaryLiteral .
    private mutating func convertLiteralExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        if let litNT = find("literal", in: spans) {
            return convertLiteral(litNT.nt, from: litNT.from, to: litNT.to)
        }
        if let arrNT = find("arrayLiteral", in: spans) {
            return convertArrayLiteral(arrNT.nt, from: arrNT.from, to: arrNT.to)
        }
        if let dictNT = find("dictionaryLiteral", in: spans) {
            return convertDictionaryLiteral(dictNT.nt, from: dictNT.from, to: dictNT.to)
        }
        return missingExpr(.unhandled, "literalExpression form has no converter: \(alternateKind(spans))", from: from, to: to)
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
            let text = collectTerminalText(boolNT.nt, from: boolNT.from, to: boolNT.to)
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
        // regularExpressionLiteral = plainRegularExpressionLiteral | extendedRegularExpressionLiteral .
        // swift-syntax keeps the whole literal as one `regexLiteralPattern` between slash
        // tokens; the `#…#` extended form additionally carries pound delimiters.
        if let reNT = find("regularExpressionLiteral", in: spans) {
            let text = collectTerminalText(reNT.nt, from: reNT.from, to: reNT.to)
            if text.hasPrefix("/") && text.hasSuffix("/") && text.count >= 2 {
                return ExprSyntax(RegexLiteralExprSyntax(
                    openingSlash: .regexSlashToken(),
                    regex: .regexLiteralPattern(String(text.dropFirst().dropLast())),
                    closingSlash: .regexSlashToken()
                ))
            }
            return missingExpr(.unhandled, "extended (#/…/#) regex literal not converted", from: from, to: to)
        }
        return missingExpr(.unhandled, "literal kind has no converter: \(alternateKind(spans))", from: from, to: to)
    }

    private mutating func convertNumericLiteral(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // numericLiteral = signedIntegerLiteral | signedFloatingPointLiteral .
        // Classify by spelling rather than by alternate: the two alternates differ
        // only in which literal terminal they reach, and the text decides it.
        let text = collectTerminalText(nt, from: from, to: to)
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
        let fullText = collectTerminalText(nt, from: from, to: to)
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
                    label: .identifier(collectTerminalText(labelNT.nt, from: labelNT.from, to: labelNT.to)),
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
        // arrayType = "[" type "]" .
        if let d = find("arrayType", in: spans),
           let (_, aSpans) = tileAlternate(d.nt, from: d.from, to: d.to),
           let elemNT = find("type", in: aSpans) {
            return TypeSyntax(ArrayTypeSyntax(
                leftSquare: .leftSquareToken(),
                element: convertType(elemNT.nt, from: elemNT.from, to: elemNT.to),
                rightSquare: .rightSquareToken()
            ))
        }
        // dictionaryType = "[" type ":" type "]" .
        if let d = find("dictionaryType", in: spans),
           let (_, dSpans) = tileAlternate(d.nt, from: d.from, to: d.to) {
            var types: [TypeSyntax] = []
            for (sym, f, t) in dSpans {
                if let tNT = findNonterminal(named: "type", sym: sym, from: f, to: t) {
                    types.append(convertType(tNT.nt, from: tNT.from, to: tNT.to))
                }
            }
            if types.count == 2 {
                return TypeSyntax(DictionaryTypeSyntax(
                    leftSquare: .leftSquareToken(),
                    key: types[0], colon: .colonToken(), value: types[1],
                    rightSquare: .rightSquareToken()
                ))
            }
            record(.lookupFailed, "dictionaryType did not yield key and value", from: d.from, to: d.to)
        }
        // metatypeType = simpleType "." "Type" | simpleType "." "Protocol" .
        if let d = find("metatypeType", in: spans),
           let (_, mSpans) = tileAlternate(d.nt, from: d.from, to: d.to),
           let baseNT = find("simpleType", in: mSpans) {
            let isProtocol = spansContainKeyword(mSpans, "Protocol")
            return TypeSyntax(MetatypeTypeSyntax(
                baseType: convertType(baseNT.nt, from: baseNT.from, to: baseNT.to),
                period: .periodToken(),
                metatypeSpecifier: isProtocol ? .keyword(.Protocol) : .keyword(.Type)
            ))
        }
        // implicitlyUnwrappedOptionalType = simpleType >s< forceMark .
        if let d = find("implicitlyUnwrappedOptionalType", in: spans),
           let (_, iSpans) = tileAlternate(d.nt, from: d.from, to: d.to),
           let baseNT = find("simpleType", in: iSpans) {
            return TypeSyntax(ImplicitlyUnwrappedOptionalTypeSyntax(
                wrappedType: convertType(baseNT.nt, from: baseNT.from, to: baseNT.to),
                exclamationMark: .exclamationMarkToken()
            ))
        }
        // anyType = "Any" .   swift-syntax models it as an IdentifierType named `Any`,
        // but with a KEYWORD token — `.identifier("Any")` would not match.
        if find("anyType", in: spans) != nil {
            return TypeSyntax(IdentifierTypeSyntax(name: .keyword(.Any)))
        }
        // tupleType = "(" ")" | "(" tupleTypeElement "," tupleTypeElementList ","? ")" .
        if let d = find("tupleType", in: spans) {
            return convertTupleType(d.nt, from: d.from, to: d.to)
        }
        // functionType = functionTypeArgumentClause "async"? throwsClause? "->" type .
        if let d = find("functionType", in: spans) {
            return convertFunctionType(d.nt, from: d.from, to: d.to)
        }
        // type = parameterModifier type .   type = attribute type .
        // swift-syntax wraps both in AttributedType: specifiers (`inout`, `borrowing`, `sending`)
        // go in `specifiers`, `@attr` goes in `attributes`, and the operand is `baseType`.
        if let innerNT = find("type", in: spans),
           find(firstOf: ["parameterModifier", "attribute"], in: spans) != nil {
            let base = convertType(innerNT.nt, from: innerNT.from, to: innerNT.to)
            var specifiers = TypeSpecifierListSyntax([])
            var attributes = AttributeListSyntax([])
            if let modNT = find("parameterModifier", in: spans) {
                let text = collectTerminalText(modNT.nt, from: modNT.from, to: modNT.to)
                if text.contains("(") {
                    record(.unhandled, "parameterised type specifier not converted", from: modNT.from, to: modNT.to)
                } else {
                    specifiers = TypeSpecifierListSyntax([
                        .simpleTypeSpecifier(SimpleTypeSpecifierSyntax(specifier: typeSpecifierToken(text)))
                    ])
                }
            }
            if let attrNT = find("attribute", in: spans) {
                if let attribute = convertAttribute(attrNT.nt, from: attrNT.from, to: attrNT.to) {
                    attributes = AttributeListSyntax([.attribute(attribute)])
                }
            }
            return TypeSyntax(AttributedTypeSyntax(
                specifiers: specifiers,
                attributes: attributes,
                baseType: base
            ))
        }
        // Everything else (composition, opaque, …) degrades to a flat IdentifierType
        // over the raw source text.
        let text = collectTerminalText(nt, from: from, to: to)
        record(.unhandled, "type form has no converter; flattened to IdentifierType: \(alternateKind(spans))", from: from, to: to)
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier(text)))
    }

    /// tupleType            = "(" ")" | "(" tupleTypeElement "," tupleTypeElementList ","? ")" .
    /// tupleTypeElementList = tupleTypeElement | tupleTypeElement "," tupleTypeElementList .
    /// tupleTypeElement     = elementName typeAnnotation | type .
    /// elementName          = hardIdentifier | "_" .
    private mutating func convertTupleType(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> TypeSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingType(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        var elements: [TupleTypeElementSyntax] = []
        if let firstNT = find("tupleTypeElement", in: spans) {
            appendTupleTypeElement(firstNT, into: &elements)
        }
        if let listNT = find("tupleTypeElementList", in: spans) {
            collectTupleTypeElements(listNT.nt, from: listNT.from, to: listNT.to, into: &elements)
        }
        if elements.count > 1 {
            for i in 0..<elements.count - 1 {
                elements[i] = elements[i].with(\.trailingComma, .commaToken())
            }
        }
        return TypeSyntax(TupleTypeSyntax(
            leftParen: .leftParenToken(),
            elements: TupleTypeElementListSyntax(elements),
            rightParen: .rightParenToken()
        ))
    }

    private mutating func collectTupleTypeElements(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [TupleTypeElementSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let elNT = find("tupleTypeElement", in: spans) {
            appendTupleTypeElement(elNT, into: &elements)
        }
        if let restNT = find("tupleTypeElementList", in: spans) {
            collectTupleTypeElements(restNT.nt, from: restNT.from, to: restNT.to, into: &elements)
        }
    }

    private mutating func appendTupleTypeElement(_ span: NTSpan, into elements: inout [TupleTypeElementSyntax]) {
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to) else {
            record(.lookupFailed, "no alternate tiles the span", from: span.from, to: span.to)
            return
        }
        // Labelled form: `elementName typeAnnotation`. swift-syntax puts the label in
        // `firstName` and a `_` label becomes a wildcard token, not an identifier.
        if let nameNT = find("elementName", in: spans),
           let taNT = find("typeAnnotation", in: spans),
           let (_, taSpans) = tileAlternate(taNT.nt, from: taNT.from, to: taNT.to),
           let typeNT = find("type", in: taSpans) {
            let label = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
            elements.append(TupleTypeElementSyntax(
                firstName: label == "_" ? .wildcardToken() : .identifier(label),
                colon: .colonToken(),
                type: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
            ))
            return
        }
        if let typeNT = find("type", in: spans) {
            elements.append(TupleTypeElementSyntax(type: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)))
            return
        }
        record(.lookupFailed, "tuple type element with neither label+annotation nor type", from: span.from, to: span.to)
    }

    /// functionType               = functionTypeArgumentClause "async"? throwsClause? "->" type .
    /// functionTypeArgumentClause = "(" ")" | "(" functionTypeArgumentList "..."? ","? ")" .
    /// functionTypeArgumentList   = functionTypeArgument | functionTypeArgument "," functionTypeArgumentList .
    /// functionTypeArgument       = type | externalArgumentLabel? localArgumentLabel typeAnnotation .
    private mutating func convertFunctionType(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> TypeSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingType(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        var parameters: [TupleTypeElementSyntax] = []
        if let clauseNT = find("functionTypeArgumentClause", in: spans),
           let (_, clauseSpans) = tileAlternate(clauseNT.nt, from: clauseNT.from, to: clauseNT.to) {
            if spansContainKeyword(clauseSpans, "...") {
                record(.unhandled, "variadic function-type parameter not converted", from: clauseNT.from, to: clauseNT.to)
            }
            if let listNT = find("functionTypeArgumentList", in: clauseSpans) {
                collectFunctionTypeArguments(listNT.nt, from: listNT.from, to: listNT.to, into: &parameters)
            }
        } else {
            record(.lookupFailed, "no functionTypeArgumentClause child", from: from, to: to)
        }
        if parameters.count > 1 {
            for i in 0..<parameters.count - 1 {
                parameters[i] = parameters[i].with(\.trailingComma, .commaToken())
            }
        }

        // swift-syntax: TypeEffectSpecifiers on a function TYPE (not FunctionEffectSpecifiers,
        // which is the declaration-side node).
        var effects: TypeEffectSpecifiersSyntax? = nil
        let isAsync = spansContainKeyword(spans, "async")
        var throwsClause: ThrowsClauseSyntax? = nil
        if let thNT = find("throwsClause", in: spans) {
            if let (_, thSpans) = tileAlternate(thNT.nt, from: thNT.from, to: thNT.to),
               find("type", in: thSpans) != nil {
                record(.unhandled, "typed throws in a function type not converted", from: thNT.from, to: thNT.to)
            }
            throwsClause = ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
        }
        if isAsync || throwsClause != nil {
            effects = TypeEffectSpecifiersSyntax(
                asyncSpecifier: isAsync ? .keyword(.async) : nil,
                throwsClause: throwsClause
            )
        }

        var returnType: TypeSyntax = TypeSyntax(MissingTypeSyntax())
        if let retNT = find("type", in: spans) {
            returnType = convertType(retNT.nt, from: retNT.from, to: retNT.to)
        } else {
            record(.lookupFailed, "no return type child", from: from, to: to)
        }

        return TypeSyntax(FunctionTypeSyntax(
            leftParen: .leftParenToken(),
            parameters: TupleTypeElementListSyntax(parameters),
            rightParen: .rightParenToken(),
            effectSpecifiers: effects,
            returnClause: ReturnClauseSyntax(arrow: .arrowToken(), type: returnType)
        ))
    }

    private mutating func collectFunctionTypeArguments(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into params: inout [TupleTypeElementSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let argNT = find("functionTypeArgument", in: spans),
           let (_, argSpans) = tileAlternate(argNT.nt, from: argNT.from, to: argNT.to) {
            if let taNT = find("typeAnnotation", in: argSpans),
               let (_, taSpans) = tileAlternate(taNT.nt, from: taNT.from, to: taNT.to),
               let typeNT = find("type", in: taSpans) {
                let ext = find("externalArgumentLabel", in: argSpans)
                let local = find("localArgumentLabel", in: argSpans)
                var first: TokenSyntax? = nil
                var second: TokenSyntax? = nil
                if let ext, let local {
                    first = .identifier(collectTerminalText(ext.nt, from: ext.from, to: ext.to))
                    second = .identifier(collectTerminalText(local.nt, from: local.from, to: local.to))
                } else if let only = local ?? ext {
                    let text = collectTerminalText(only.nt, from: only.from, to: only.to)
                    first = text == "_" ? .wildcardToken() : .identifier(text)
                }
                params.append(TupleTypeElementSyntax(
                    firstName: first, secondName: second,
                    colon: first == nil ? nil : .colonToken(),
                    type: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
                ))
            } else if let typeNT = find("type", in: argSpans) {
                params.append(TupleTypeElementSyntax(type: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)))
            } else {
                record(.lookupFailed, "function type argument with no type", from: argNT.from, to: argNT.to)
            }
        }
        if let restNT = find("functionTypeArgumentList", in: spans) {
            collectFunctionTypeArguments(restNT.nt, from: restNT.from, to: restNT.to, into: &params)
        }
    }

    /// genericArgumentClause / typeGenericArgumentClause = openAngle genericArgumentList ","? closeAngle .
    /// genericArgumentList = genericArgument | genericArgument "," genericArgumentList .
    /// genericArgument     = type | signedIntegerLiteral .
    private mutating func convertGenericArgumentClause(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> GenericArgumentClauseSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return GenericArgumentClauseSyntax(arguments: [])
        }
        var args: [GenericArgumentSyntax] = []
        if let listNT = find("genericArgumentList", in: spans) {
            collectGenericArguments(listNT.nt, from: listNT.from, to: listNT.to, into: &args)
        }
        if args.count > 1 {
            for i in 0..<args.count - 1 {
                args[i] = args[i].with(\.trailingComma, .commaToken())
            }
        }
        return GenericArgumentClauseSyntax(
            leftAngle: .leftAngleToken(),
            arguments: GenericArgumentListSyntax(args),
            rightAngle: .rightAngleToken()
        )
    }

    private mutating func collectGenericArguments(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into args: inout [GenericArgumentSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let gaNT = find("genericArgument", in: spans),
           let (_, gaSpans) = tileAlternate(gaNT.nt, from: gaNT.from, to: gaNT.to) {
            if let typeNT = find("type", in: gaSpans) {
                args.append(GenericArgumentSyntax(argument: .type(convertType(typeNT.nt, from: typeNT.from, to: typeNT.to))))
            } else {
                record(.unhandled, "integer-literal generic argument not converted", from: gaNT.from, to: gaNT.to)
            }
        }
        if let restNT = find("genericArgumentList", in: spans) {
            collectGenericArguments(restNT.nt, from: restNT.from, to: restNT.to, into: &args)
        }
    }

    /// typeIdentifier = typeName typeGenericArgumentClause? .
    /// typeIdentifier = typeIdentifier "." typeName typeGenericArgumentClause? .
    ///
    /// LEFT-recursive, so it maps directly onto swift-syntax's left-nesting `MemberType`:
    /// the recursive child IS the base. (It used to be right-recursive, copied from TSPL,
    /// which forced a collect-the-chain-then-fold-left dance here.)
    private mutating func convertTypeIdentifier(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> TypeSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingType(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        guard let nameNT = find("typeName", in: spans) else {
            return missingType(.lookupFailed, "no typeName child", from: from, to: to)
        }
        let text = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
        // `Self` is a keyword token in swift-syntax, not an identifier.
        let name: TokenSyntax = text == "Self" ? .keyword(.Self) : .identifier(text)

        var generics: GenericArgumentClauseSyntax? = nil
        if let gNT = find(firstOf: ["typeGenericArgumentClause", "genericArgumentClause"], in: spans) {
            generics = convertGenericArgumentClause(gNT.nt, from: gNT.from, to: gNT.to)
        }

        if let baseNT = find("typeIdentifier", in: spans) {
            return TypeSyntax(MemberTypeSyntax(
                baseType: convertTypeIdentifier(baseNT.nt, from: baseNT.from, to: baseNT.to),
                period: .periodToken(),
                name: name,
                genericArgumentClause: generics
            ))
        }
        return TypeSyntax(IdentifierTypeSyntax(name: name, genericArgumentClause: generics))
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

    /// Concatenated text of the terminals the parse actually committed inside
    /// `nt`'s span, found by walking the SAME tiling the tree is built from.
    ///
    /// This is the accurate path: a tile names both the terminal and its two
    /// boundaries, so `terminalContent` resolves exactly one commit. Scanning
    /// the commit log by position cannot do that — the log is a superset of the
    /// accepted derivation, and on `1.5` it holds the float `1.5` at the `1` AND
    /// `.5` at the `.`, which concatenated read `1.5.5`.
    ///
    /// Falls back to the positional scan when the tiling can't be reproduced,
    /// recording an `.unhandled` so the gap is visible rather than silent.
    private mutating func collectTerminalText(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> String {
        var text = ""
        tiledFailure = nil
        if tiledText(nt, from: from, to: to, into: &text) { return text }
        record(.unhandled, "tiled text walk failed (\(tiledFailure ?? "unknown")); fell back to commit-log scan", from: from, to: to)
        return scanTerminalText(from: from, to: to)
    }

    /// Append the text of `sym` over `[from, to)`, walking the tiling. Returns
    /// false if no tiling of `sym` covers the span exactly.
    private mutating func tiledText(_ sym: GrammarNode, from: CharPosition, to: CharPosition, into out: inout String) -> Bool {
        switch sym.kind {
        case .EPS:
            return from == to
        case .T, .TI, .C, .B:
            // Boundary assertions (`>s<`, `<s>`, `>n<`, `<n>`) sit in the body as
            // zero-width `.B` symbols. They never commit, so there is no image to look
            // up — and none is needed: a zero-width span contributes no text.
            if from == to { return true }
            guard let id = sym.nameID,
                  let content = parser.terminalContent(terminalID: id, triviaStart: from, triviaEnd: to)
            else {
                tiledFailure = "no commit for terminal '\(sym.name)' (\(sym.kind))"
                return false
            }
            out += content
            return true
        case .N:
            // Only an RHS *reference* resolves through `.alt` to its definition.
            // On an LHS node `.alt` is already the first ALTERNATE, so resolving
            // again would tile the wrong node's alternate chain.
            let def = sym.isRHS ? (sym.alt ?? sym) : sym
            guard let (_, spans) = tileAlternate(def, from: from, to: to) else {
                tiledFailure = "no alternate of '\(def.name)' tiles its span"
                return false
            }
            return tiledText(spans: spans, into: &out)
        case .KLN, .POS:
            return closureText(sym, from: from, to: to, allowEmpty: sym.kind == .KLN, into: &out)
        case .DO, .OPT:
            if from == to { return sym.kind == .OPT }
            guard let (_, spans) = tileAlternate(sym, from: from, to: to) else { return false }
            return tiledText(spans: spans, into: &out)
        default:
            tiledFailure = "unhandled node kind \(sym.kind) for '\(sym.name)'"
            return false
        }
    }

    private mutating func tiledText(spans: [(GrammarNode, CharPosition, CharPosition)], into out: inout String) -> Bool {
        for (sym, f, t) in spans where !tiledText(sym, from: f, to: t, into: &out) {
            return false
        }
        return true
    }

    /// A closure tile covers ALL its iterations at once, so peel them off one at
    /// a time, backtracking over the candidate ends of each iteration.
    private mutating func closureText(_ bracket: GrammarNode, from: CharPosition, to: CharPosition, allowEmpty: Bool, into out: inout String) -> Bool {
        if from == to { return allowEmpty }
        for end in iterationEndPositions(bracket, from: from).sorted() where end > from && end <= to {
            guard let (_, spans) = tileAlternate(bracket, from: from, to: end) else { continue }
            var piece = ""
            guard tiledText(spans: spans, into: &piece) else { continue }
            if end == to {
                out += piece
                return true
            }
            var rest = ""
            if closureText(bracket, from: end, to: to, allowEmpty: false, into: &rest) {
                out += piece + rest
                return true
            }
        }
        return false
    }

    /// Positional fallback: every commit in `[from, to)`, skipping ones that
    /// overlap a previously taken commit or run past the span end. Inexact —
    /// `terminalImage` resolves same-start commits by taking the LONGEST, which
    /// is a maximal-munch guess (see TODO 20).
    private func scanTerminalText(from: CharPosition, to: CharPosition) -> String {
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
