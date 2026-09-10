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

    /// Whitespace and comments only — what the scanner skips. Used to confirm that the part of
    /// the input NOT covered by the root yield carries no syntax.
    private func isTriviaOnly(_ text: Substring) -> Bool {
        var rest = text
        while let first = rest.first {
            if first.isWhitespace { rest = rest.dropFirst(); continue }
            if rest.hasPrefix("//") {
                guard let nl = rest.firstIndex(where: \.isNewline) else { return true }
                rest = rest[nl...]
                continue
            }
            if rest.hasPrefix("/*") {
                // Block comments NEST in Swift, so track the depth.
                var depth = 0
                var index = rest.startIndex
                while index < rest.endIndex {
                    if rest[index...].hasPrefix("/*") {
                        depth += 1
                        index = rest.index(index, offsetBy: 2)
                    } else if rest[index...].hasPrefix("*/") {
                        depth -= 1
                        index = rest.index(index, offsetBy: 2)
                        if depth == 0 { break }
                    } else {
                        index = rest.index(after: index)
                    }
                }
                guard depth == 0 else { return false }
                rest = rest[index...]
                continue
            }
            return false
        }
        return true
    }

    mutating func generate() -> SourceFileSyntax? {
        diagnostics.removeAll()
        // The root derivation covers the input MODULO TRIVIA. Comments are `=:` productions the
        // scanner skips, so a source beginning with `//` yields a root span that starts at the
        // first real TOKEN, not at `startIndex`. Demanding `i == startIndex && j == endIndex`
        // therefore rejected every comment-led source outright (33 corpus snippets), even though
        // they parse fine.
        //
        // `statements?` is nullable, so the root also yields many EMPTY spans; take the WIDEST
        // yield and then require that whatever falls outside it is trivia only.
        let n = input.endIndex
        guard let span = parser.yield(of: grammar.root).max(by: {
            input.distance(from: $0.i, to: $0.j) < input.distance(from: $1.i, to: $1.j)
        }) else {
            record(.lookupFailed, "no root yield at all", from: input.startIndex, to: n)
            return nil
        }
        let origin = span.i
        let end = span.j
        guard isTriviaOnly(input[input.startIndex..<origin]), isTriviaOnly(input[end..<n]) else {
            record(.lookupFailed, "root yield leaves non-trivia uncovered", from: input.startIndex, to: n)
            return nil
        }
        let items = convertNonterminal(grammar.root, from: origin, to: end)
        // topLevelDeclaration = shebang? statements? .   swift-syntax keeps the interpreter line
        // as a token on the SourceFile itself, ahead of the top-level items.
        var shebang: TokenSyntax? = nil
        if let (_, rootSpans) = tileAlternate(grammar.root, from: origin, to: end),
           let shNT = findTerminal(named: "shebang", in: rootSpans) {
            shebang = .shebang(collectTerminalText(shNT.nt, from: shNT.from, to: shNT.to))
        }
        return SourceFileSyntax(
            shebang: shebang,
            statements: CodeBlockItemListSyntax(items),
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
    private mutating func convertNonterminal(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> [CodeBlockItemSyntax] {
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

    private mutating func convertTopLevelDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> [CodeBlockItemSyntax] {
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

    /// Flatten a grammar list without depending on whether it is encoded as
    /// right recursion (`item "," list`) or native EBNF closure (`item { "," item }`).
    /// Descent is intentionally structural only: brackets and same-list recursion are
    /// walked, but arbitrary child nonterminals are not searched.
    private mutating func collectListElements(
        named elementName: String,
        in list: NTSpan,
        recursiveListName: String
    ) -> [NTSpan] {
        var elements: [NTSpan] = []
        let listNode = list.nt.isRHS ? (lhs(list.nt) ?? list.nt) : list.nt
        collectListElements(named: elementName, within: listNode, from: list.from, to: list.to,
                            recursiveListName: recursiveListName, into: &elements)
        return elements.sorted {
            if $0.from != $1.from { return $0.from < $1.from }
            return $0.to < $1.to
        }
    }

    private mutating func collectListElements(
        named elementName: String,
        within node: GrammarNode,
        from: CharPosition,
        to: CharPosition,
        recursiveListName: String,
        into elements: inout [NTSpan]
    ) {
        guard let (_, spans) = tileAlternate(node, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles list span", from: from, to: to)
            return
        }
        collectListElements(named: elementName, in: spans,
                            recursiveListName: recursiveListName, into: &elements)
    }

    private mutating func collectListElements(
        named elementName: String,
        in spans: [(GrammarNode, CharPosition, CharPosition)],
        recursiveListName: String,
        into elements: inout [NTSpan]
    ) {
        for (sym, from, to) in spans {
            collectListElements(named: elementName, through: sym, from: from, to: to,
                                recursiveListName: recursiveListName, into: &elements)
        }
    }

    private mutating func collectListElements(
        named elementName: String,
        through sym: GrammarNode,
        from: CharPosition,
        to: CharPosition,
        recursiveListName: String,
        into elements: inout [NTSpan]
    ) {
        if from == to && (sym.kind == .OPT || sym.kind == .KLN) { return }
        switch sym.kind {
        case .N:
            let def = sym.isRHS ? (lhs(sym) ?? sym) : sym
            if def.name == elementName {
                elements.append(NTSpan(nt: def, from: from, to: to))
            } else if def.name == recursiveListName {
                collectListElements(named: elementName, within: def, from: from, to: to,
                                    recursiveListName: recursiveListName, into: &elements)
            }
        case .DO, .OPT:
            if let (_, inner) = tileAlternate(sym, from: from, to: to) {
                collectListElements(named: elementName, in: inner,
                                    recursiveListName: recursiveListName, into: &elements)
            }
        case .KLN, .POS:
            collectClosureListElements(named: elementName, through: sym, from: from, to: to,
                                       recursiveListName: recursiveListName, into: &elements)
        default:
            break
        }
    }

    private mutating func collectClosureListElements(
        named elementName: String,
        through bracket: GrammarNode,
        from: CharPosition,
        to: CharPosition,
        recursiveListName: String,
        into elements: inout [NTSpan]
    ) {
        _ = tileClosureListElements(named: elementName, from: bracket, position: from, to: to,
                                    consumedOne: false, recursiveListName: recursiveListName,
                                    into: &elements)
    }

    private mutating func tileClosureListElements(
        named elementName: String,
        from bracket: GrammarNode,
        position: CharPosition,
        to: CharPosition,
        consumedOne: Bool,
        recursiveListName: String,
        into elements: inout [NTSpan]
    ) -> Bool {
        if position == to { return bracket.kind != .POS || consumedOne }

        let ends = iterationEndPositions(bracket, from: position).filter { $0 > position && $0 <= to }.sorted()
        for end in ends {
            var alt = bracket.alt
            while let a = alt {
                defer { alt = a.alt }
                guard let spans = tileBody(a.bodySymbols, from: position, to: end) else { continue }
                let restoreCount = elements.count
                collectListElements(named: elementName, in: spans,
                                    recursiveListName: recursiveListName, into: &elements)
                if tileClosureListElements(named: elementName, from: bracket, position: end, to: to,
                                           consumedOne: true, recursiveListName: recursiveListName,
                                           into: &elements) {
                    return true
                }
                elements.removeSubrange(restoreCount..<elements.count)
            }
        }
        return false
    }

    /// SE-0470 lets a list carry a trailing comma before its closer (`f(a, b,)`, `[1, 2,]`,
    /// `Foo<A,>`). The grammar spells it as an optional `","` AFTER the list nonterminal, and
    /// swift-syntax hangs it on the LAST element — so it cannot be seen from inside the list walk.
    private mutating func hasTrailingComma(_ spans: [(GrammarNode, CharPosition, CharPosition)], afterList list: String) -> Bool {
        guard let listSpan = spans.first(where: { findNonterminal(named: list, sym: $0.0, from: $0.1, to: $0.2) != nil })
        else { return false }
        for (sym, f, t) in spans where f >= listSpan.2 && f < t {
            var text = ""
            if (sym.kind.isTerminal || sym.kind == .OPT), tiledText(sym, from: f, to: t, into: &text), text == "," {
                return true
            }
        }
        return false
    }

    /// Is this list element terminated by an EXPLICIT `;`?
    ///
    /// Two places carry it: the trailing `";"?` of `statements = statement ";"?` (a direct
    /// terminal) and the separator of `statements = statement statementSeparator statements`,
    /// where `statementSeparator = <n> | ";"` hides it one level down. Checking only the direct
    /// terminal missed every separator case.
    private mutating func hasExplicitSemicolon(in spans: [(GrammarNode, CharPosition, CharPosition)]) -> Bool {
        if spansContainKeyword(spans, ";") { return true }
        guard let sepNT = find("statementSeparator", in: spans),
              let (_, sepSpans) = tileAlternate(sepNT.nt, from: sepNT.from, to: sepNT.to)
        else { return false }
        return spansContainKeyword(sepSpans, ";")
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

    /// Returns whole `CodeBlockItem`s, not bare items, because an explicit `;` belongs to the
    /// item it terminates (`CodeBlockItem.semicolon`) and is otherwise dropped.
    private mutating func convertStatements(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> [CodeBlockItemSyntax] {
        // statements = statement ";"? .
        // statements = statement statementSeparator statements .
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return []
        }
        var items: [CodeBlockItemSyntax] = []
        if let stmtNT = find("statement", in: spans),
           let item = convertStatement(stmtNT.nt, from: stmtNT.from, to: stmtNT.to) {
            items.append(CodeBlockItemSyntax(
                item: item,
                semicolon: hasExplicitSemicolon(in: spans) ? .semicolonToken() : nil
            ))
        }
        if let stmtsNT = find("statements", in: spans) {
            items.append(contentsOf: convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to))
        }
        return items
    }

    /// statement = @cannotParse(declaration attributes) expression .  |  @prefer declaration .
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
        // yieldStatement = "yield" >->( "(" "[" "." ) <s> >n< expression .
        if let yNT = find("yieldStatement", in: spans),
           let (_, ySpans) = tileAlternate(yNT.nt, from: yNT.from, to: yNT.to) {
            guard let exprNT = find("expression", in: ySpans) else {
                record(.lookupFailed, "yield without an expression", from: yNT.from, to: yNT.to)
                return nil
            }
            return .stmt(StmtSyntax(YieldStmtSyntax(
                yieldKeyword: .keyword(.yield),
                yieldedExpressions: .single(convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to))
            )))
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
        if let ccNT = find("compilerControlStatement", in: spans),
           let (_, ccSpans) = tileAlternate(ccNT.nt, from: ccNT.from, to: ccNT.to) {
            if let blockNT = find("conditionalCompilationBlock", in: ccSpans) {
                return .decl(DeclSyntax(convertConditionalCompilationBlock(blockNT.nt, from: blockNT.from, to: blockNT.to)))
            }
            record(.unhandled, "#sourceLocation line-control statement not converted", from: ccNT.from, to: ccNT.to)
            return nil
        }
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
        // labeledStatement = statementLabel ( loopStatement | conditionalExpression | doStatement ) .
        // statementLabel   = labelName ":" .
        // A labelled `if`/`switch` wraps the if/switch EXPRESSION in an ExpressionStmt, exactly as
        // an unlabelled one does in statement position.
        if let lsNT = find("labeledStatement", in: spans),
           let (_, lsSpans) = tileAlternate(lsNT.nt, from: lsNT.from, to: lsNT.to),
           // `labelName` sits one level down inside `statementLabel`, and `find` does not descend
           // through nonterminals — looking for it directly failed silently.
           let slNT = find("statementLabel", in: lsSpans),
           let (_, slSpans) = tileAlternate(slNT.nt, from: slNT.from, to: slNT.to),
           let labelNT = find("labelName", in: slSpans) {
            var inner: StmtSyntax? = nil
            if let loopNT = find("loopStatement", in: lsSpans) {
                inner = convertLoopStatement(loopNT.nt, from: loopNT.from, to: loopNT.to)
            } else if let doNT = find("doStatement", in: lsSpans) {
                inner = convertDoStatement(doNT.nt, from: doNT.from, to: doNT.to)
            } else if let condNT = find("conditionalExpression", in: lsSpans) {
                inner = StmtSyntax(ExpressionStmtSyntax(
                    expression: convertConditionalExpression(condNT.nt, from: condNT.from, to: condNT.to)
                ))
            }
            guard let statement = inner else {
                record(.unhandled, "labelled statement body has no converter: \(alternateKind(lsSpans))",
                       from: lsNT.from, to: lsNT.to)
                return nil
            }
            return .stmt(StmtSyntax(LabeledStmtSyntax(
                label: .identifier(collectTerminalText(labelNT.nt, from: labelNT.from, to: labelNT.to)),
                colon: .colonToken(),
                statement: statement
            )))
        }
        // discardStatement = "discard" >-> ( "(" "[" "." ) <s> >n< expression .
        if let dNT = find("discardStatement", in: spans),
           let (_, dSpans) = tileAlternate(dNT.nt, from: dNT.from, to: dNT.to),
           let exprNT = find("expression", in: dSpans) {
            return .stmt(StmtSyntax(DiscardStmtSyntax(
                discardKeyword: .keyword(.discard),
                expression: convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
            )))
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
                                             inheritanceClause: inherit,
                                             genericWhereClause: nominalWhereClause(d),
                                             memberBlock: members))
        }
        if let d = find("classDeclaration", in: spans) {
            let (name, attrs, modifiers, generics, inherit, members) = nominalParts(d, nameRule: "className", bodyRule: "classBody", membersRule: "classMembers", memberRule: "classMember")
            return DeclSyntax(ClassDeclSyntax(attributes: attrs, modifiers: modifiers, name: name,
                                             genericParameterClause: generics,
                                             inheritanceClause: inherit,
                                             genericWhereClause: nominalWhereClause(d),
                                             memberBlock: members))
        }
        if let d = find("enumDeclaration", in: spans) {
            // enumDeclaration inlines its braces — no body nonterminal.
            let (name, attrs, modifiers, generics, inherit, members) = nominalParts(d, nameRule: "enumName", bodyRule: nil, membersRule: "enumMembers", memberRule: "enumMember")
            return DeclSyntax(EnumDeclSyntax(attributes: attrs, modifiers: modifiers, name: name,
                                             genericParameterClause: generics,
                                             inheritanceClause: inherit,
                                             genericWhereClause: nominalWhereClause(d),
                                             memberBlock: members))
        }
        if let d = find("protocolDeclaration", in: spans) {
            let (name, attrs, modifiers, _, inherit, members) = nominalParts(d, nameRule: "protocolName", bodyRule: "protocolBody", membersRule: "protocolMembers", memberRule: "protocolMember")
            // A protocol's `<…>` is a PRIMARY ASSOCIATED TYPE clause (SE-0346), a different node
            // from a generic parameter clause even though the surface syntax matches — so it is
            // read here rather than taken from `nominalParts`.
            var primary: PrimaryAssociatedTypeClauseSyntax? = nil
            if let (_, pSpans) = tileAlternate(d.nt, from: d.from, to: d.to),
               let pcNT = find("primaryAssociatedTypeClause", in: pSpans) {
                primary = convertPrimaryAssociatedTypeClause(pcNT.nt, from: pcNT.from, to: pcNT.to)
            }
            var protocolWhere: GenericWhereClauseSyntax? = nil
            if let (_, pSpans) = tileAlternate(d.nt, from: d.from, to: d.to),
               let wcNT = find("genericWhereClause", in: pSpans) {
                protocolWhere = convertGenericWhereClause(wcNT.nt, from: wcNT.from, to: wcNT.to)
            }
            return DeclSyntax(ProtocolDeclSyntax(attributes: attrs, modifiers: modifiers, name: name,
                                             primaryAssociatedTypeClause: primary,
                                             inheritanceClause: inherit,
                                             genericWhereClause: protocolWhere,
                                             memberBlock: members))
        }
        if let d = find("actorDeclaration", in: spans) {
            let (name, attrs, modifiers, generics, inherit, members) = nominalParts(d,
                nameRule: "actorName", bodyRule: "actorBody",
                membersRule: "actorMembers", memberRule: "actorMember")
            return DeclSyntax(ActorDeclSyntax(attributes: attrs, modifiers: modifiers, name: name,
                                              genericParameterClause: generics,
                                              inheritanceClause: inherit,
                                              genericWhereClause: nominalWhereClause(d),
                                              memberBlock: members))
        }
        if let d = find("extensionDeclaration", in: spans) {
            return DeclSyntax(convertExtensionDeclaration(d.nt, from: d.from, to: d.to))
        }
        if let d = find("importDeclaration", in: spans) {
            return DeclSyntax(convertImportDeclaration(d.nt, from: d.from, to: d.to))
        }
        if let d = find("associatedTypeDeclaration", in: spans) {
            return DeclSyntax(convertAssociatedTypeDeclaration(d.nt, from: d.from, to: d.to))
        }
        if let d = find("precedenceGroupDeclaration", in: spans) {
            return DeclSyntax(convertPrecedenceGroupDeclaration(d.nt, from: d.from, to: d.to))
        }
        if let d = find("macroDeclaration", in: spans) {
            return DeclSyntax(convertMacroDeclaration(d.nt, from: d.from, to: d.to))
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
        if let d = find("macroExpansionDeclaration", in: spans) {
            return convertMacroExpansionDeclaration(d.nt, from: d.from, to: d.to)
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
            } else if let wsNT = find("willSetDidSetBlock", in: spans) {
                accessorBlock = convertWillSetDidSetBlock(wsNT.nt, from: wsNT.from, to: wsNT.to)
            } else if let iabNT = find("initializedAccessorBlock", in: spans) {
                // initializedAccessorBlock = @cannotParse(accessorBlockBrace) codeBlock
                //                          | "{" accessorClauseListNoInit "}"
                //                          | "{" initAccessorClause accessorClauseList? "}"
                //                          | @excludedFrom(variableDeclaration) accessorBlockBrace .
                // This is an ACCESSOR block (get/set/init), NOT a willSet/didSet one — routing it
                // to the observer converter found no observers and produced an empty list.
                accessorBlock = convertInitializedAccessorBlock(iabNT.nt, from: iabNT.from, to: iabNT.to)
            }
            // `var _: T` — swift-syntax uses a WildcardPattern here, not an IdentifierPattern
            // whose identifier happens to be `_`.
            let bindingPattern: PatternSyntax = name == "_"
                ? PatternSyntax(WildcardPatternSyntax(wildcard: .wildcardToken()))
                : PatternSyntax(IdentifierPatternSyntax(identifier: identifierPatternToken(name)))
            bindings = [PatternBindingSyntax(
                pattern: bindingPattern,
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

    /// primaryAssociatedTypeClause = openAngle primaryAssociatedTypeList ","? closeAngle .
    /// primaryAssociatedTypeList   = hardIdentifier { "," hardIdentifier } .
    private mutating func convertPrimaryAssociatedTypeClause(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition
    ) -> PrimaryAssociatedTypeClauseSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let listNT = find("primaryAssociatedTypeList", in: spans) else {
            record(.lookupFailed, "no primaryAssociatedTypeList child", from: from, to: to)
            return nil
        }
        var items: [PrimaryAssociatedTypeSyntax] = []
        collectPrimaryAssociatedTypes(listNT.nt, from: listNT.from, to: listNT.to, into: &items)
        for i in items.indices.dropLast() {
            items[i] = items[i].with(\.trailingComma, .commaToken())
        }
        // SE-0470 trailing comma, kept on the LAST element.
        if hasTrailingComma(spans, afterList: "primaryAssociatedTypeList"), !items.isEmpty {
            items[items.count - 1] = items[items.count - 1].with(\.trailingComma, .commaToken())
        }
        return PrimaryAssociatedTypeClauseSyntax(
            leftAngle: .leftAngleToken(),
            primaryAssociatedTypes: PrimaryAssociatedTypeListSyntax(items),
            rightAngle: .rightAngleToken()
        )
    }

    private mutating func collectPrimaryAssociatedTypes(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [PrimaryAssociatedTypeSyntax]
    ) {
        let list = NTSpan(nt: nt, from: from, to: to)
        for idNT in collectListElements(named: "hardIdentifier", in: list, recursiveListName: "primaryAssociatedTypeList") {
            items.append(PrimaryAssociatedTypeSyntax(
                name: .identifier(collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to))
            ))
        }
    }

    /// The trailing `where` clause of a nominal declaration. `nominalParts` cannot carry it —
    /// `declHeadModifiers` only returns modifiers — so each nominal branch reads it here.
    private mutating func nominalWhereClause(_ span: NTSpan) -> GenericWhereClauseSyntax? {
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to),
              let wcNT = find("genericWhereClause", in: spans) else { return nil }
        return convertGenericWhereClause(wcNT.nt, from: wcNT.from, to: wcNT.to)
    }

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
        var extensionWhere: GenericWhereClauseSyntax? = nil
        if let wcNT = find("genericWhereClause", in: spans) {
            extensionWhere = convertGenericWhereClause(wcNT.nt, from: wcNT.from, to: wcNT.to)
        }
        return ExtensionDeclSyntax(
            attributes: attributes,
            modifiers: modifiers,
            extendedType: extended,
            inheritanceClause: inheritance,
            genericWhereClause: extensionWhere,
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
        // typeInheritanceClause = ":" typeInheritance { "," typeInheritance } .
        var types: [InheritedTypeSyntax] = []
        collectInheritedTypes(nt, from: from, to: to, into: &types)
        return InheritanceClauseSyntax(
            colon: .colonToken(),
            inheritedTypes: InheritedTypeListSyntax(types)
        )
    }

    private mutating func collectInheritedTypes(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into types: inout [InheritedTypeSyntax]) {
        let list = NTSpan(nt: nt, from: from, to: to)
        for inheritanceNT in collectListElements(named: "typeInheritance", in: list, recursiveListName: "typeInheritanceClause") {
            appendInheritedType(inheritanceNT, into: &types)
        }
        if types.count > 1 {
            for i in 0..<types.count - 1 {
                types[i] = types[i].with(\.trailingComma, .commaToken())
            }
        }
    }

    private mutating func appendInheritedType(_ inheritanceNT: NTSpan, into types: inout [InheritedTypeSyntax]) {
        guard let (_, spans) = tileAlternate(inheritanceNT.nt, from: inheritanceNT.from, to: inheritanceNT.to) else {
            record(.lookupFailed, "no alternate tiles the span", from: inheritanceNT.from, to: inheritanceNT.to)
            return
        }
        guard let tiNT = find("typeIdentifier", in: spans) else { return }

        var type = convertTypeIdentifier(tiNT.nt, from: tiNT.from, to: tiNT.to)
        // `~Copyable` — SE-0390 suppressed conformance. swift-syntax: SuppressedType.
        if spansContainKeyword(spans, "~") {
            type = TypeSyntax(SuppressedTypeSyntax(withoutTilde: .prefixOperator("~"), type: type))
        }
        // `: @retroactive P` / `: nonisolated P` — swift-syntax wraps the conformance in an
        // AttributedType. SE-0414 nonisolated conformance is BARE only (see the grammar note),
        // so it is always a plain specifier with no argument here.
        var attributeItems: [AttributeListSyntax.Element] = []
        if let attrNT = find("attributes", in: spans) {
            attributeItems = Array(convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to))
        }
        // AttributedType has TWO specifier lists, split by where the attributes sit. The
        // grammar puts `attributes?` before `nonisolated`, so with attributes present it is a
        // LATE specifier (`: @preconcurrency nonisolated Q`) and without them an early one
        // (`: nonisolated Q`) — measured both ways.
        var specifiers: [TypeSpecifierListSyntax.Element] = []
        if spansContainKeyword(spans, "nonisolated") {
            specifiers.append(.nonisolatedTypeSpecifier(NonisolatedTypeSpecifierSyntax(
                nonisolatedKeyword: .keyword(.nonisolated)
            )))
        }
        if !attributeItems.isEmpty || !specifiers.isEmpty {
            let late = attributeItems.isEmpty ? [] : specifiers
            type = TypeSyntax(AttributedTypeSyntax(
                specifiers: TypeSpecifierListSyntax(attributeItems.isEmpty ? specifiers : []),
                attributes: AttributeListSyntax(attributeItems),
                lateSpecifiers: TypeSpecifierListSyntax(late),
                baseType: type
            ))
        }
        types.append(InheritedTypeSyntax(type: type))
    }

    /// memberDeclaration = declaration | freestandingMacroExpansionDeclaration | bodylessInitializerDeclaration .
    ///
    /// The two non-`declaration` alternates are MEMBER-ONLY, so `convertDeclaration` never sees
    /// them and they were reported as "no converter" even though both map cleanly.
    private mutating func memberOnlyDeclaration(
        _ spans: [(GrammarNode, CharPosition, CharPosition)], from: CharPosition, to: CharPosition
    ) -> DeclSyntax? {
        // freestandingMacroExpansionDeclaration = macroHead genericArgumentClause? functionCallArgumentClause? trailingClosures? .
        // The BARE `#foo` form — same children as the attributed `macroExpansionDeclaration`, but
        // with no attributes or modifiers to carry.
        if let fmNT = find("freestandingMacroExpansionDeclaration", in: spans),
           let (_, fmSpans) = tileAlternate(fmNT.nt, from: fmNT.from, to: fmNT.to),
           let parts = macroExpansionParts(fmSpans, from: fmNT.from, to: fmNT.to) {
            return DeclSyntax(MacroExpansionDeclSyntax(
                pound: .poundToken(),
                moduleSelector: parts.selector,
                macroName: .identifier(parts.name),
                genericArgumentClause: parts.generics,
                leftParen: parts.parens ? .leftParenToken() : nil,
                arguments: parts.args,
                rightParen: parts.parens ? .rightParenToken() : nil,
                trailingClosure: parts.trailing,
                additionalTrailingClosures: parts.additional
            ))
        }
        // bodylessInitializerDeclaration = initializerHead … (no body) — `init()` in a protocol.
        // Its children are named exactly as the full form's, so the same converter applies and
        // simply finds no body.
        if let biNT = find("bodylessInitializerDeclaration", in: spans) {
            return DeclSyntax(convertInitializerDeclaration(biNT.nt, from: biNT.from, to: biNT.to))
        }
        return nil
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
                    // `<kind>Members = <kind>Member ";"? .` — an explicit `;` belongs to the
                    // member it terminates, exactly as for statements.
                    items.append(MemberBlockItemSyntax(
                        decl: decl,
                        semicolon: hasExplicitSemicolon(in: spans) ? .semicolonToken() : nil
                    ))
                } else if let decl = memberOnlyDeclaration(mdSpans, from: mdNT.from, to: mdNT.to) {
                    items.append(MemberBlockItemSyntax(
                        decl: decl,
                        semicolon: hasExplicitSemicolon(in: spans) ? .semicolonToken() : nil
                    ))
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
        var cases: [SwitchCaseListSyntax.Element] = []
        if let scNT = find("switchCases", in: spans) {
            collectSwitchCases(scNT.nt, from: scNT.from, to: scNT.to, into: &cases)
        }
        return SwitchExprSyntax(
            switchKeyword: .keyword(.switch),
            subject: subject,
            leftBrace: .leftBraceToken(),
            cases: SwitchCaseListSyntax(cases),
            rightBrace: .rightBraceToken()
        )
    }

    /// switchCases  = switchCase switchCases? .
    /// switchCase   = caseLabel statements | defaultLabel statements | conditionalSwitchCase .
    /// caseLabel    = switchCaseAttribute? "case" caseItemList ":" .
    /// defaultLabel = switchCaseAttribute? "default" ":" .
    /// Yields `SwitchCaseList` ELEMENTS rather than cases, because `#if` around a group of cases
    /// is a PEER of those cases in swift-syntax (`.ifConfigDecl`), not a wrapper — so it has to
    /// keep its source position in the list.
    private mutating func collectSwitchCases(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into cases: inout [SwitchCaseListSyntax.Element]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let scNT = find("switchCase", in: spans),
           let (_, scSpans) = tileAlternate(scNT.nt, from: scNT.from, to: scNT.to) {
            // switchCaseAttribute = "@" >s< attributeName .  It lives inside caseLabel /
            // defaultLabel, NOT directly under switchCase — which is why looking for it here
            // found nothing and the mismatch was SILENT. swift-syntax hangs it on the
            // SwitchCase itself, before the label.
            var caseAttributes: AttributeSyntax? = nil
            var label: SwitchCaseSyntax.Label? = nil
            if let clNT = find("caseLabel", in: scSpans),
               let (_, clSpans) = tileAlternate(clNT.nt, from: clNT.from, to: clNT.to) {
                caseAttributes = switchCaseAttributes(in: clSpans)
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
            } else if let dlNT = find("defaultLabel", in: scSpans) {
                if let (_, dlSpans) = tileAlternate(dlNT.nt, from: dlNT.from, to: dlNT.to) {
                    caseAttributes = switchCaseAttributes(in: dlSpans)
                }
                label = .default(SwitchDefaultLabelSyntax(
                    defaultKeyword: .keyword(.default),
                    colon: .colonToken()
                ))
            }

            if let label {
                var items: [CodeBlockItemSyntax] = []
                if let stmtsNT = find("statements", in: scSpans) {
                    items = convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to)
                }
                cases.append(.switchCase(SwitchCaseSyntax(
                    attribute: caseAttributes,
                    label: label,
                    statements: CodeBlockItemListSyntax(items)
                )))
            } else if let ccNT = find("conditionalSwitchCase", in: scSpans) {
                if let decl = convertConditionalSwitchCase(ccNT.nt, from: ccNT.from, to: ccNT.to) {
                    cases.append(.ifConfigDecl(decl))
                }
            } else {
                record(.unhandled, "switch case form has no converter: \(alternateKind(scSpans))", from: scNT.from, to: scNT.to)
            }
        }
        if let restNT = find("switchCases", in: spans) {
            collectSwitchCases(restNT.nt, from: restNT.from, to: restNT.to, into: &cases)
        }
    }

    /// `switchCaseAttribute = "@" >s< attributeName .` — `@unknown default:` and friends.
    /// swift-syntax models this as a SINGLE optional `unknownAttr`, not an AttributeList —
    /// the position exists for `@unknown default:` specifically.
    private mutating func switchCaseAttributes(in spans: [(GrammarNode, CharPosition, CharPosition)]) -> AttributeSyntax? {
        guard let attrNT = find("switchCaseAttribute", in: spans),
              let (_, aSpans) = tileAlternate(attrNT.nt, from: attrNT.from, to: attrNT.to),
              let nameNT = find("attributeName", in: aSpans) else { return nil }
        let name = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
        return AttributeSyntax(
            atSign: .atSignToken(),
            attributeName: IdentifierTypeSyntax(name: .identifier(name))
        )
    }

    /// caseItemList = matchPattern whereClause? { "," matchPattern whereClause? } .
    private mutating func collectCaseItems(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [SwitchCaseItemSyntax]) {
        let list = NTSpan(nt: nt, from: from, to: to)
        let patterns = collectListElements(named: "matchPattern", in: list, recursiveListName: "caseItemList")
        let whereClauses = collectListElements(named: "whereClause", in: list, recursiveListName: "caseItemList")
        for (index, mpNT) in patterns.enumerated() {
            // whereClause     = "where" whereExpression .
            // whereExpression = conditionExpression .   ← NOT `expression`
            var whereClause: WhereClauseSyntax? = nil
            let nextStart = patterns.indices.contains(index + 1) ? patterns[index + 1].from : to
            if let wcNT = whereClauses.first(where: { $0.from >= mpNT.to && $0.from < nextStart }) {
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
    }

    /// matchPattern = wildcardPattern | identifierPattern | valueBindingPattern
    ///              | tupleMatchPattern | enumCasePattern | optionalPattern
    ///              | typeCastingPattern | @prefer expressionPattern .
    ///
    /// INVARIANT — every route out of here must emit the EXPRESSION-flavoured shape.
    /// In match position swift parses an expression and wraps it in `ExpressionPattern`; the
    /// Wildcard/Identifier/EnumCase pattern nodes are Sema's, not the parser's (Swift.apus:3011,
    /// probe-verified). `@prefer expressionPattern` models exactly that, so anything the
    /// expression route reaches is already right. The dedicated rules — `tupleMatchPattern`,
    /// `enumCasePattern` — exist only for COVERAGE, because `(let a, let b)` and `.a(let y)` are
    /// not valid expressions; they are NOT a licence to emit a different node type.
    /// Giving `tupleMatchPattern` a `TuplePattern` (the DECLARATION shape) is the mistake that
    /// was made here first, and it hid because `case (1, 2)` IS an expression and never took
    /// that route.
    ///
    /// Only the forms with a settled shape are converted; the rest record `.unhandled`.
    ///
    /// `binding` = we are inside a `valueBindingPattern` (`case let y`). That changes the
    /// answer for a bare identifier: swift-syntax makes it an `IdentifierPattern` (it BINDS a
    /// new name), whereas in a plain match position the same spelling is an `ExpressionPattern`
    /// (it COMPARES against an existing value). Our grammar can't express the distinction —
    /// `matchPattern = @prefer expressionPattern` prunes the identifierPattern alternate before
    /// the converter sees it — so the binding context is re-applied here.
    /// Inside a value binding, each element of a call or tuple that is a BARE identifier binds a
    /// new name, so swift-syntax wraps it in `PatternExpr(IdentifierPattern)`. Anything else —
    /// `y[0]`, a literal, a member access — stays an expression and is compared, not bound.
    private func bindingPatternElements(_ list: LabeledExprListSyntax) -> LabeledExprListSyntax {
        LabeledExprListSyntax(list.map { element in
            guard let ref = element.expression.as(DeclReferenceExprSyntax.self),
                  ref.argumentNames == nil,
                  case .identifier(let name) = ref.baseName.tokenKind
            else { return element }
            return element.with(\.expression, ExprSyntax(PatternExprSyntax(
                pattern: IdentifierPatternSyntax(identifier: identifierPatternToken(name))
            )))
        })
    }

    private mutating func convertMatchPattern(_ nt: GrammarNode, from: CharPosition, to: CharPosition, binding: Bool = false) -> PatternSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingPattern(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        if find("wildcardPattern", in: spans) != nil {
            return PatternSyntax(WildcardPatternSyntax(wildcard: .wildcardToken()))
        }
        if let d = find("identifierPattern", in: spans) {
            let name = collectTerminalText(d.nt, from: d.from, to: d.to)
            return PatternSyntax(IdentifierPatternSyntax(identifier: identifierPatternToken(name)))
        }
        // expressionPattern = expression .  (`case 1:`, `case .foo:` — swift-syntax
        // wraps the expression in ExpressionPatternSyntax.)
        if let d = find("expressionPattern", in: spans),
           let (_, epSpans) = tileAlternate(d.nt, from: d.from, to: d.to),
           let exprNT = find("expression", in: epSpans) {
            var expr = convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
            if binding, let ref = expr.as(DeclReferenceExprSyntax.self), ref.argumentNames == nil,
               case .identifier(let name) = ref.baseName.tokenKind {
                return PatternSyntax(IdentifierPatternSyntax(identifier: identifierPatternToken(name)))
            }
            // `case let .a(y)`: inside a value binding the call's ARGUMENTS bind too, so
            // swift-syntax wraps each bare identifier in PatternExpr(IdentifierPattern) rather
            // than leaving it a DeclReferenceExpr. The binding context is only known here — the
            // expression path below has no way to carry it — so the rewrite happens at this site.
            // The same applies to a parenthesised list: `case let (y[0], z)` binds `z` but not
            // `y[0]`, so the rewrite is per-ELEMENT in both the call and the tuple shape.
            if binding, let call = expr.as(FunctionCallExprSyntax.self) {
                expr = ExprSyntax(call.with(\.arguments, bindingPatternElements(call.arguments)))
            }
            if binding, let tuple = expr.as(TupleExprSyntax.self) {
                expr = ExprSyntax(tuple.with(\.elements, bindingPatternElements(tuple.elements)))
            }
            // `case let copy as T` — the binding is the FIRST element of a flat sequence, so the
            // same rewrite applies there. Only the first element can be the bound name; later
            // ones are operators and operands.
            if binding, let sequence = expr.as(SequenceExprSyntax.self),
               let head = sequence.elements.first,
               let ref = head.as(DeclReferenceExprSyntax.self),
               ref.argumentNames == nil,
               case .identifier(let name) = ref.baseName.tokenKind {
                var rewritten = Array(sequence.elements)
                rewritten[0] = ExprSyntax(PatternExprSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(name))
                ))
                expr = ExprSyntax(sequence.with(\.elements, ExprListSyntax(rewritten)))
            }
            // `case let y[z]` — a SUBSCRIPT's arguments bind the same way a call's do.
            if binding, let subscriptCall = expr.as(SubscriptCallExprSyntax.self) {
                expr = ExprSyntax(subscriptCall.with(
                    \.arguments, bindingPatternElements(subscriptCall.arguments)
                ))
            }
            return PatternSyntax(ExpressionPatternSyntax(expression: expr))
        }
        // valueBindingPattern = ("let"|"var"|…) matchPattern .
        if let d = find("valueBindingPattern", in: spans),
           let (_, vbSpans) = tileAlternate(d.nt, from: d.from, to: d.to),
           let innerNT = find("matchPattern", in: vbSpans) {
            // valueBindingPattern = ( "var" | "let" | "inout" | "borrowing" | "_borrowing"
            //                        | "_consuming" | "_mutating" ) matchPattern .
            // All seven are legal binding specifiers; defaulting the five rarer ones to `let`
            // produced a tree that read as `let` and silently differed.
            let text = collectTerminalText(d.nt, from: d.from, to: d.to)
            let specifier: TokenSyntax
            switch true {
            case text.hasPrefix("var"):         specifier = .keyword(.var)
            case text.hasPrefix("let"):         specifier = .keyword(.let)
            case text.hasPrefix("inout"):       specifier = .keyword(.inout)
            case text.hasPrefix("_borrowing"):  specifier = .keyword(._borrowing)
            case text.hasPrefix("borrowing"):   specifier = .keyword(.borrowing)
            default:
                // `_consuming` / `_mutating` are real binding specifiers, but their `Keyword`
                // cases are `@_spi`-protected and cannot be constructed from here — the same
                // limitation as the `read`/`modify` accessor keywords.
                record(.unhandled, "value-binding specifier not constructible: \(text.prefix(while: { !$0.isWhitespace }))", from: from, to: to)
                specifier = .keyword(.let)
            }
            return PatternSyntax(ValueBindingPatternSyntax(
                bindingSpecifier: specifier,
                pattern: convertMatchPattern(innerNT.nt, from: innerNT.from, to: innerNT.to, binding: true)
            ))
        }
        // typeCastingPattern = isPattern .   isPattern = "is" type .
        // (`asPattern` is deliberately absent — see the grammar note: `x as T` in a pattern is a
        // SequenceExpr already covered by `@prefer expressionPattern`.)
        if let tcNT = find("typeCastingPattern", in: spans),
           let (_, tcSpans) = tileAlternate(tcNT.nt, from: tcNT.from, to: tcNT.to),
           let isNT = find("isPattern", in: tcSpans),
           let (_, isSpans) = tileAlternate(isNT.nt, from: isNT.from, to: isNT.to),
           let typeNT = find("type", in: isSpans) {
            return PatternSyntax(IsTypePatternSyntax(
                isKeyword: .keyword(.is),
                type: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
            ))
        }
        // tupleMatchPattern = "(" tupleMatchElementList? ")" .
        if let tupNT = find("tupleMatchPattern", in: spans) {
            return convertTupleMatchPattern(tupNT.nt, from: tupNT.from, to: tupNT.to)
        }
        // enumCasePattern = typeIdentifier? "." enumCaseName tupleMatchPattern?
        //                 | enumCaseName tupleMatchPattern .
        // swift-syntax has no dedicated node: it is an ExpressionPattern over a
        // MemberAccessExpr (optionally called with the associated-value patterns).
        if let ecNT = find("enumCasePattern", in: spans) {
            return convertEnumCasePattern(ecNT.nt, from: ecNT.from, to: ecNT.to)
        }
        return missingPattern(.unhandled, "match pattern form has no converter: \(alternateKind(spans))", from: from, to: to)
    }

    /// tupleMatchPattern     = "(" tupleMatchElementList? ")" .
    /// tupleMatchElement     = matchPattern | softIdentifier ":" matchPattern .
    private mutating func convertTupleMatchPattern(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> PatternSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingPattern(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        var elements: [TuplePatternElementSyntax] = []
        if let listNT = find("tupleMatchElementList", in: spans) {
            collectTupleMatchElements(listNT.nt, from: listNT.from, to: listNT.to, into: &elements)
        }
        // A parenthesised pattern in MATCH position is an ExpressionPattern over a TupleExpr whose
        // elements are `PatternExpr`s — NOT a TuplePattern. TuplePattern is the DECLARATION binding
        // shape (`let (x, y) = …`, handled by `convertTupleBindingPattern`). This is the same
        // declaration-vs-switch-case split that `ParserProbe.patternNodeShapeProbe` documents.
        let args = elements.enumerated().map { index, element -> LabeledExprSyntax in
            // An element that is ALREADY an expression pattern contributes its expression
            // directly — `case (2, let x)` gives `IntegerLiteralExpr` for `2` and a `PatternExpr`
            // only for `let x`. Wrapping everything produced `PatternExpr(ExpressionPattern(2))`.
            let expression: ExprSyntax
            if let exprPattern = element.pattern.as(ExpressionPatternSyntax.self) {
                expression = exprPattern.expression
            } else {
                expression = ExprSyntax(PatternExprSyntax(pattern: element.pattern))
            }
            return LabeledExprSyntax(
                label: element.label,
                colon: element.label == nil ? nil : .colonToken(),
                expression: expression,
                trailingComma: index == elements.count - 1 ? nil : .commaToken()
            )
        }
        return PatternSyntax(ExpressionPatternSyntax(expression: ExprSyntax(TupleExprSyntax(
            leftParen: .leftParenToken(),
            elements: LabeledExprListSyntax(args),
            rightParen: .rightParenToken()
        ))))
    }

    private mutating func collectTupleMatchElements(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [TuplePatternElementSyntax]) {
        let list = NTSpan(nt: nt, from: from, to: to)
        for elNT in collectListElements(named: "tupleMatchElement", in: list, recursiveListName: "tupleMatchElementList") {
            guard let (_, eSpans) = tileAlternate(elNT.nt, from: elNT.from, to: elNT.to),
                  let mpNT = find("matchPattern", in: eSpans) else {
                record(.lookupFailed, "tuple match element without pattern", from: elNT.from, to: elNT.to)
                continue
            }
            let label = find("softIdentifier", in: eSpans)
            elements.append(TuplePatternElementSyntax(
                label: label.map { .identifier(collectTerminalText($0.nt, from: $0.from, to: $0.to)) },
                colon: label == nil ? nil : .colonToken(),
                pattern: convertMatchPattern(mpNT.nt, from: mpNT.from, to: mpNT.to)
            ))
        }
    }

    /// enumCasePattern = typeIdentifier? "." enumCaseName tupleMatchPattern? | enumCaseName tupleMatchPattern .
    ///
    /// swift-syntax has no EnumCasePattern node — `.a(x)` is an ExpressionPattern wrapping a
    /// FunctionCallExpr over a MemberAccessExpr, with the associated-value PATTERNS carried as
    /// `PatternExpr` arguments.
    private mutating func convertEnumCasePattern(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> PatternSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingPattern(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        guard let nameNT = find("enumCaseName", in: spans) else {
            return missingPattern(.lookupFailed, "no enumCaseName child", from: from, to: to)
        }
        let name = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
        var base: ExprSyntax? = nil
        if let tiNT = find("typeIdentifier", in: spans) {
            base = ExprSyntax(DeclReferenceExprSyntax(
                baseName: .identifier(collectTerminalText(tiNT.nt, from: tiNT.from, to: tiNT.to))
            ))
        }
        var callee: ExprSyntax = ExprSyntax(MemberAccessExprSyntax(
            base: base, period: .periodToken(),
            declName: DeclReferenceExprSyntax(baseName: .identifier(name))
        ))
        // `enumCaseName tupleMatchPattern` (no leading dot) is a bare reference, not a member.
        if base == nil && !String(input[from..<to]).hasPrefix(".") {
            callee = ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
        }
        guard let tupNT = find("tupleMatchPattern", in: spans) else {
            return PatternSyntax(ExpressionPatternSyntax(expression: callee))
        }
        // The associated values are PATTERNS carried as call arguments.
        var elements: [TuplePatternElementSyntax] = []
        if let (_, tSpans) = tileAlternate(tupNT.nt, from: tupNT.from, to: tupNT.to),
           let listNT = find("tupleMatchElementList", in: tSpans) {
            collectTupleMatchElements(listNT.nt, from: listNT.from, to: listNT.to, into: &elements)
        }
        let args = elements.enumerated().map { index, element in
            LabeledExprSyntax(
                label: element.label,
                colon: element.label == nil ? nil : .colonToken(),
                expression: ExprSyntax(PatternExprSyntax(pattern: element.pattern)),
                trailingComma: index == elements.count - 1 ? nil : .commaToken()
            )
        }
        return PatternSyntax(ExpressionPatternSyntax(expression: ExprSyntax(FunctionCallExprSyntax(
            calledExpression: callee,
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(args),
            rightParen: .rightParenToken()
        ))))
    }

    /// conditionList = condition { "," condition } .
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
        let list = NTSpan(nt: nt, from: from, to: to)
        for cNT in collectListElements(named: "condition", in: list, recursiveListName: "conditionList") {
            guard let (_, cSpans) = tileAlternate(cNT.nt, from: cNT.from, to: cNT.to) else {
                record(.lookupFailed, "no alternate tiles condition span", from: cNT.from, to: cNT.to)
                continue
            }
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
            } else if let ccNT = find("caseCondition", in: cSpans),
                      let (_, ccSpans) = tileAlternate(ccNT.nt, from: ccNT.from, to: ccNT.to) {
                // caseCondition = "case" matchPattern initializer .
                var pattern: PatternSyntax = PatternSyntax(MissingPatternSyntax())
                if let mpNT = find("matchPattern", in: ccSpans) {
                    pattern = convertMatchPattern(mpNT.nt, from: mpNT.from, to: mpNT.to)
                }
                var initializer = InitializerClauseSyntax(equal: .equalToken(), value: MissingExprSyntax())
                if let iNT = find("initializer", in: ccSpans),
                   let converted = convertInitializer(iNT.nt, from: iNT.from, to: iNT.to) {
                    initializer = converted
                }
                items.append(ConditionElementSyntax(condition: .matchingPattern(
                    MatchingPatternConditionSyntax(
                        caseKeyword: .keyword(.case), pattern: pattern, initializer: initializer
                    )
                )))
            } else if let acNT = find("availabilityCondition", in: cSpans) {
                items.append(ConditionElementSyntax(condition: .availability(
                    convertAvailabilityCondition(acNT.nt, from: acNT.from, to: acNT.to)
                )))
            } else {
                record(.unhandled, "condition kind has no converter: \(alternateKind(cSpans))", from: cNT.from, to: cNT.to)
            }
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
            collectAvailabilityArguments(listNT.nt, from: listNT.from, to: listNT.to,
                                         bareIsVersionRestriction: true, into: &args)
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
            // `if let _ = x` — in OPTIONAL-BINDING position swift-syntax spells the underscore as
            // an ExpressionPattern over a DiscardAssignmentExpr, not as a WildcardPattern (which
            // is what it uses in match position). Same spelling, different node by context.
            if pattern.is(WildcardPatternSyntax.self) {
                pattern = PatternSyntax(ExpressionPatternSyntax(
                    expression: DiscardAssignmentExprSyntax(wildcard: .wildcardToken())
                ))
            }
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
        // forInStatement = "for" "try"? "await"? "unsafe"? … — ForStmt carries each as its own
        // optional token, so they must be threaded through rather than merely noted.
        let tryKeyword: TokenSyntax? = spansContainKeyword(spans, "try") ? .keyword(.try) : nil
        let awaitKeyword: TokenSyntax? = spansContainKeyword(spans, "await") ? .keyword(.await) : nil
        let unsafeKeyword: TokenSyntax? = spansContainKeyword(spans, "unsafe") ? .keyword(.unsafe) : nil
        let caseKeyword: TokenSyntax? = spansContainKeyword(spans, "case") ? .keyword(.case) : nil

        var pattern: PatternSyntax = PatternSyntax(MissingPatternSyntax())
        var typeAnnotation: TypeAnnotationSyntax? = nil
        if let mpNT = find("matchPattern", in: spans) {
            pattern = convertMatchPattern(mpNT.nt, from: mpNT.from, to: mpNT.to)
        } else if let bpNT = find("bindingPattern", in: spans) {
            // for-in binds, so a bare identifier is an IdentifierPattern here. `bindingPattern`
            // also carries the optional annotation of `for x: Int in …`, which ForStmt keeps as
            // its own child — discarding it dropped the annotation from the tree.
            (pattern, typeAnnotation) = convertBindingPattern(bpNT.nt, from: bpNT.from, to: bpNT.to)
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
            tryKeyword: tryKeyword,
            awaitKeyword: awaitKeyword,
            unsafeKeyword: unsafeKeyword,
            caseKeyword: caseKeyword,
            pattern: pattern,
            typeAnnotation: typeAnnotation,
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
        let throwsClause = throwsClauseSyntax(in: spans)
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
        let list = NTSpan(nt: nt, from: from, to: to)
        for cpNT in collectListElements(named: "catchPattern", in: list, recursiveListName: "catchPatternList") {
            guard let (_, cpSpans) = tileAlternate(cpNT.nt, from: cpNT.from, to: cpNT.to) else {
                record(.lookupFailed, "no alternate tiles catch pattern span", from: cpNT.from, to: cpNT.to)
                continue
            }
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
        // deinitializerDeclaration = attributes? declarationModifiers? "deinit" "async"? codeBlock? .
        // The `async` that FOLLOWS `deinit` is an effect specifier; an `async` BEFORE it is a
        // declaration modifier and already in `modifiers`. `spansContainKeyword` cannot tell them
        // apart, so `async deinit {}` was emitting both.
        let deinitKeyword = spans.first { sym, f, t in
            var text = ""
            return f < t && sym.kind.isTerminal && tiledText(sym, from: f, to: t, into: &text) && text == "deinit"
        }
        let asyncAfterDeinit = spans.contains { sym, f, t in
            guard let deinitSpan = deinitKeyword, f >= deinitSpan.2, f < t else { return false }
            var text = ""
            return (sym.kind.isTerminal || sym.kind == .OPT)
                && tiledText(sym, from: f, to: t, into: &text) && text == "async"
        }
        if asyncAfterDeinit {
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
        // A trailing `where` clause is its own child on every declaration that admits one.
        var genericWhereClause: GenericWhereClauseSyntax? = nil
        if let wcNT = find("genericWhereClause", in: spans) {
            genericWhereClause = convertGenericWhereClause(wcNT.nt, from: wcNT.from, to: wcNT.to)
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
            genericWhereClause: genericWhereClause,
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
            var items: [CodeBlockItemSyntax] = []
            if let stmtsNT = find("statements", in: cbSpans) {
                items = convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to)
            }
            return AccessorBlockSyntax(
                leftBrace: .leftBraceToken(),
                accessors: .getter(CodeBlockItemListSyntax(items)),
                rightBrace: .rightBraceToken()
            )
        }
        record(.lookupFailed, "getterSetterBlock with neither brace nor codeBlock", from: from, to: to)
        return AccessorBlockSyntax(accessors: .getter([]))
    }

    /// accessorClauseList  = accessorClauseEntry accessorClauseList? .
    /// initializedAccessorBlock — the accessor block that may follow an initializer
    /// (`var x: T = v { init(nv) {} get {} set {} }`). Its three list shapes all hold ordinary
    /// accessor clauses, so they funnel into the same collector.
    private mutating func convertInitializedAccessorBlock(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition
    ) -> AccessorBlockSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        // The brace-wrapped form defers to the shared block converter.
        if find("accessorBlockBrace", in: spans) != nil {
            return convertGetterSetterBlock(nt, from: from, to: to)
        }
        var accessors: [AccessorDeclSyntax] = []
        // `"{" initAccessorClause accessorClauseList? "}"` — the leading `init` accessor is a
        // SIBLING of the list, so it has to be collected before it.
        if find("initAccessorClause", in: spans) != nil {
            appendAccessorEntry(spans, into: &accessors)
        }
        for rule in ["accessorClauseListNoInit", "accessorClauseList"] {
            if let listNT = find(rule, in: spans) {
                collectAccessorClauses(listNT.nt, from: listNT.from, to: listNT.to, into: &accessors)
            }
        }
        if accessors.isEmpty {
            // The shorthand `{ statements }` getter form.
            if let cbNT = find("codeBlock", in: spans) {
                return convertGetterSetterBlock(nt, from: from, to: to)
            }
            record(.unhandled, "initialized accessor block with no accessors", from: from, to: to)
            return nil
        }
        return AccessorBlockSyntax(
            leftBrace: .leftBraceToken(),
            accessors: .accessors(AccessorDeclListSyntax(accessors)),
            rightBrace: .rightBraceToken()
        )
    }

    /// willSetDidSetBlock = "{" willSetClause didSetClause? "}" | "{" didSetClause willSetClause? "}" .
    /// willSetClause      = attributes? "willSet" setterName? accessorEffects? codeBlock .
    /// didSetClause       = attributes? "didSet" setterName? accessorEffects? codeBlock .
    ///
    /// swift-syntax has no separate observer node: these are ordinary `AccessorDecl`s in an
    /// `AccessorBlock`, distinguished only by the specifier keyword.
    private mutating func convertWillSetDidSetBlock(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition
    ) -> AccessorBlockSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        var accessors: [AccessorDeclSyntax] = []
        // Source order matters, and either clause may come first, so walk the spans rather than
        // looking the two rules up in a fixed order.
        for (sym, f, t) in spans where f < t {
            for (rule, keyword) in [("willSetClause", Keyword.willSet), ("didSetClause", Keyword.didSet)] {
                guard let clauseNT = findNonterminal(named: rule, sym: sym, from: f, to: t),
                      let (_, cSpans) = tileAlternate(clauseNT.nt, from: clauseNT.from, to: clauseNT.to)
                else { continue }
                var parameters: AccessorParametersSyntax? = nil
                if let snNT = find("setterName", in: cSpans),
                   let (_, snSpans) = tileAlternate(snNT.nt, from: snNT.from, to: snNT.to),
                   let idNT = find("hardIdentifier", in: snSpans) {
                    parameters = AccessorParametersSyntax(
                        name: .identifier(collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to))
                    )
                }
                var body: CodeBlockSyntax? = nil
                if let cbNT = find("codeBlock", in: cSpans) {
                    body = convertCodeBlock(cbNT.nt, from: cbNT.from, to: cbNT.to)
                }
                accessors.append(AccessorDeclSyntax(
                    attributes: attributeList(in: cSpans),
                    accessorSpecifier: .keyword(keyword),
                    parameters: parameters,
                    body: body
                ))
            }
        }
        return AccessorBlockSyntax(
            leftBrace: .leftBraceToken(),
            accessors: .accessors(AccessorDeclListSyntax(accessors)),
            rightBrace: .rightBraceToken()
        )
    }

    /// accessorClauseEntry = getterClause | setterClause | initAccessorClause | coroutineAccessorClause .
    /// getterClause        = attributes? accessorModifier? "get" accessorEffects? codeBlock? .
    /// setterClause        = attributes? accessorModifier? "set" setterName? accessorEffects? codeBlock? .
    private mutating func collectAccessorClauses(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into accessors: inout [AccessorDeclSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        // A bare `initAccessorClause` may also arrive WITHOUT an enclosing entry — the
        // `"{" initAccessorClause accessorClauseList? "}"` shape of `initializedAccessorBlock`
        // makes it a sibling of the list rather than an entry in it.
        if find("accessorClauseEntry", in: spans) == nil,
           find("initAccessorClause", in: spans) != nil {
            appendAccessorEntry(spans, into: &accessors)
            return
        }
        if let entryNT = find("accessorClauseEntry", in: spans),
           let (_, eSpans) = tileAlternate(entryNT.nt, from: entryNT.from, to: entryNT.to) {
            appendAccessorEntry(eSpans, into: &accessors)
        }
        if let restNT = find("accessorClauseList", in: spans) {
            collectAccessorClauses(restNT.nt, from: restNT.from, to: restNT.to, into: &accessors)
        }
        if let restNT = find("accessorClauseListNoInit", in: spans) {
            collectAccessorClauses(restNT.nt, from: restNT.from, to: restNT.to, into: &accessors)
        }
    }

    /// One accessor clause, given the spans that CONTAIN it (an `accessorClauseEntry`'s body, or
    /// an `initializedAccessorBlock`'s own spans for the sibling `init` form).
    private mutating func appendAccessorEntry(
        _ eSpans: [(GrammarNode, CharPosition, CharPosition)], into accessors: inout [AccessorDeclSyntax]
    ) {
        do {
            // initAccessorClause = attributes? "init" setterName? accessorEffects? codeBlock .
            // The SAME child names as getter/setter (minus `accessorModifier`), so it belongs in
            // this branch rather than in one of its own — only the specifier keyword differs.
            if let clauseNT = find(firstOf: ["getterClause", "setterClause", "initAccessorClause"], in: eSpans),
               let (_, cSpans) = tileAlternate(clauseNT.nt, from: clauseNT.from, to: clauseNT.to) {
                let specifier: TokenSyntax
                switch clauseNT.nt.name {
                case "getterClause": specifier = .keyword(.get)
                case "setterClause": specifier = .keyword(.set)
                default:             specifier = .keyword(.`init`)
                }
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
                    accessorSpecifier: specifier,
                    parameters: parameters,
                    effectSpecifiers: effects,
                    body: body
                ))
            } else if let coNT = find("coroutineAccessorClause", in: eSpans),
                      let (_, cSpans) = tileAlternate(coNT.nt, from: coNT.from, to: coNT.to),
                      let specNT = find("coroutineSpecifier", in: cSpans) {
                // coroutineAccessorClause = attributes? accessorModifier? coroutineSpecifier
                //                           accessorEffects? codeBlock .   (SE-0443)
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
                let specText = collectTerminalText(specNT.nt, from: specNT.from, to: specNT.to)
                guard let specifier = coroutineSpecifierToken(specText) else {
                    record(.unhandled, "experimental coroutine accessor '\(specText)' not converted",
                           from: coNT.from, to: coNT.to)
                    return
                }
                accessors.append(AccessorDeclSyntax(
                    attributes: attributes,
                    modifier: modifier,
                    accessorSpecifier: specifier,
                    effectSpecifiers: effects,
                    body: body
                ))
            } else {
                record(.unhandled, "accessor kind has no converter: \(alternateKind(eSpans))", from: eSpans.first?.1 ?? input.startIndex, to: eSpans.last?.2 ?? input.startIndex)
            }
        }
    }

    /// coroutineSpecifier = "_read" | "read" | "_modify" | "modify" | "borrow" | "mutate" .
    /// A fourth distinct keyword set — see the note on `typeSpecifierToken`.
    ///
    /// `read` and `modify` (the modern SE-0443 spellings) are `@_spi` in swift-syntax, gated
    /// behind experimental features (as is `mutate`) — the same gating the grammar comment on `coroutineSpecifier`
    /// records. They are therefore not emittable here, and swift-syntax would not produce them by
    /// default either, so those two return nil and the caller records the gap.
    private func coroutineSpecifierToken(_ name: String) -> TokenSyntax? {
        switch name {
        case "_read":   return .keyword(._read)
        case "_modify": return .keyword(._modify)
        case "borrow":  return .keyword(.borrow)
        default:        return nil
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
        if let ccNT = find("conditionalCompilationAttributes", in: spans) {
            // AttributeList admits an `.ifConfigDecl` element directly, so a `#if` around
            // attributes is a PEER of the attributes rather than a wrapper.
            if let decl = convertConditionalCompilationAttributes(ccNT.nt, from: ccNT.from, to: ccNT.to) {
                items.append(.ifConfigDecl(decl))
            }
        } else if let attrNT = find("attribute", in: spans) {
            if let attribute = convertAttribute(attrNT.nt, from: attrNT.from, to: attrNT.to) {
                items.append(.attribute(attribute))
            }
        }
        if let restNT = find("attributes", in: spans) {
            collectAttributes(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    /// derivativeName      = derivativeNameChain | derivativeNameChain >s< "(" argumentNames? ")" .
    /// derivativeNameChain = derivativeNameAtom | derivativeNameChain "." derivativeNameAtom .
    /// derivativeNameAtom  = moduleSelector? hardIdentifier | moduleSelector? selfType | operator .
    private mutating func derivativeName(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition
    ) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let chainNT = find("derivativeNameChain", in: spans) else {
            return missingExpr(.lookupFailed, "no derivativeNameChain child", from: from, to: to)
        }
        var expr = derivativeNameChain(chainNT.nt, from: chainNT.from, to: chainNT.to)
        // A trailing `(labels)` belongs to the NAME, so it lands on the innermost reference.
        if let namesNT = find("argumentNames", in: spans) {
            var arguments: [DeclNameArgumentSyntax] = []
            collectDeclNameArguments(namesNT.nt, from: namesNT.from, to: namesNT.to, into: &arguments)
            let declArgs = DeclNameArgumentsSyntax(arguments: DeclNameArgumentListSyntax(arguments))
            if let member = expr.as(MemberAccessExprSyntax.self) {
                expr = ExprSyntax(member.with(\.declName, member.declName.with(\.argumentNames, declArgs)))
            } else if let ref = expr.as(DeclReferenceExprSyntax.self) {
                expr = ExprSyntax(ref.with(\.argumentNames, declArgs))
            }
        } else if spansContainKeyword(spans, "(") {
            // `of: baz()` — empty parens still produce a (childless) DeclNameArguments.
            let declArgs = DeclNameArgumentsSyntax(arguments: DeclNameArgumentListSyntax([]))
            if let member = expr.as(MemberAccessExprSyntax.self) {
                expr = ExprSyntax(member.with(\.declName, member.declName.with(\.argumentNames, declArgs)))
            } else if let ref = expr.as(DeclReferenceExprSyntax.self) {
                expr = ExprSyntax(ref.with(\.argumentNames, declArgs))
            }
        }
        return expr
    }

    /// The chain is LEFT-recursive, so the recursive child IS the base — the same shape as
    /// `typeIdentifier`, and it maps straight onto swift-syntax's left-nesting MemberAccessExpr.
    private mutating func derivativeNameChain(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition
    ) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        // `Float.-` — the `.` and the operator arrive as ONE `dotOperator` token, so strip the
        // leading dot to recover the member name.
        if let dotNT = findTerminal(named: "dotOperator", in: spans),
           let baseNT = find("derivativeNameChain", in: spans) {
            let text = collectTerminalText(dotNT.nt, from: dotNT.from, to: dotNT.to)
            return ExprSyntax(MemberAccessExprSyntax(
                // The qualifier is a TYPE here too (`of: Float.-`), as for a named member.
                base: ExprSyntax(TypeExprSyntax(type: derivativeNameType(baseNT))),
                period: .periodToken(),
                declName: DeclReferenceExprSyntax(baseName: .binaryOperator(String(text.dropFirst())))
            ))
        }
        guard let atomNT = find("derivativeNameAtom", in: spans),
              let (_, atomSpans) = tileAlternate(atomNT.nt, from: atomNT.from, to: atomNT.to) else {
            return missingExpr(.lookupFailed, "no derivativeNameAtom child", from: from, to: to)
        }
        let text = collectTerminalText(atomNT.nt, from: atomNT.from, to: atomNT.to)
        let selector = moduleSelector(in: atomSpans)
        // The atom may BE an operator (`of: -`), which needs the operator token kind.
        var name = text
        if let sel = selector, let cut = text.range(of: "::") {
            _ = sel
            name = String(text[cut.upperBound...])
        }
        let reference = DeclReferenceExprSyntax(
            moduleSelector: selector,
            baseName: functionNameToken(name)
        )
        if let baseNT = find("derivativeNameChain", in: spans) {
            // The QUALIFIER of a derivative name is a TYPE, not an expression: `of: S.method`
            // gives `TypeExpr(IdentifierType(S))` and `of: Foo.Self.other` gives
            // `TypeExpr(MemberType(…))`. (The operator-member path above is the exception — there
            // the base stays an expression, which is why it is handled separately.)
            let base = ExprSyntax(TypeExprSyntax(type: derivativeNameType(baseNT)))
            return ExprSyntax(MemberAccessExprSyntax(
                base: base,
                period: .periodToken(),
                declName: reference
            ))
        }
        return ExprSyntax(reference)
    }

    /// The same LEFT-recursive chain read as a TYPE — `Foo.Self` is `MemberType(IdentifierType(Foo), Self)`.
    private mutating func derivativeNameType(_ span: NTSpan) -> TypeSyntax {
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to),
              let atomNT = find("derivativeNameAtom", in: spans) else {
            return missingType(.lookupFailed, "no derivativeNameAtom child", from: span.from, to: span.to)
        }
        // `derivativeNameAtom = moduleSelector? hardIdentifier | …` — read the two parts, since
        // the atom's raw TEXT would be `Swift::Foo` and the selector is its own node.
        guard let (_, atomSpans) = tileAlternate(atomNT.nt, from: atomNT.from, to: atomNT.to) else {
            return missingType(.lookupFailed, "no alternate tiles the span", from: span.from, to: span.to)
        }
        let selector = moduleSelector(in: atomSpans)
        var text = collectTerminalText(atomNT.nt, from: atomNT.from, to: atomNT.to)
        if let cut = text.range(of: "::") { text = String(text[cut.upperBound...]) }
        // `Self` is `keyword(Self)` only as a LEADING IdentifierType; as a MemberType's name
        // (`Foo.Self`) it is a plain identifier.
        if let baseNT = find("derivativeNameChain", in: spans) {
            return TypeSyntax(MemberTypeSyntax(
                baseType: derivativeNameType(baseNT), period: .periodToken(),
                moduleSelector: selector,
                name: .identifier(text)
            ))
        }
        return TypeSyntax(IdentifierTypeSyntax(
            moduleSelector: selector,
            name: text == "Self" ? .keyword(.Self) : .identifier(text)
        ))
    }

    /// differentiableWrt = "wrt" ":" differentiabilityArgument | "wrt" ":" "(" differentiabilityArgumentList ")" .
    private mutating func differentiabilityWithRespectTo(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition
    ) -> DifferentiabilityWithRespectToArgumentSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        if let listNT = find("differentiabilityArgumentList", in: spans) {
            var items: [DifferentiabilityArgumentSyntax] = []
            collectDifferentiabilityArguments(listNT.nt, from: listNT.from, to: listNT.to, into: &items)
            for i in items.indices.dropLast() {
                items[i] = items[i].with(\.trailingComma, .commaToken())
            }
            return DifferentiabilityWithRespectToArgumentSyntax(
                arguments: .argumentList(DifferentiabilityArgumentsSyntax(
                    arguments: DifferentiabilityArgumentListSyntax(items)
                ))
            )
        }
        if let oneNT = find("differentiabilityArgument", in: spans) {
            return DifferentiabilityWithRespectToArgumentSyntax(
                arguments: .argument(differentiabilityArgument(oneNT))
            )
        }
        record(.lookupFailed, "wrt clause with no argument", from: from, to: to)
        return nil
    }

    /// lifetimeArguments = lifetimeArgument | lifetimeArgument "," lifetimeArguments .
    /// lifetimeArgument  = lifetimeTarget | hardIdentifier ":" lifetimeTarget .
    /// lifetimeTarget    = hardIdentifier | "borrow" hardIdentifier | "copy" hardIdentifier | "&" >s< hardIdentifier .
    private mutating func collectLifetimeArguments(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [LabeledExprSyntax]
    ) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let argNT = find("lifetimeArgument", in: spans),
           let (_, argSpans) = tileAlternate(argNT.nt, from: argNT.from, to: argNT.to),
           let targetNT = find("lifetimeTarget", in: argSpans),
           let (_, tSpans) = tileAlternate(targetNT.nt, from: targetNT.from, to: targetNT.to),
           let nameNT = find("hardIdentifier", in: tSpans) {
            let reference = ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(
                collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
            )))
            var value = reference
            if spansContainKeyword(tSpans, "borrow") {
                value = ExprSyntax(BorrowExprSyntax(borrowKeyword: .keyword(.borrow), expression: reference))
            } else if spansContainKeyword(tSpans, "copy") {
                value = ExprSyntax(CopyExprSyntax(copyKeyword: .keyword(.copy), expression: reference))
            } else if spansContainKeyword(tSpans, "&") {
                value = ExprSyntax(InOutExprSyntax(expression: reference))
            }
            // The LABEL is the `hardIdentifier` of the ARGUMENT, one level above the target's.
            let label = find("hardIdentifier", in: argSpans)
            let isLabel = label.map { $0.from < targetNT.from } ?? false
            items.append(LabeledExprSyntax(
                label: isLabel ? .identifier(collectTerminalText(label!.nt, from: label!.from, to: label!.to)) : nil,
                colon: isLabel ? .colonToken() : nil,
                expression: value
            ))
        }
        if let restNT = find("lifetimeArguments", in: spans) {
            collectLifetimeArguments(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    /// backDeployedPlatforms = backDeployedPlatform | backDeployedPlatform "," backDeployedPlatforms .
    /// backDeployedPlatform  = platformName platformVersion? .
    private mutating func collectBackDeployedPlatforms(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [PlatformVersionItemSyntax]
    ) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let oneNT = find("backDeployedPlatform", in: spans),
           let (_, oneSpans) = tileAlternate(oneNT.nt, from: oneNT.from, to: oneNT.to),
           let nameNT = find("platformName", in: oneSpans) {
            var version: VersionTupleSyntax? = nil
            if let verNT = find("platformVersion", in: oneSpans) {
                version = versionTuple(verNT)
            }
            items.append(PlatformVersionItemSyntax(platformVersion: PlatformVersionSyntax(
                platform: .identifier(collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)),
                version: version
            )))
        }
        if let restNT = find("backDeployedPlatforms", in: spans) {
            collectBackDeployedPlatforms(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    /// differentiabilityArgument = hardIdentifier | selfType | decimalDigits .
    private mutating func differentiabilityArgument(_ span: NTSpan) -> DifferentiabilityArgumentSyntax {
        let text = collectTerminalText(span.nt, from: span.from, to: span.to)
        // `wrt: self` and `wrt: 0` are both legal; the token KIND follows the spelling.
        if text == "self" { return DifferentiabilityArgumentSyntax(argument: .keyword(.self)) }
        if !text.isEmpty, text.allSatisfy(\.isNumber) {
            return DifferentiabilityArgumentSyntax(argument: .integerLiteral(text))
        }
        return DifferentiabilityArgumentSyntax(argument: .identifier(text))
    }

    /// differentiabilityArgumentList = differentiabilityArgument { "," differentiabilityArgument } .
    private mutating func collectDifferentiabilityArguments(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [DifferentiabilityArgumentSyntax]
    ) {
        let list = NTSpan(nt: nt, from: from, to: to)
        for oneNT in collectListElements(named: "differentiabilityArgument", in: list, recursiveListName: "differentiabilityArgumentList") {
            items.append(differentiabilityArgument(oneNT))
        }
    }

    /// genericWhereClause     = "where" requirementList .
    /// requirementList        = requirement | requirement "," requirementList .
    /// requirement            = conformanceRequirement | sameTypeRequirement .
    /// conformanceRequirement = typeIdentifier ":" "~"? ( typeIdentifier | protocolCompositionType ) .
    /// sameTypeRequirement    = typeIdentifier "==" ( type | signedIntegerLiteral ) .
    private mutating func convertGenericWhereClause(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition
    ) -> GenericWhereClauseSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let listNT = find("requirementList", in: spans) else {
            record(.lookupFailed, "no requirementList child", from: from, to: to)
            return nil
        }
        var requirements: [GenericRequirementSyntax] = []
        collectGenericRequirements(listNT.nt, from: listNT.from, to: listNT.to, into: &requirements)
        for i in requirements.indices.dropLast() {
            requirements[i] = requirements[i].with(\.trailingComma, .commaToken())
        }
        return GenericWhereClauseSyntax(
            whereKeyword: .keyword(.where),
            requirements: GenericRequirementListSyntax(requirements)
        )
    }

    private mutating func collectGenericRequirements(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into requirements: inout [GenericRequirementSyntax]
    ) {
        let list = NTSpan(nt: nt, from: from, to: to)
        for reqNT in collectListElements(named: "requirement", in: list, recursiveListName: "requirementList") {
            guard let (_, reqSpans) = tileAlternate(reqNT.nt, from: reqNT.from, to: reqNT.to) else {
                record(.lookupFailed, "no alternate tiles the span", from: reqNT.from, to: reqNT.to)
                continue
            }
            if let confNT = find("conformanceRequirement", in: reqSpans),
               let (_, cSpans) = tileAlternate(confNT.nt, from: confNT.from, to: confNT.to) {
                // BOTH sides are `typeIdentifier` in one alternate, so walk the spans in order —
                // calling `find` twice would return the same (first) one.
                var types: [TypeSyntax] = []
                for (sym, f, t) in cSpans where f < t {
                    if let idNT = findNonterminal(named: "typeIdentifier", sym: sym, from: f, to: t) {
                        types.append(convertTypeIdentifier(idNT.nt, from: idNT.from, to: idNT.to))
                    } else if let pcNT = findNonterminal(named: "protocolCompositionType", sym: sym, from: f, to: t) {
                        var elements: [CompositionTypeElementSyntax] = []
                        collectCompositionElements(pcNT.nt, from: pcNT.from, to: pcNT.to, into: &elements)
                        for i in elements.indices.dropLast() {
                            elements[i] = elements[i].with(\.ampersand, .binaryOperator("&"))
                        }
                        types.append(TypeSyntax(CompositionTypeSyntax(
                            elements: CompositionTypeElementListSyntax(elements)
                        )))
                    }
                }
                guard types.count == 2 else {
                    record(.lookupFailed, "conformance requirement without two types",
                           from: confNT.from, to: confNT.to)
                    continue
                }
                var right = types[1]
                if spansContainKeyword(cSpans, "~") {
                    right = TypeSyntax(SuppressedTypeSyntax(
                        withoutTilde: .prefixOperator("~"), type: right
                    ))
                }
                requirements.append(GenericRequirementSyntax(
                    requirement: .conformanceRequirement(ConformanceRequirementSyntax(
                        leftType: types[0], colon: .colonToken(), rightType: right
                    ))
                ))
            } else if let stNT = find("sameTypeRequirement", in: reqSpans),
                      let (_, sSpans) = tileAlternate(stNT.nt, from: stNT.from, to: stNT.to),
                      let leftNT = find("typeIdentifier", in: sSpans) {
                let left = convertTypeIdentifier(leftNT.nt, from: leftNT.from, to: leftNT.to)
                // Each side is a CHOICE of type or expression — which is exactly why `T == 3`
                // (SE-0453 InlineArray) has somewhere to go: the literal is an EXPRESSION here,
                // not a type spelled with digits.
                var right: SameTypeRequirementSyntax.RightType = .type(TypeSyntax(MissingTypeSyntax()))
                if let typeNT = find("type", in: sSpans) {
                    right = .type(convertType(typeNT.nt, from: typeNT.from, to: typeNT.to))
                } else if let litNT = find("signedIntegerLiteral", in: sSpans) {
                    right = .expr(ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral(
                        collectTerminalText(litNT.nt, from: litNT.from, to: litNT.to)))))
                }
                requirements.append(GenericRequirementSyntax(
                    requirement: .sameTypeRequirement(SameTypeRequirementSyntax(
                        leftType: .type(left), equal: .binaryOperator("=="), rightType: right
                    ))
                ))
            } else {
                record(.unhandled, "requirement form has no converter: \(alternateKind(reqSpans))",
                       from: reqNT.from, to: reqNT.to)
            }
        }
    }

    /// macroRoleArguments = macroRoleArgument | macroRoleArgument "," macroRoleArguments .
    /// macroRoleArgument  = macroRoleName | hardIdentifier ":" macroRoleName .
    private mutating func collectMacroRoleArguments(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [LabeledExprSyntax]
    ) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let argNT = find("macroRoleArgument", in: spans),
           let (_, argSpans) = tileAlternate(argNT.nt, from: argNT.from, to: argNT.to),
           let nameNT = find("macroRoleName", in: argSpans) {
            let label = find("hardIdentifier", in: argSpans)
            items.append(LabeledExprSyntax(
                label: label.map { .identifier(collectTerminalText($0.nt, from: $0.from, to: $0.to)) },
                colon: label == nil ? nil : .colonToken(),
                expression: macroRoleName(nameNT.nt, from: nameNT.from, to: nameNT.to)
            ))
        }
        if let restNT = find("macroRoleArguments", in: spans) {
            collectMacroRoleArguments(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    /// macroRoleName = macroRoleDeclName
    ///               | macroRoleDeclName >s< "(" macroRoleName ")"
    ///               | macroRoleDeclName >s< "(" argumentNames ")" .
    ///
    /// `named(deinit)` is a CALL of the reference `named`; `init(a:b:)` is one reference carrying
    /// `DeclNameArguments`. Note the token kinds: in this position `init`/`deinit`/`subscript` are
    /// KEYWORDS, unlike member position where swift-syntax keeps `deinit` and `subscript` as
    /// identifiers — so this needs its own mapping rather than `declNameToken`.
    private mutating func macroRoleName(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let declNT = find("macroRoleDeclName", in: spans) else {
            return missingExpr(.lookupFailed, "no macroRoleDeclName child", from: from, to: to)
        }
        let text = collectTerminalText(declNT.nt, from: declNT.from, to: declNT.to)
        let base: TokenSyntax
        switch text {
        case "init":      base = .keyword(.`init`)
        case "deinit":    base = .keyword(.`deinit`)
        case "subscript": base = .keyword(.subscript)
        case "self":      base = .keyword(.self)
        case "Self":      base = .keyword(.Self)
        default:          base = .identifier(text)
        }
        // `init(a:b:)` — the labels belong to the NAME, not to a call.
        if let namesNT = find("argumentNames", in: spans) {
            var arguments: [DeclNameArgumentSyntax] = []
            collectDeclNameArguments(namesNT.nt, from: namesNT.from, to: namesNT.to, into: &arguments)
            return ExprSyntax(DeclReferenceExprSyntax(
                moduleSelector: moduleSelector(in: spans),
                baseName: base,
                argumentNames: DeclNameArgumentsSyntax(
                    arguments: DeclNameArgumentListSyntax(arguments)
                )
            ))
        }
        // `named(x)` — a call whose single argument is the nested name.
        if let innerNT = find("macroRoleName", in: spans) {
            return ExprSyntax(FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(
                    moduleSelector: moduleSelector(in: spans), baseName: base
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax([
                    LabeledExprSyntax(expression: macroRoleName(innerNT.nt, from: innerNT.from, to: innerNT.to))
                ]),
                rightParen: .rightParenToken()
            ))
        }
        return ExprSyntax(DeclReferenceExprSyntax(
            moduleSelector: moduleSelector(in: spans), baseName: base
        ))
    }

    /// argumentNames = argumentName argumentNames? .   argumentName = softIdentifier ":" .
    private mutating func collectDeclNameArguments(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into arguments: inout [DeclNameArgumentSyntax]
    ) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let oneNT = find("argumentName", in: spans),
           let (_, oneSpans) = tileAlternate(oneNT.nt, from: oneNT.from, to: oneNT.to),
           let idNT = find("softIdentifier", in: oneSpans) {
            arguments.append(DeclNameArgumentSyntax(
                name: .identifier(collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)),
                colon: .colonToken()
            ))
        }
        if let restNT = find("argumentNames", in: spans) {
            collectDeclNameArguments(restNT.nt, from: restNT.from, to: restNT.to, into: &arguments)
        }
    }

    /// conventionArguments = conventionArgument | conventionArgument "," conventionArguments .
    /// conventionArgument  = hardIdentifier | hardIdentifier ":" staticStringLiteral .
    private mutating func collectConventionArguments(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into items: inout [LabeledExprSyntax]
    ) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let argNT = find("conventionArgument", in: spans),
           let (_, argSpans) = tileAlternate(argNT.nt, from: argNT.from, to: argNT.to),
           let idNT = find("hardIdentifier", in: argSpans) {
            // `find` returns the first match in span order, so this is the LABEL when the
            // argument is labelled and the whole argument when it is not.
            let name = collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)
            if let valueNT = find("conventionValue", in: argSpans),
               let (_, valueSpans) = tileAlternate(valueNT.nt, from: valueNT.from, to: valueNT.to) {
                let value: ExprSyntax
                if let strNT = find("staticStringLiteral", in: valueSpans) {
                    value = convertStringLiteral(strNT.nt, from: strNT.from, to: strNT.to)
                } else {
                    value = ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(
                        collectTerminalText(valueNT.nt, from: valueNT.from, to: valueNT.to))))
                }
                items.append(LabeledExprSyntax(
                    label: .identifier(name), colon: .colonToken(), expression: value
                ))
            } else {
                items.append(LabeledExprSyntax(
                    expression: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
                ))
            }
        }
        if let restNT = find("conventionArguments", in: spans) {
            collectConventionArguments(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
        }
    }

    /// objcSelector       = identifier | objcSelectorPieces .
    /// objcSelectorPieces = objcSelectorPiece objcSelectorPieces? .
    /// objcSelectorPiece  = identifier? ":" .
    ///
    /// A zero-argument selector is one piece carrying only a name; every other piece carries a
    /// colon and MAY carry a name, so `:::x::` is five pieces.
    private mutating func collectObjCSelectorPieces(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into pieces: inout [ObjCSelectorPieceSyntax]
    ) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let listNT = find("objcSelectorPieces", in: spans) {
            var cursor: NTSpan? = listNT
            while let level = cursor {
                guard let (_, levelSpans) = tileAlternate(level.nt, from: level.from, to: level.to) else {
                    record(.lookupFailed, "no alternate tiles the span", from: level.from, to: level.to)
                    return
                }
                if let pieceNT = find("objcSelectorPiece", in: levelSpans),
                   let (_, pieceSpans) = tileAlternate(pieceNT.nt, from: pieceNT.from, to: pieceNT.to) {
                    var name: TokenSyntax? = nil
                    if let idNT = findTerminal(named: "identifier", in: pieceSpans) {
                        name = .identifier(collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to))
                    }
                    pieces.append(ObjCSelectorPieceSyntax(name: name, colon: .colonToken()))
                }
                cursor = find("objcSelectorPieces", in: levelSpans)
            }
            return
        }
        if let idNT = findTerminal(named: "identifier", in: spans) {
            pieces.append(ObjCSelectorPieceSyntax(
                name: .identifier(collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to))
            ))
            return
        }
        record(.lookupFailed, "objcSelector with neither an identifier nor pieces", from: from, to: to)
    }

    /// conditionalCompilationAttributes = ifDirectiveAttributes elseifDirectiveAttributes? elseDirectiveAttributes? endifDirective .
    /// ifDirectiveAttributes     = ifDirective compilationCondition attributes? .
    /// elseifDirectiveAttributes = elseifDirective compilationCondition attributes? .
    /// elseDirectiveAttributes   = elseDirective attributes? .
    private mutating func convertConditionalCompilationAttributes(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition
    ) -> IfConfigDeclSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        var clauses: [IfConfigClauseSyntax] = []
        if let ifNT = find("ifDirectiveAttributes", in: spans) {
            appendAttributeIfConfigClause(ifNT, keyword: .poundIfToken(), withCondition: true, into: &clauses)
        } else {
            record(.lookupFailed, "no ifDirectiveAttributes child", from: from, to: to)
        }
        if let elseifNT = find("elseifDirectiveAttributes", in: spans) {
            appendAttributeIfConfigClause(elseifNT, keyword: .poundElseifToken(), withCondition: true, into: &clauses)
        }
        if let elseNT = find("elseDirectiveAttributes", in: spans) {
            appendAttributeIfConfigClause(elseNT, keyword: .poundElseToken(), withCondition: false, into: &clauses)
        }
        return IfConfigDeclSyntax(
            clauses: IfConfigClauseListSyntax(clauses),
            poundEndif: .poundEndifToken()
        )
    }

    private mutating func appendAttributeIfConfigClause(
        _ span: NTSpan, keyword: TokenSyntax, withCondition: Bool, into clauses: inout [IfConfigClauseSyntax]
    ) {
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to) else {
            record(.lookupFailed, "no alternate tiles the span", from: span.from, to: span.to)
            return
        }
        var condition: ExprSyntax? = nil
        if withCondition {
            if let condNT = find("compilationCondition", in: spans) {
                var elements: [ExprSyntax] = []
                flattenCompilationCondition(condNT.nt, from: condNT.from, to: condNT.to, into: &elements)
                condition = elements.count == 1
                    ? elements[0]
                    : ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(elements)))
            } else {
                record(.lookupFailed, "directive clause without a condition", from: span.from, to: span.to)
            }
        }
        var attributes = AttributeListSyntax([])
        if let attrNT = find("attributes", in: spans) {
            attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
        }
        clauses.append(IfConfigClauseSyntax(
            poundKeyword: keyword,
            condition: condition,
            elements: .attributes(attributes)
        ))
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
        // attribute = "@" >s< "abi" >s< "(" abiDeclaration ")" .
        // The argument is a whole DECLARATION, which we already convert, so this one needs no
        // bespoke argument grammar — just re-wrap the result. `Provider` is the subset of decl
        // kinds swift-syntax accepts here; anything else stays unhandled rather than guessed.
        if let abiNT = find("abiDeclaration", in: spans) {
            // `abiDeclaration` admits BODYLESS forms that `declaration` does not
            // (`abiSubscriptDeclaration`, `abiVariableDeclaration`, `bodylessInitializerDeclaration`),
            // so fall back to the member-only reader before giving up.
            var converted = convertDeclaration(abiNT.nt, from: abiNT.from, to: abiNT.to)
            if converted == nil, let (_, abiSpans) = tileAlternate(abiNT.nt, from: abiNT.from, to: abiNT.to) {
                converted = memberOnlyDeclaration(abiSpans, from: abiNT.from, to: abiNT.to)
                if converted == nil, let subNT = find("abiSubscriptDeclaration", in: abiSpans) {
                    converted = DeclSyntax(convertSubscriptDeclaration(subNT.nt, from: subNT.from, to: subNT.to))
                }
                if converted == nil, let varNT = find("abiVariableDeclaration", in: abiSpans) {
                    converted = DeclSyntax(convertVarLetDecl(varNT.nt, from: varNT.from, to: varNT.to, isLet: false))
                }
            }
            guard let decl = converted,
                  let provider = ABIAttributeArgumentsSyntax.Provider(decl)
            else {
                record(.unhandled, "@abi argument declaration not converted", from: from, to: to)
                return nil
            }
            return AttributeSyntax(
                atSign: .atSignToken(),
                attributeName: TypeSyntax(IdentifierTypeSyntax(name: .identifier("abi"))),
                leftParen: .leftParenToken(),
                arguments: .abiArguments(ABIAttributeArgumentsSyntax(provider: provider)),
                rightParen: .rightParenToken()
            )
        }
        // attribute = "@" >s< "convention" >s< "(" conventionArguments ")" .
        // The name is spelled as a LITERAL in this alternate, so there is no `attributeName` child
        // to read it from — hence the explicit token.
        if spansContainKeyword(spans, "convention"), let argsNT = find("conventionArguments", in: spans) {
            var items: [LabeledExprSyntax] = []
            collectConventionArguments(argsNT.nt, from: argsNT.from, to: argsNT.to, into: &items)
            for i in items.indices.dropLast() {
                items[i] = items[i].with(\.trailingComma, .commaToken())
            }
            return AttributeSyntax(
                atSign: .atSignToken(),
                attributeName: TypeSyntax(IdentifierTypeSyntax(name: .identifier("convention"))),
                leftParen: .leftParenToken(),
                arguments: .argumentList(LabeledExprListSyntax(items)),
                rightParen: .rightParenToken()
            )
        }
        // attribute = "@" >s< "attached"     >s< "(" macroRoleArguments? ")" .
        // attribute = "@" >s< "freestanding" >s< "(" macroRoleArguments? ")" .
        // Plain `.argumentList`, like `@convention` — no dedicated macro-role node exists.
        for role in ["attached", "freestanding"] where spansContainKeyword(spans, role) {
            var items: [LabeledExprSyntax] = []
            if let argsNT = find("macroRoleArguments", in: spans) {
                collectMacroRoleArguments(argsNT.nt, from: argsNT.from, to: argsNT.to, into: &items)
                for i in items.indices.dropLast() {
                    items[i] = items[i].with(\.trailingComma, .commaToken())
                }
            }
            return AttributeSyntax(
                atSign: .atSignToken(),
                attributeName: TypeSyntax(IdentifierTypeSyntax(name: .identifier(role))),
                leftParen: .leftParenToken(),
                arguments: .argumentList(LabeledExprListSyntax(items)),
                rightParen: .rightParenToken()
            )
        }
        // attribute = "@" >s< ( "derivative" | "transpose" ) >s< "(" "of" ":" derivativeName [ "," differentiableWrt ] ")" .
        for kind in ["derivative", "transpose"] where spansContainKeyword(spans, kind) {
            guard let nameNT = find("derivativeName", in: spans) else {
                record(.lookupFailed, "no derivativeName child", from: from, to: to)
                return nil
            }
            var wrt: DifferentiabilityWithRespectToArgumentSyntax? = nil
            if let wrtNT = find("differentiableWrt", in: spans) {
                wrt = differentiabilityWithRespectTo(wrtNT.nt, from: wrtNT.from, to: wrtNT.to)
            }
            return AttributeSyntax(
                atSign: .atSignToken(),
                attributeName: TypeSyntax(IdentifierTypeSyntax(name: .identifier(kind))),
                leftParen: .leftParenToken(),
                arguments: .derivativeRegistrationArguments(DerivativeAttributeArgumentsSyntax(
                    ofLabel: .keyword(.of),
                    colon: .colonToken(),
                    originalDeclName: derivativeName(nameNT.nt, from: nameNT.from, to: nameNT.to),
                    comma: wrt == nil ? nil : .commaToken(),
                    arguments: wrt
                )),
                rightParen: .rightParenToken()
            )
        }
        // attribute = "@" >s< "lifetime" >s< "(" lifetimeArguments ")" .
        if spansContainKeyword(spans, "lifetime"),
           let argsNT = find("lifetimeArguments", in: spans) {
            var items: [LabeledExprSyntax] = []
            collectLifetimeArguments(argsNT.nt, from: argsNT.from, to: argsNT.to, into: &items)
            for i in items.indices.dropLast() {
                items[i] = items[i].with(\.trailingComma, .commaToken())
            }
            return AttributeSyntax(
                atSign: .atSignToken(),
                attributeName: TypeSyntax(IdentifierTypeSyntax(name: .identifier("lifetime"))),
                leftParen: .leftParenToken(),
                arguments: .argumentList(LabeledExprListSyntax(items)),
                rightParen: .rightParenToken()
            )
        }
        // attribute = "@" >s< "backDeployed" >s< "(" "before" ":" backDeployedPlatforms ")" .
        if spansContainKeyword(spans, "backDeployed"),
           let listNT = find("backDeployedPlatforms", in: spans) {
            var items: [PlatformVersionItemSyntax] = []
            collectBackDeployedPlatforms(listNT.nt, from: listNT.from, to: listNT.to, into: &items)
            for i in items.indices.dropLast() {
                items[i] = items[i].with(\.trailingComma, .commaToken())
            }
            return AttributeSyntax(
                atSign: .atSignToken(),
                attributeName: TypeSyntax(IdentifierTypeSyntax(name: .identifier("backDeployed"))),
                leftParen: .leftParenToken(),
                arguments: .backDeployedArguments(BackDeployedAttributeArgumentsSyntax(
                    beforeLabel: .keyword(.before),
                    colon: .colonToken(),
                    platforms: PlatformVersionItemListSyntax(items)
                )),
                rightParen: .rightParenToken()
            )
        }
        // attribute = "@" >s< "differentiable" >s< "(" differentiableArguments ")" .
        if spansContainKeyword(spans, "differentiable"),
           let argsNT = find("differentiableArguments", in: spans),
           let (_, aSpans) = tileAlternate(argsNT.nt, from: argsNT.from, to: argsNT.to) {
            var kind: TokenSyntax? = nil
            if let kindNT = find("differentiableKind", in: aSpans) {
                kind = .keyword(.reverse)
                let text = collectTerminalText(kindNT.nt, from: kindNT.from, to: kindNT.to)
                if text != "reverse" { kind = .identifier(text) }
            }
            var wrt: DifferentiabilityWithRespectToArgumentSyntax? = nil
            if let wrtNT = find("differentiableWrt", in: aSpans),
               let (_, wSpans) = tileAlternate(wrtNT.nt, from: wrtNT.from, to: wrtNT.to) {
                if let listNT = find("differentiabilityArgumentList", in: wSpans) {
                    var items: [DifferentiabilityArgumentSyntax] = []
                    collectDifferentiabilityArguments(listNT.nt, from: listNT.from, to: listNT.to, into: &items)
                    for i in items.indices.dropLast() {
                        items[i] = items[i].with(\.trailingComma, .commaToken())
                    }
                    wrt = DifferentiabilityWithRespectToArgumentSyntax(
                        arguments: .argumentList(DifferentiabilityArgumentsSyntax(
                            arguments: DifferentiabilityArgumentListSyntax(items)
                        ))
                    )
                } else if let oneNT = find("differentiabilityArgument", in: wSpans) {
                    wrt = DifferentiabilityWithRespectToArgumentSyntax(
                        arguments: .argument(differentiabilityArgument(oneNT))
                    )
                }
            }
            var whereClause: GenericWhereClauseSyntax? = nil
            if let wcNT = find("genericWhereClause", in: aSpans) {
                whereClause = convertGenericWhereClause(wcNT.nt, from: wcNT.from, to: wcNT.to)
            }
            return AttributeSyntax(
                atSign: .atSignToken(),
                attributeName: TypeSyntax(IdentifierTypeSyntax(name: .identifier("differentiable"))),
                leftParen: .leftParenToken(),
                arguments: .differentiableArguments(DifferentiableAttributeArgumentsSyntax(
                    kindSpecifier: kind,
                    kindSpecifierComma: (kind != nil && wrt != nil) ? .commaToken() : nil,
                    arguments: wrt,
                    genericWhereClause: whereClause
                )),
                rightParen: .rightParenToken()
            )
        }
        // attribute = "@" >s< "specialized" >s< "(" genericWhereClause ")" .
        if spansContainKeyword(spans, "specialized"),
           let wcNT = find("genericWhereClause", in: spans),
           let whereClause = convertGenericWhereClause(wcNT.nt, from: wcNT.from, to: wcNT.to) {
            return AttributeSyntax(
                atSign: .atSignToken(),
                attributeName: TypeSyntax(IdentifierTypeSyntax(name: .identifier("specialized"))),
                leftParen: .leftParenToken(),
                arguments: .specializedArguments(SpecializedAttributeArgumentSyntax(
                    genericWhereClause: whereClause
                )),
                rightParen: .rightParenToken()
            )
        }
        // attribute = "@" >s< "isolated" >s< "(" identifier ")" .
        // swift-syntax has no dedicated node for it either — a plain LabeledExprList, as for
        // `@convention`. The grammar already gives the argument structure; only this was missing.
        if spansContainKeyword(spans, "isolated"), let idNT = findTerminal(named: "identifier", in: spans) {
            let name = collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)
            return AttributeSyntax(
                atSign: .atSignToken(),
                attributeName: TypeSyntax(IdentifierTypeSyntax(name: .identifier("isolated"))),
                leftParen: .leftParenToken(),
                arguments: .argumentList(LabeledExprListSyntax([
                    LabeledExprSyntax(expression: ExprSyntax(
                        DeclReferenceExprSyntax(baseName: .identifier(name))
                    ))
                ])),
                rightParen: .rightParenToken()
            )
        }
        // attribute = "@" >s< "objc" >s< "(" objcSelector ")" .   attribute = "@" >s< "objc" .
        if spansContainKeyword(spans, "objc") {
            var pieces: [ObjCSelectorPieceSyntax] = []
            let selector = find("objcSelector", in: spans)
            if let selector {
                collectObjCSelectorPieces(selector.nt, from: selector.from, to: selector.to, into: &pieces)
            }
            return AttributeSyntax(
                atSign: .atSignToken(),
                attributeName: TypeSyntax(IdentifierTypeSyntax(name: .identifier("objc"))),
                leftParen: selector == nil ? nil : .leftParenToken(),
                arguments: selector == nil ? nil : .objCName(ObjCSelectorPieceListSyntax(pieces)),
                rightParen: selector == nil ? nil : .rightParenToken()
            )
        }
        // Every OTHER argument form is still balanced-token soup at this level — see the note above.
        if find(firstOf: ["attributeArgumentClause", "attributeArgumentExprClause",
                          "macroRoleArguments"], in: spans) != nil {
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
        // attributeName = attributeHeadName typeGenericArgumentClause? "." typeIdentifier .
        // `@Foo.Bar` — swift-syntax's attribute NAME is a type, so this is a MemberType over the
        // head, exactly as a dotted type would be.
        if let tailNT = find("typeIdentifier", in: nameSpans),
           let headNT = find("attributeHeadName", in: nameSpans) {
            let headText = collectTerminalText(headNT.nt, from: headNT.from, to: headNT.to)
            var head: TypeSyntax = TypeSyntax(IdentifierTypeSyntax(
                name: headText == "Self" ? .keyword(.Self) : .identifier(headText)
            ))
            if let gNT = find("typeGenericArgumentClause", in: nameSpans) {
                head = TypeSyntax(IdentifierTypeSyntax(
                    name: headText == "Self" ? .keyword(.Self) : .identifier(headText),
                    genericArgumentClause: convertGenericArgumentClause(gNT.nt, from: gNT.from, to: gNT.to)
                ))
            }
            // The tail may itself be dotted; rebase its left-nesting onto our head.
            let tail = convertTypeIdentifier(tailNT.nt, from: tailNT.from, to: tailNT.to)
            var name: TypeSyntax
            if let member = tail.as(MemberTypeSyntax.self) {
                name = TypeSyntax(member.with(\.baseType, TypeSyntax(MemberTypeSyntax(
                    baseType: head, period: .periodToken(),
                    name: member.baseType.as(IdentifierTypeSyntax.self)?.name ?? .identifier("?")
                ))))
            } else if let ident = tail.as(IdentifierTypeSyntax.self) {
                name = TypeSyntax(MemberTypeSyntax(
                    baseType: head, period: .periodToken(),
                    name: ident.name, genericArgumentClause: ident.genericArgumentClause
                ))
            } else {
                record(.unhandled, "dot-qualified attribute name with an unexpected tail", from: from, to: to)
                return nil
            }
            return AttributeSyntax(atSign: .atSignToken(), attributeName: name)
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
            // `@Swift::Foo` (SE-0491) — the selector hangs off the attribute NAME's type, which is
            // why the name must not be taken as raw text (that produced `identifier "Swift::Foo"`).
            attributeName: IdentifierTypeSyntax(
                moduleSelector: moduleSelector(in: spans),
                name: .identifier(name),
                genericArgumentClause: generics
            )
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
            collectAvailabilityArguments(listNT.nt, from: listNT.from, to: listNT.to,
                                         bareIsVersionRestriction: false, into: &args)
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

    /// `bareIsVersionRestriction` splits the two callers apart. A platform with NO version is a
    /// `PlatformVersion` (with a nil version) in a `#available` CONDITION, but a plain `.token` in
    /// an `@available` ATTRIBUTE, where the same spelling introduces a labelled argument
    /// (`@available(macOS, introduced: …)`). The element shapes are otherwise identical, so one
    /// collector serves both.
    private mutating func collectAvailabilityArguments(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition,
        bareIsVersionRestriction: Bool, into args: inout [AvailabilityArgumentSyntax]
    ) {
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
                } else if bareIsVersionRestriction {
                    args.append(AvailabilityArgumentSyntax(argument: .availabilityVersionRestriction(
                        PlatformVersionSyntax(platform: .identifier(platform), version: nil)
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
            collectAvailabilityArguments(restNT.nt, from: restNT.from, to: restNT.to,
                                         bareIsVersionRestriction: bareIsVersionRestriction, into: &args)
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
            // The message may itself be MULTILINE (`message: \"\"\"…\"\"\"`), which needs the
            // multiline quote token and three characters trimmed from each end.
            let isMultiline = tookMultilineStringForm(span.nt, from: span.from, to: span.to) == true
            let quote: TokenSyntax = isMultiline ? .multilineStringQuoteToken() : .stringQuoteToken()
            let delimiter = isMultiline ? 3 : 1
            var content = String(text.dropFirst(delimiter).dropLast(delimiter))
            if isMultiline {
                // The opener's line break and the closer's indentation are delimiters, exactly as
                // in `convertStringLiteral`.
                if content.hasPrefix("\r\n") { content.removeFirst(2) }
                else if content.hasPrefix("\n") { content.removeFirst() }
                if let lastNewline = content.lastIndex(of: "\n") {
                    content = String(content[content.startIndex..<lastNewline])
                    if content.hasSuffix("\r") { content.removeLast() }
                }
                content = content.trimmingCharacters(in: .whitespaces)
            }
            return .string(SimpleStringLiteralExprSyntax(
                openingQuote: quote,
                segments: SimpleStringLiteralSegmentListSyntax([
                    StringSegmentSyntax(content: .stringSegment(content))
                ]),
                closingQuote: quote
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
        // SE-0470 trailing comma, kept on the LAST parameter.
        if hasTrailingComma(spans, afterList: "genericParameterList"), !params.isEmpty {
            params[params.count - 1] = params[params.count - 1].with(\.trailingComma, .commaToken())
        }
        return GenericParameterClauseSyntax(
            leftAngle: .leftAngleToken(),
            parameters: GenericParameterListSyntax(params),
            rightAngle: .rightAngleToken()
        )
    }

    private mutating func collectGenericParameters(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into params: inout [GenericParameterSyntax]) {
        let list = NTSpan(nt: nt, from: from, to: to)
        for gpNT in collectListElements(named: "genericParameter", in: list, recursiveListName: "genericParameterList") {
            guard let (_, gpSpans) = tileAlternate(gpNT.nt, from: gpNT.from, to: gpNT.to) else {
                record(.lookupFailed, "no alternate tiles the span", from: gpNT.from, to: gpNT.to)
                continue
            }
            var attributes = AttributeListSyntax([])
            if let attrNT = find("attributes", in: gpSpans) {
                attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
            }
            if spansContainKeyword(gpSpans, "let") {
                record(.unhandled, "value generic parameter (`let N: Int`) not converted", from: gpNT.from, to: gpNT.to)
            }
            guard let nameNT = find("typeName", in: gpSpans) else {
                record(.lookupFailed, "no typeName child", from: gpNT.from, to: gpNT.to)
                continue
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
            // `T: ~Copyable` (SE-0390) — the tilde wraps the CONSTRAINT, as in an inheritance clause.
            if inherited != nil, spansContainKeyword(gpSpans, "~") {
                inherited = TypeSyntax(SuppressedTypeSyntax(
                    withoutTilde: .prefixOperator("~"), type: inherited!
                ))
            }
            params.append(GenericParameterSyntax(
                attributes: attributes,
                name: .identifier(collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)),
                colon: inherited == nil ? nil : .colonToken(),
                inheritedType: inherited
            ))
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
        // parameterDeclarationModifiers = parameterDeclarationModifier parameterDeclarationModifiers? .
        // A PARALLEL rule with its own child names (`_const`, `isolated`), so looking only for
        // `declarationModifier` found nothing and the modifier vanished.
        if let modNT = find("parameterDeclarationModifier", in: spans) {
            items.append(DeclModifierSyntax(name: modifierToken(
                collectTerminalText(modNT.nt, from: modNT.from, to: modNT.to)
            )))
        }
        for rule in ["declarationModifiers", "parameterDeclarationModifiers"] {
            if let restNT = find(rule, in: spans) {
                collectDeclarationModifiers(restNT.nt, from: restNT.from, to: restNT.to, into: &items)
            }
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
        // `_const` is underscored but IS lexer-classified, unlike the SPI modifiers noted above.
        case "_const":       return .keyword(._const)
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

    /// importDeclaration = attributes? "import" importKind? importPath .
    /// importPath        = hardIdentifier | hardIdentifier "." importPath .
    /// importKind        = "typealias" | "struct" | "class" | "enum" | "protocol" | "let" | "var" | "func" .
    ///
    /// swift-syntax splits the dotted path into an `ImportPathComponentList`, each component
    /// carrying its own leading period except the first.
    private mutating func convertImportDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ImportDeclSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return ImportDeclSyntax(path: [])
        }
        var attributes = AttributeListSyntax([])
        if let attrNT = find("attributes", in: spans) {
            attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
        }
        // The SE-0491 alternate is `attributes? "import" importKind moduleSelector
        // ( hardIdentifier | operatorName )` — it has no `importPath` at all, so falling through
        // to that lookup would report an unconverted FORM as a failed lookup.

        // importKind = "typealias" | "struct" | "class" | "enum" | "protocol" | "let" | "var" | "func" .
        // Its own keyword set — only `class` overlaps the declaration modifiers, so reusing
        // `modifierToken` here left `struct`/`func`/… as plain identifiers.
        var importKind: TokenSyntax? = nil
        if let kindNT = find("importKind", in: spans) {
            let text = collectTerminalText(kindNT.nt, from: kindNT.from, to: kindNT.to)
            switch text {
            case "typealias": importKind = .keyword(.typealias)
            case "struct":    importKind = .keyword(.struct)
            case "class":     importKind = .keyword(.class)
            case "enum":      importKind = .keyword(.enum)
            case "protocol":  importKind = .keyword(.protocol)
            case "let":       importKind = .keyword(.let)
            case "var":       importKind = .keyword(.var)
            case "func":      importKind = .keyword(.func)
            default:
                record(.unhandled, "unrecognised import kind '\(text)'", from: kindNT.from, to: kindNT.to)
            }
        }
        var components: [ImportPathComponentSyntax] = []
        if let pathNT = find("importPath", in: spans) {
            collectImportPath(pathNT.nt, from: pathNT.from, to: pathNT.to, into: &components)
        } else if let msNT = find("moduleSelector", in: spans) {
            // importDeclaration = attributes? "import" importKind moduleSelector ( hardIdentifier | operatorName ) .
            // The SE-0491 alternate has NO `importPath`. `ImportPathComponent` carries no
            // `moduleSelector` of its own — swift-syntax spells `Module::A` as TWO components,
            // the first one's `trailingPeriod` holding the `::` token.
            if let (_, msSpans) = tileAlternate(msNT.nt, from: msNT.from, to: msNT.to),
               let modNT = find("hardIdentifier", in: msSpans) {
                components.append(ImportPathComponentSyntax(
                    name: .identifier(collectTerminalText(modNT.nt, from: modNT.from, to: modNT.to)),
                    trailingPeriod: .colonColonToken()
                ))
            }
            // The trailing name sits AFTER the selector, so pick the span that starts past it.
            var nameSpan = spans.compactMap { sym, f, t -> NTSpan? in
                guard f >= msNT.to, f < t else { return nil }
                return findNonterminal(named: "hardIdentifier", sym: sym, from: f, to: t)
            }.first
            if nameSpan == nil { nameSpan = findTerminal(named: "operatorName", in: spans) }
            guard let nameSpan else {
                record(.lookupFailed, "module-qualified import without a name", from: from, to: to)
                return ImportDeclSyntax(importKeyword: .keyword(.import), path: [])
            }
            components.append(ImportPathComponentSyntax(
                name: .identifier(collectTerminalText(nameSpan.nt, from: nameSpan.from, to: nameSpan.to))
            ))
        } else {
            record(.lookupFailed, "no importPath child", from: from, to: to)
        }
        return ImportDeclSyntax(
            attributes: attributes,
            importKeyword: .keyword(.import),
            importKindSpecifier: importKind,
            path: ImportPathComponentListSyntax(components)
        )
    }

    private mutating func collectImportPath(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into components: inout [ImportPathComponentSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        // swift-syntax hangs the dot off the component BEFORE it (`trailingPeriod`), so a
        // component gets one exactly when the right-recursive rule has a tail.
        let rest = find("importPath", in: spans)
        if let idNT = find("hardIdentifier", in: spans) {
            components.append(ImportPathComponentSyntax(
                name: .identifier(collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)),
                trailingPeriod: rest == nil ? nil : .periodToken()
            ))
        }
        if let rest {
            collectImportPath(rest.nt, from: rest.from, to: rest.to, into: &components)
        }
    }

    /// associatedTypeDeclaration = attributes? declarationModifiers? "associatedtype" typealiasName
    ///                             typeInheritanceClause? typealiasAssignment? genericWhereClause? .
    private mutating func convertAssociatedTypeDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> AssociatedTypeDeclSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return AssociatedTypeDeclSyntax(name: .identifier("?"))
        }
        var attributes = AttributeListSyntax([])
        if let attrNT = find("attributes", in: spans) {
            attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
        }
        var modifiers = DeclModifierListSyntax([])
        if let modsNT = find("declarationModifiers", in: spans) {
            modifiers = convertDeclarationModifiers(modsNT.nt, from: modsNT.from, to: modsNT.to)
        }
        var name = TokenSyntax.identifier("?")
        if let nameNT = find("typealiasName", in: spans) {
            name = .identifier(collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to))
        } else {
            record(.lookupFailed, "no typealiasName child", from: from, to: to)
        }
        var inheritance: InheritanceClauseSyntax? = nil
        if let inhNT = find("typeInheritanceClause", in: spans) {
            inheritance = convertInheritanceClause(inhNT.nt, from: inhNT.from, to: inhNT.to)
        }
        var initializer: TypeInitializerClauseSyntax? = nil
        if let asgNT = find("typealiasAssignment", in: spans),
           let (_, asgSpans) = tileAlternate(asgNT.nt, from: asgNT.from, to: asgNT.to),
           let typeNT = find("type", in: asgSpans) {
            initializer = TypeInitializerClauseSyntax(
                equal: .equalToken(), value: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
            )
        }
        // A trailing `where` clause is its own child on every declaration that admits one.
        var genericWhereClause: GenericWhereClauseSyntax? = nil
        if let wcNT = find("genericWhereClause", in: spans) {
            genericWhereClause = convertGenericWhereClause(wcNT.nt, from: wcNT.from, to: wcNT.to)
        }
        return AssociatedTypeDeclSyntax(
            attributes: attributes,
            modifiers: modifiers,
            associatedtypeKeyword: .keyword(.associatedtype),
            name: name,
            inheritanceClause: inheritance,
            initializer: initializer,
            genericWhereClause: genericWhereClause
        )
    }

    /// precedenceGroupDeclaration = "precedencegroup" precedenceGroupName "{" precedenceGroupAttributes? "}" .
    /// precedenceGroupAttribute   = precedenceGroupRelation | precedenceGroupAssignment | precedenceGroupAssociativity .
    private mutating func convertPrecedenceGroupDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> PrecedenceGroupDeclSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return PrecedenceGroupDeclSyntax(name: .identifier("?"), groupAttributes: [])
        }
        var name = TokenSyntax.identifier("?")
        if let nameNT = find("precedenceGroupName", in: spans) {
            name = .identifier(collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to))
        } else {
            record(.lookupFailed, "no precedenceGroupName child", from: from, to: to)
        }
        var attributes: [PrecedenceGroupAttributeListSyntax.Element] = []
        if let attrsNT = find("precedenceGroupAttributes", in: spans) {
            collectPrecedenceGroupAttributes(attrsNT.nt, from: attrsNT.from, to: attrsNT.to, into: &attributes)
        }
        return PrecedenceGroupDeclSyntax(
            precedencegroupKeyword: .keyword(.precedencegroup),
            name: name,
            leftBrace: .leftBraceToken(),
            groupAttributes: PrecedenceGroupAttributeListSyntax(attributes),
            rightBrace: .rightBraceToken()
        )
    }

    private mutating func collectPrecedenceGroupAttributes(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into attributes: inout [PrecedenceGroupAttributeListSyntax.Element]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let attrNT = find("precedenceGroupAttribute", in: spans),
           let (_, aSpans) = tileAlternate(attrNT.nt, from: attrNT.from, to: attrNT.to) {
            if let relNT = find("precedenceGroupRelation", in: aSpans),
               let (_, rSpans) = tileAlternate(relNT.nt, from: relNT.from, to: relNT.to) {
                let isHigher = spansContainKeyword(rSpans, "higherThan")
                var names: [PrecedenceGroupNameSyntax] = []
                if let namesNT = find("precedenceGroupNames", in: rSpans) {
                    collectPrecedenceGroupNames(namesNT.nt, from: namesNT.from, to: namesNT.to, into: &names)
                }
                if names.count > 1 {
                    for i in 0..<names.count - 1 {
                        names[i] = names[i].with(\.trailingComma, .commaToken())
                    }
                }
                attributes.append(.precedenceGroupRelation(PrecedenceGroupRelationSyntax(
                    higherThanOrLowerThanLabel: isHigher ? .keyword(.higherThan) : .keyword(.lowerThan),
                    colon: .colonToken(),
                    precedenceGroups: PrecedenceGroupNameListSyntax(names)
                )))
            } else if let asgNT = find("precedenceGroupAssignment", in: aSpans),
                      let (_, gSpans) = tileAlternate(asgNT.nt, from: asgNT.from, to: asgNT.to) {
                let value = find("booleanLiteral", in: gSpans).map {
                    collectTerminalText($0.nt, from: $0.from, to: $0.to)
                } ?? "false"
                attributes.append(.precedenceGroupAssignment(PrecedenceGroupAssignmentSyntax(
                    assignmentLabel: .keyword(.assignment),
                    colon: .colonToken(),
                    value: .keyword(value == "true" ? .true : .false)
                )))
            } else if let assocNT = find("precedenceGroupAssociativity", in: aSpans),
                      let (_, cSpans) = tileAlternate(assocNT.nt, from: assocNT.from, to: assocNT.to) {
                let value: TokenSyntax = spansContainKeyword(cSpans, "left") ? .keyword(.left)
                    : spansContainKeyword(cSpans, "right") ? .keyword(.right) : .keyword(.none)
                attributes.append(.precedenceGroupAssociativity(PrecedenceGroupAssociativitySyntax(
                    associativityLabel: .keyword(.associativity),
                    colon: .colonToken(),
                    value: value
                )))
            } else {
                record(.unhandled, "precedence group attribute has no converter: \(alternateKind(aSpans))", from: attrNT.from, to: attrNT.to)
            }
        }
        if let restNT = find("precedenceGroupAttributes", in: spans) {
            collectPrecedenceGroupAttributes(restNT.nt, from: restNT.from, to: restNT.to, into: &attributes)
        }
    }

    private mutating func collectPrecedenceGroupNames(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into names: inout [PrecedenceGroupNameSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let nameNT = find("precedenceGroupName", in: spans) {
            names.append(PrecedenceGroupNameSyntax(
                name: .identifier(collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to))
            ))
        }
        if let restNT = find("precedenceGroupNames", in: spans) {
            collectPrecedenceGroupNames(restNT.nt, from: restNT.from, to: restNT.to, into: &names)
        }
    }

    /// macroDeclaration     = macroDeclarationHead hardIdentifier genericParameterClause?
    ///                        macroSignature macroDefinition? genericWhereClause? .
    /// macroDeclarationHead = attributes? declarationModifiers? "macro" .
    /// macroSignature       = parameterClause macroFunctionSignatureResult? .
    /// macroDefinition      = assignmentOperator expression .
    private mutating func convertMacroDeclaration(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> MacroDeclSyntax {
        let emptyClause = FunctionParameterClauseSyntax(parameters: [])
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return MacroDeclSyntax(name: .identifier("?"), signature: FunctionSignatureSyntax(parameterClause: emptyClause))
        }
        var attributes = AttributeListSyntax([])
        var modifiers = DeclModifierListSyntax([])
        if let headNT = find("macroDeclarationHead", in: spans),
           let (_, hSpans) = tileAlternate(headNT.nt, from: headNT.from, to: headNT.to) {
            if let attrNT = find("attributes", in: hSpans) {
                attributes = convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
            }
            if let modsNT = find("declarationModifiers", in: hSpans) {
                modifiers = convertDeclarationModifiers(modsNT.nt, from: modsNT.from, to: modsNT.to)
            }
        }
        var name = TokenSyntax.identifier("?")
        if let nameNT = find("hardIdentifier", in: spans) {
            name = .identifier(collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to))
        } else {
            record(.lookupFailed, "no macro name child", from: from, to: to)
        }
        var generics: GenericParameterClauseSyntax? = nil
        if let gpNT = find("genericParameterClause", in: spans) {
            generics = convertGenericParameterClause(gpNT.nt, from: gpNT.from, to: gpNT.to)
        }
        var parameterClause = emptyClause
        var returnClause: ReturnClauseSyntax? = nil
        if let sigNT = find("macroSignature", in: spans),
           let (_, sSpans) = tileAlternate(sigNT.nt, from: sigNT.from, to: sigNT.to) {
            if let pcNT = find("parameterClause", in: sSpans) {
                parameterClause = convertParameterClause(pcNT.nt, from: pcNT.from, to: pcNT.to)
            }
            if let resNT = find("macroFunctionSignatureResult", in: sSpans),
               let (_, rSpans) = tileAlternate(resNT.nt, from: resNT.from, to: resNT.to),
               let typeNT = find("type", in: rSpans) {
                returnClause = ReturnClauseSyntax(
                    arrow: .arrowToken(), type: convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
                )
            }
        } else {
            record(.lookupFailed, "no macroSignature child", from: from, to: to)
        }
        var definition: InitializerClauseSyntax? = nil
        if let defNT = find("macroDefinition", in: spans),
           let (_, dSpans) = tileAlternate(defNT.nt, from: defNT.from, to: defNT.to),
           let exprNT = find("expression", in: dSpans) {
            definition = InitializerClauseSyntax(
                equal: .equalToken(),
                value: convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
            )
        }
        // A trailing `where` clause is its own child on every declaration that admits one.
        var genericWhereClause: GenericWhereClauseSyntax? = nil
        if let wcNT = find("genericWhereClause", in: spans) {
            genericWhereClause = convertGenericWhereClause(wcNT.nt, from: wcNT.from, to: wcNT.to)
        }
        return MacroDeclSyntax(
            attributes: attributes,
            modifiers: modifiers,
            macroKeyword: .keyword(.macro),
            name: name,
            genericParameterClause: generics,
            signature: FunctionSignatureSyntax(parameterClause: parameterClause, returnClause: returnClause),
            definition: definition,
            genericWhereClause: genericWhereClause
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
        var attributes = AttributeListSyntax([])
        var modifiers = DeclModifierListSyntax([])
        var optionalMark: TokenSyntax? = nil
        if let headNT = find("initializerHead", in: spans),
           let (_, headSpans) = tileAlternate(headNT.nt, from: headNT.from, to: headNT.to) {
            attributes = attributeList(in: headSpans)
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
        // A trailing `where` clause is its own child on every declaration that admits one.
        var genericWhereClause: GenericWhereClauseSyntax? = nil
        if let wcNT = find("genericWhereClause", in: spans) {
            genericWhereClause = convertGenericWhereClause(wcNT.nt, from: wcNT.from, to: wcNT.to)
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
        let throwsClause = throwsClauseSyntax(in: spans)
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
            attributes: attributes,
            modifiers: modifiers,
            initKeyword: .keyword(.`init`),
            optionalMark: optionalMark,
            signature: FunctionSignatureSyntax(
                parameterClause: parameterClause,
                effectSpecifiers: effects,
                returnClause: returnClause
            ),
            genericWhereClause: genericWhereClause,
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
            // designatedTypes = "," | "," designatedType designatedTypes? .
            // swift-syntax keeps them in `OperatorPrecedenceAndTypes.designatedTypes`; the
            // trailing-comma-only form contributes no entries.
            var designated: [DesignatedTypeSyntax] = []
            if let dtNT = find("designatedTypes", in: gSpans) {
                collectDesignatedTypes(dtNT.nt, from: dtNT.from, to: dtNT.to, into: &designated)
            }
            if let pgNT = find("precedenceGroupName", in: gSpans) {
                precedenceGroup = OperatorPrecedenceAndTypesSyntax(
                    colon: .colonToken(),
                    precedenceGroup: .identifier(collectTerminalText(pgNT.nt, from: pgNT.from, to: pgNT.to)),
                    designatedTypes: DesignatedTypeListSyntax(designated)
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

    private mutating func collectDesignatedTypes(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into types: inout [DesignatedTypeSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        // `designatedTypes = "," | "," designatedType designatedTypes?` — the bare-comma
        // alternate still produces an entry in swift-syntax, with an empty name.
        let name = find("designatedType", in: spans).map {
            collectTerminalText($0.nt, from: $0.from, to: $0.to)
        } ?? ""
        // `infix operator <*<<< : P, &` — a designated type may BE an operator, which needs the
        // operator token kind just as a function name does.
        types.append(DesignatedTypeSyntax(leadingComma: .commaToken(), name: functionNameToken(name)))
        if let restNT = find("designatedTypes", in: spans) {
            collectDesignatedTypes(restNT.nt, from: restNT.from, to: restNT.to, into: &types)
        }
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
            attributes: attributeList(in: spans),
            caseKeyword: .keyword(.case),
            elements: EnumCaseElementListSyntax(elements)
        )
    }

    private mutating func collectEnumCaseElements(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [EnumCaseElementSyntax]) {
        let list = NTSpan(nt: nt, from: from, to: to)
        for elNT in collectListElements(named: "enumCaseElement", in: list, recursiveListName: "enumCaseElementList") {
            guard let (_, elSpans) = tileAlternate(elNT.nt, from: elNT.from, to: elNT.to) else {
                record(.lookupFailed, "no alternate tiles enum case element span", from: elNT.from, to: elNT.to)
                continue
            }
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
        let list = NTSpan(nt: nt, from: from, to: to)
        for pNT in collectListElements(named: "enumCaseParameter", in: list, recursiveListName: "enumCaseParameterList") {
            guard let (_, pSpans) = tileAlternate(pNT.nt, from: pNT.from, to: pNT.to) else {
                record(.lookupFailed, "no alternate tiles enum case parameter span", from: pNT.from, to: pNT.to)
                continue
            }
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
                // A `_` label is a WILDCARD token, not an identifier named `_` — in either
                // position, and including the two-name form `case a(_ x: Int)`.
                if let ext, let local {
                    first = parameterNameToken(ext)
                    second = parameterNameToken(local)
                } else if let only = local ?? ext {
                    first = parameterNameToken(only)
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
        // A trailing `where` clause is its own child on every declaration that admits one.
        var genericWhereClause: GenericWhereClauseSyntax? = nil
        if let wcNT = find("genericWhereClause", in: spans) {
            genericWhereClause = convertGenericWhereClause(wcNT.nt, from: wcNT.from, to: wcNT.to)
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
            name: functionNameToken(name),
            genericParameterClause: genericParameterClause,
            signature: signature,
            genericWhereClause: genericWhereClause,
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
        let throwsClause = throwsClauseSyntax(in: spans)
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
        if hasTrailingComma(spans, afterList: "parameterList"), !params.isEmpty {
            params[params.count - 1] = params[params.count - 1].with(\.trailingComma, .commaToken())
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

        // parameterDeclarationModifiers = parameterDeclarationModifier parameterDeclarationModifiers? .
        var modifiers = DeclModifierListSyntax([])
        if let modsNT = find("parameterDeclarationModifiers", in: spans) {
            modifiers = convertDeclarationModifiers(modsNT.nt, from: modsNT.from, to: modsNT.to)
        }
        return FunctionParameterSyntax(
            attributes: attributeList(in: spans),
            modifiers: modifiers,
            firstName: firstName,
            secondName: secondName,
            colon: .colonToken(),
            type: type,
            // `parameter = … typeAnnotation "..."` — a variadic parameter's ellipsis follows the
            // TYPE, so it cannot be placed with the names.
            ellipsis: spansContainKeyword(spans, "...") ? .ellipsisToken() : nil,
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
        var items: [CodeBlockItemSyntax] = []
        if let stmtsNT = find("statements", in: spans) {
            items = convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to)
        }
        return CodeBlockSyntax(
            leftBrace: .leftBraceToken(),
            statements: CodeBlockItemListSyntax(items),
            rightBrace: .rightBraceToken()
        )
    }

    private mutating func convertPatternInitializerList(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> [PatternBindingSyntax] {
        var bindings: [PatternBindingSyntax] = []
        let list = NTSpan(nt: nt, from: from, to: to)
        for piNT in collectListElements(named: "patternInitializer", in: list, recursiveListName: "patternInitializerList") {
            bindings.append(convertPatternInitializer(piNT.nt, from: piNT.from, to: piNT.to))
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
            pattern = PatternSyntax(IdentifierPatternSyntax(identifier: identifierPatternToken(name)))
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
        let list = NTSpan(nt: nt, from: from, to: to)
        for elNT in collectListElements(named: "tupleBindingElement", in: list, recursiveListName: "tupleBindingElementList") {
            guard let (_, elSpans) = tileAlternate(elNT.nt, from: elNT.from, to: elNT.to),
                  let subNT = find("bindingSubpattern", in: elSpans) else {
                record(.lookupFailed, "tuple binding element without subpattern", from: elNT.from, to: elNT.to)
                continue
            }
            let label = find("softIdentifier", in: elSpans)
            elements.append(TuplePatternElementSyntax(
                label: label.map { .identifier(collectTerminalText($0.nt, from: $0.from, to: $0.to)) },
                colon: label == nil ? nil : .colonToken(),
                pattern: convertBindingSubpattern(subNT.nt, from: subNT.from, to: subNT.to)
            ))
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
            return PatternSyntax(IdentifierPatternSyntax(identifier: identifierPatternToken(name)))
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
            // `try if c { 1 } else { 2 }` — the `try`/`await` prefix applies to an if/switch
            // EXPRESSION exactly as to any other operand. This branch returned early without
            // them, so the wrapper was dropped and the bare IfExpr reached the caller (which then
            // wrapped it in an ExpressionStmt in statement position).
            var operand = convertConditionalExpression(condNT.nt, from: condNT.from, to: condNT.to)
            if find("awaitOperator", in: spans) != nil {
                operand = ExprSyntax(AwaitExprSyntax(awaitKeyword: .keyword(.await), expression: operand))
            }
            if let tryNT = find("tryOperator", in: spans) {
                let text = collectTerminalText(tryNT.nt, from: tryNT.from, to: tryNT.to)
                var mark: TokenSyntax? = nil
                if text.hasSuffix("?") { mark = .postfixQuestionMarkToken() }
                else if text.hasSuffix("!") { mark = .exclamationMarkToken() }
                operand = ExprSyntax(TryExprSyntax(
                    tryKeyword: .keyword(.try), questionOrExclamationMark: mark, expression: operand
                ))
            }
            elements.append(operand)
            // coercingOperator = "as" type | "as" >s< "?" type | "as" >s< "!" type — exactly the
            // `as` alternates of `typeCastingOperator`, so the same SPLICE applies:
            // `if c { 0 } else { 1 } as Int` is a flat SequenceExpr [IfExpr, UnresolvedAsExpr,
            // TypeExpr], not an if-expression wrapped in anything.
            if let coNT = find("coercingOperator", in: spans) {
                convertTypeCastingOperator(coNT.nt, from: coNT.from, to: coNT.to, into: &elements)
            }
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
        // infixExpression = >s< ( @cannotParse( regularExpressionLiteral ) postfixOperatorToken | dotOperator | "&" ) >s< tryOperator? awaitOperator? prefixExpression .
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
        //
        // The FIRST alternate spells its operator as `postfixOperatorToken | dotOperator | "&"`,
        // NONE of which is `infixOperator` — so `yield & 5` and `a ...b` silently lost the
        // operator element and the sequence collapsed by one term. `postfixOperatorToken` and
        // `dotOperator` are `-` TERMINALS, so they need `findTerminal`.
        var tightOperator = findTerminal(named: "postfixOperatorToken", in: spans)
        if tightOperator == nil { tightOperator = findTerminal(named: "dotOperator", in: spans) }
        if let opNT = find("infixOperator", in: spans) {
            let opText = collectTerminalText(opNT.nt, from: opNT.from, to: opNT.to)
            elements.append(ExprSyntax(BinaryOperatorExprSyntax(operator: .binaryOperator(opText))))
        } else if let opNT = tightOperator {
            let opText = collectTerminalText(opNT.nt, from: opNT.from, to: opNT.to)
            elements.append(ExprSyntax(BinaryOperatorExprSyntax(operator: .binaryOperator(opText))))
        } else if spansContainKeyword(spans, "&") {
            elements.append(ExprSyntax(BinaryOperatorExprSyntax(operator: .binaryOperator("&"))))
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
                effects = TypeEffectSpecifiersSyntax(
                    asyncSpecifier: isAsync ? .keyword(.async) : nil,
                    throwsClause: throwsClauseSyntax(in: teSpans)
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
            // `x += try foo()` — the operand may carry its own `try`/`await`, exactly as the
            // head operand does, and innermost-first: `try await x` is TryExpr(AwaitExpr(x)).
            var operand = convertPrefixExpression(prefNT.nt, from: prefNT.from, to: prefNT.to)
            if find("awaitOperator", in: spans) != nil {
                operand = ExprSyntax(AwaitExprSyntax(awaitKeyword: .keyword(.await), expression: operand))
            }
            if let tryNT = find("tryOperator", in: spans) {
                let text = collectTerminalText(tryNT.nt, from: tryNT.from, to: tryNT.to)
                var mark: TokenSyntax? = nil
                if text.hasSuffix("?") { mark = .postfixQuestionMarkToken() }
                else if text.hasSuffix("!") { mark = .exclamationMarkToken() }
                operand = ExprSyntax(TryExprSyntax(
                    tryKeyword: .keyword(.try), questionOrExclamationMark: mark, expression: operand
                ))
            }
            elements.append(operand)
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

        // inOutExpression = "&" >s< postfixExpression .
        if let ioNT = find("inOutExpression", in: spans),
           let (_, ioSpans) = tileAlternate(ioNT.nt, from: ioNT.from, to: ioNT.to),
           let innerNT = find("postfixExpression", in: ioSpans) {
            return ExprSyntax(InOutExprSyntax(
                ampersand: .prefixAmpersandToken(),
                expression: convertPostfixExpression(innerNT.nt, from: innerNT.from, to: innerNT.to)
            ))
        }
        // prefixExpression = @prefer ("consume"|"borrow"|"copy"|"unsafe") <s> >n< prefixExpression .
        // Each ownership operator has its OWN swift-syntax node — they are not PrefixOperatorExpr.
        if let innerNT = find("prefixExpression", in: spans) {
            let inner = convertPrefixExpression(innerNT.nt, from: innerNT.from, to: innerNT.to)
            if spansContainKeyword(spans, "consume") {
                return ExprSyntax(ConsumeExprSyntax(consumeKeyword: .keyword(.consume), expression: inner))
            }
            if spansContainKeyword(spans, "borrow") {
                return ExprSyntax(BorrowExprSyntax(borrowKeyword: .keyword(.borrow), expression: inner))
            }
            if spansContainKeyword(spans, "copy") {
                return ExprSyntax(CopyExprSyntax(copyKeyword: .keyword(.copy), expression: inner))
            }
            if spansContainKeyword(spans, "unsafe") {
                return ExprSyntax(UnsafeExprSyntax(unsafeKeyword: .keyword(.unsafe), expression: inner))
            }
            return missingExpr(.unhandled, "prefixExpression wrapper has no converter", from: from, to: to)
        }
        guard let postNT = find("postfixExpression", in: spans) else {
            return missingExpr(.unhandled, "prefixExpression without postfixExpression child", from: from, to: to)
        }
        let operand = convertPostfixExpression(postNT.nt, from: postNT.from, to: postNT.to)

        if let op = prefixOp {
            // `&x` is an INOUT argument, which swift-syntax models as InOutExpr rather than as a
            // prefix operator named `&`.
            if op == "&" {
                return ExprSyntax(InOutExprSyntax(expression: operand))
            }
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
        //                   | @prefer @cannotParse( keyPathExpression ) postfixExpression >s< postfixOperator <s> …
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
        // postfixExpression = postfixExpression >s< postfixOperator <s>
        //                   | postfixExpression >s< postfixOperatorToken >+> ( … )
        //                   | postfixExpression >s< dotOperator          >+> ( … ) .
        if let baseNT = find("postfixExpression", in: spans) {
            let base = convertPostfixExpression(baseNT.nt, from: baseNT.from, to: baseNT.to)
            if let opNT = find(firstOf: ["postfixOperator", "postfixOperatorToken", "dotOperator"], in: spans) {
                let opText = collectTerminalText(opNT.nt, from: opNT.from, to: opNT.to)
                return ExprSyntax(PostfixOperatorExprSyntax(
                    expression: base, operator: .postfixOperator(opText)
                ))
            }
            if let opText = findTerminal(named: "postfixOperatorToken", in: spans)
                ?? findTerminal(named: "dotOperator", in: spans) {
                let text = collectTerminalText(opText.nt, from: opText.from, to: opText.to)
                return ExprSyntax(PostfixOperatorExprSyntax(
                    expression: base, operator: .postfixOperator(text)
                ))
            }
        }
        // postfixExpression = initializerExpression .   initializerExpression = "init" >-> ( "{" ) .
        // A bare `init` reference — the delegating `init()` call inside an initializer.
        // swift-syntax spells the name with a KEYWORD token, exactly as in member position.
        if find("initializerExpression", in: spans) != nil {
            return ExprSyntax(DeclReferenceExprSyntax(baseName: .keyword(.`init`)))
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

    /// macroExpansionExpression = macroHead genericArgumentClause? functionCallArgumentClause? trailingClosures? .
    /// macroHead                = poundName ---( … ) | "#" >s< moduleSelector identifier ---( "_" ) .
    ///
    /// swift-syntax splits the `#name` head into a `pound` token plus a name token, so the
    /// leading `#` is stripped from the head's text here.
    /// The macro-expansion parts shared by `macroExpansionExpression` and
    /// `macroExpansionDeclaration`. The two rules have IDENTICAL children — head, generic
    /// arguments, call arguments, trailing closures — and differ only in the node they build and
    /// in the declaration form's attributes/modifiers, so reading them lives here once.
    ///
    /// Returns `nil` after recording why; `parens` says whether an argument clause was present,
    /// which swift-syntax distinguishes from an empty one.
    private mutating func macroExpansionParts(
        _ spans: [(GrammarNode, CharPosition, CharPosition)], from: CharPosition, to: CharPosition
    ) -> (name: String, selector: ModuleSelectorSyntax?, generics: GenericArgumentClauseSyntax?,
          parens: Bool, args: LabeledExprListSyntax, trailing: ClosureExprSyntax?,
          additional: MultipleTrailingClosureElementListSyntax)? {
        guard let headNT = find("macroHead", in: spans) else {
            record(.lookupFailed, "no macroHead child", from: from, to: to)
            return nil
        }
        let headText = collectTerminalText(headNT.nt, from: headNT.from, to: headNT.to)
        guard headText.hasPrefix("#") else {
            record(.unhandled, "macro head without a leading '#'", from: from, to: to)
            return nil
        }
        // macroHead = poundName ---( … ) | "#" >s< moduleSelector identifier ---( "_" ) .
        // `#Module::macro` (SE-0491): both MacroExpansionExpr and MacroExpansionDecl carry a
        // `moduleSelector`, so read it off the head instead of refusing the whole macro.
        var selector: ModuleSelectorSyntax? = nil
        var name = String(headText.dropFirst())
        if name.contains("::") {
            guard let (_, headSpans) = tileAlternate(headNT.nt, from: headNT.from, to: headNT.to),
                  let idNT = findTerminal(named: "identifier", in: headSpans) else {
                record(.lookupFailed, "module-qualified macro head without a name", from: from, to: to)
                return nil
            }
            selector = moduleSelector(in: headSpans)
            name = collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)
        }
        var generics: GenericArgumentClauseSyntax? = nil
        if let gcNT = find("genericArgumentClause", in: spans) {
            generics = convertGenericArgumentClause(gcNT.nt, from: gcNT.from, to: gcNT.to)
        }
        var trailing: ClosureExprSyntax? = nil
        var additional = MultipleTrailingClosureElementListSyntax([])
        if let tcNT = find("trailingClosures", in: spans),
           let (_, tcSpans) = tileAlternate(tcNT.nt, from: tcNT.from, to: tcNT.to) {
            if let closNT = find("closureExpression", in: tcSpans) {
                trailing = convertClosureExpression(closNT.nt, from: closNT.from, to: closNT.to)
            }
            if let labelledNT = find("labeledTrailingClosures", in: tcSpans) {
                var extra: [MultipleTrailingClosureElementSyntax] = []
                collectLabeledTrailingClosures(labelledNT.nt, from: labelledNT.from, to: labelledNT.to, into: &extra)
                additional = MultipleTrailingClosureElementListSyntax(extra)
            }
        }
        var args = LabeledExprListSyntax([])
        var parens = false
        if let clauseNT = find("functionCallArgumentClause", in: spans),
           let (_, clauseSpans) = tileAlternate(clauseNT.nt, from: clauseNT.from, to: clauseNT.to) {
            parens = true
            if let listNT = find("functionCallArgumentList", in: clauseSpans) {
                args = convertArgumentList(listNT.nt, from: listNT.from, to: listNT.to)
                // SE-0470 trailing comma, kept on the LAST argument.
                if hasTrailingComma(clauseSpans, afterList: "functionCallArgumentList"),
                   var last = args.last {
                    last.trailingComma = .commaToken()
                    args = LabeledExprListSyntax(args.dropLast() + [last])
                }
            }
        }
        return (name, selector, generics, parens, args, trailing, additional)
    }

    /// macroExpansionDeclaration = attributes declarationModifiers? macroHead genericArgumentClause? functionCallArgumentClause? trailingClosures? .
    /// macroExpansionDeclaration = declarationModifiers macroHead genericArgumentClause? functionCallArgumentClause? trailingClosures? .
    ///
    /// Both alternates REQUIRE an attribute or a modifier — a bare `#foo` at top level is a
    /// macro-expansion EXPRESSION instead, so it never reaches here.
    private mutating func convertMacroExpansionDeclaration(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition
    ) -> DeclSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        guard let parts = macroExpansionParts(spans, from: from, to: to) else { return nil }
        var modifiers = DeclModifierListSyntax([])
        if let modsNT = find("declarationModifiers", in: spans) {
            modifiers = convertDeclarationModifiers(modsNT.nt, from: modsNT.from, to: modsNT.to)
        }
        return DeclSyntax(MacroExpansionDeclSyntax(
            attributes: attributeList(in: spans),
            modifiers: modifiers,
            pound: .poundToken(),
            moduleSelector: parts.selector,
            macroName: .identifier(parts.name),
            genericArgumentClause: parts.generics,
            leftParen: parts.parens ? .leftParenToken() : nil,
            arguments: parts.args,
            rightParen: parts.parens ? .rightParenToken() : nil,
            trailingClosure: parts.trailing,
            additionalTrailingClosures: parts.additional
        ))
    }

    private mutating func convertMacroExpansionExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        guard let parts = macroExpansionParts(spans, from: from, to: to) else {
            return ExprSyntax(MissingExprSyntax())
        }
        return ExprSyntax(MacroExpansionExprSyntax(
            pound: .poundToken(),
            moduleSelector: parts.selector,
            macroName: .identifier(parts.name),
            genericArgumentClause: parts.generics,
            leftParen: parts.parens ? .leftParenToken() : nil,
            arguments: parts.args,
            rightParen: parts.parens ? .rightParenToken() : nil,
            trailingClosure: parts.trailing,
            additionalTrailingClosures: parts.additional
        ))
    }

    // MARK: - Conditional compilation

    /// conditionalCompilationBlock = ifDirectiveClause elseifDirectiveClauses? elseDirectiveClause? endifDirective .
    /// ifDirectiveClause     = "#if" compilationCondition >->( "." ) <n> statements? .
    /// elseifDirectiveClause = "#elseif" compilationCondition >->( "." ) <n> statements? .
    /// elseDirectiveClause   = "#else" >->( "." ) statements? .
    ///
    /// swift-syntax models this as a DECL (`IfConfigDecl`) even in statement position, with one
    /// `IfConfigClause` per directive.
    /// conditionalSwitchCase        = switchIfDirectiveClause switchElseifDirectiveClauses? switchElseDirectiveClause? endifDirective .
    /// switchIfDirectiveClause      = ifDirective compilationCondition switchCases? .
    /// switchElseifDirectiveClause  = elseifDirective compilationCondition switchCases? .
    /// switchElseDirectiveClause    = elseDirective switchCases? .
    private mutating func convertConditionalSwitchCase(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition
    ) -> IfConfigDeclSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return nil
        }
        var clauses: [IfConfigClauseSyntax] = []
        if let ifNT = find("switchIfDirectiveClause", in: spans) {
            appendSwitchIfConfigClause(ifNT, keyword: .poundIfToken(), withCondition: true, into: &clauses)
        } else {
            record(.lookupFailed, "no switchIfDirectiveClause child", from: from, to: to)
        }
        if let elseifNT = find("switchElseifDirectiveClauses", in: spans) {
            collectSwitchElseifClauses(elseifNT.nt, from: elseifNT.from, to: elseifNT.to, into: &clauses)
        }
        if let elseNT = find("switchElseDirectiveClause", in: spans) {
            appendSwitchIfConfigClause(elseNT, keyword: .poundElseToken(), withCondition: false, into: &clauses)
        }
        return IfConfigDeclSyntax(
            clauses: IfConfigClauseListSyntax(clauses),
            poundEndif: .poundEndifToken()
        )
    }

    private mutating func collectSwitchElseifClauses(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into clauses: inout [IfConfigClauseSyntax]
    ) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let cNT = find("switchElseifDirectiveClause", in: spans) {
            appendSwitchIfConfigClause(cNT, keyword: .poundElseifToken(), withCondition: true, into: &clauses)
        }
        if let restNT = find("switchElseifDirectiveClauses", in: spans) {
            collectSwitchElseifClauses(restNT.nt, from: restNT.from, to: restNT.to, into: &clauses)
        }
    }

    private mutating func appendSwitchIfConfigClause(
        _ span: NTSpan, keyword: TokenSyntax, withCondition: Bool, into clauses: inout [IfConfigClauseSyntax]
    ) {
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to) else {
            record(.lookupFailed, "no alternate tiles the span", from: span.from, to: span.to)
            return
        }
        var condition: ExprSyntax? = nil
        if withCondition {
            if let condNT = find("compilationCondition", in: spans) {
                var elements: [ExprSyntax] = []
                flattenCompilationCondition(condNT.nt, from: condNT.from, to: condNT.to, into: &elements)
                condition = elements.count == 1
                    ? elements[0]
                    : ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(elements)))
            } else {
                record(.lookupFailed, "directive clause without a condition", from: span.from, to: span.to)
            }
        }
        var cases: [SwitchCaseListSyntax.Element] = []
        if let casesNT = find("switchCases", in: spans) {
            collectSwitchCases(casesNT.nt, from: casesNT.from, to: casesNT.to, into: &cases)
        }
        clauses.append(IfConfigClauseSyntax(
            poundKeyword: keyword,
            condition: condition,
            elements: .switchCases(SwitchCaseListSyntax(cases))
        ))
    }

    /// postfixConditionalCompilationBlock = postfixIfDirectiveClause postfixElseifDirectiveClauses? postfixElseDirectiveClause? endifDirective .
    /// postfixIfDirectiveClause      = ifDirective compilationCondition <n> postfixIfBody? .
    /// postfixElseifDirectiveClause  = elseifDirective compilationCondition <n> postfixIfBody? .
    /// postfixElseDirectiveClause    = elseDirective postfixIfBody? .
    /// postfixIfBody                 = postfixExpression | postfixNestedBlocks .
    ///
    /// swift-syntax: `PostfixIfConfigExpr(base:config:)`. The BASE stays outside the directive and
    /// each clause carries a base-less continuation (`.methodOne()`) — which is what the
    /// implicit-member path already builds, so the body needs no special handling.
    /// `base` is nil for a NESTED block: `#if A / #if B / .m() / #endif / #endif` gives an outer
    /// PostfixIfConfigExpr over `baseExpr` whose clause element is a BASE-LESS
    /// PostfixIfConfigExpr holding the inner directive.
    private mutating func convertPostfixConditionalCompilation(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, base: ExprSyntax?
    ) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        var clauses: [IfConfigClauseSyntax] = []
        if let ifNT = find("postfixIfDirectiveClause", in: spans) {
            appendPostfixIfConfigClause(ifNT, keyword: .poundIfToken(), withCondition: true, into: &clauses)
        } else {
            record(.lookupFailed, "no postfixIfDirectiveClause child", from: from, to: to)
        }
        if let elseifNT = find("postfixElseifDirectiveClauses", in: spans) {
            collectPostfixElseifClauses(elseifNT.nt, from: elseifNT.from, to: elseifNT.to, into: &clauses)
        }
        if let elseNT = find("postfixElseDirectiveClause", in: spans) {
            appendPostfixIfConfigClause(elseNT, keyword: .poundElseToken(), withCondition: false, into: &clauses)
        }
        return ExprSyntax(PostfixIfConfigExprSyntax(
            base: base,
            config: IfConfigDeclSyntax(
                clauses: IfConfigClauseListSyntax(clauses),
                poundEndif: .poundEndifToken()
            )
        ))
    }

    private mutating func collectPostfixElseifClauses(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into clauses: inout [IfConfigClauseSyntax]
    ) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let cNT = find("postfixElseifDirectiveClause", in: spans) {
            appendPostfixIfConfigClause(cNT, keyword: .poundElseifToken(), withCondition: true, into: &clauses)
        }
        if let restNT = find("postfixElseifDirectiveClauses", in: spans) {
            collectPostfixElseifClauses(restNT.nt, from: restNT.from, to: restNT.to, into: &clauses)
        }
    }

    private mutating func appendPostfixIfConfigClause(
        _ span: NTSpan, keyword: TokenSyntax, withCondition: Bool, into clauses: inout [IfConfigClauseSyntax]
    ) {
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to) else {
            record(.lookupFailed, "no alternate tiles the span", from: span.from, to: span.to)
            return
        }
        var condition: ExprSyntax? = nil
        if withCondition {
            if let condNT = find("compilationCondition", in: spans) {
                var elements: [ExprSyntax] = []
                flattenCompilationCondition(condNT.nt, from: condNT.from, to: condNT.to, into: &elements)
                condition = elements.count == 1
                    ? elements[0]
                    : ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(elements)))
            } else {
                record(.lookupFailed, "directive clause without a condition", from: span.from, to: span.to)
            }
        }
        var elements: IfConfigClauseSyntax.Elements? = nil
        if let bodyNT = find("postfixIfBody", in: spans),
           let (_, bodySpans) = tileAlternate(bodyNT.nt, from: bodyNT.from, to: bodyNT.to) {
            if let peNT = find("postfixExpression", in: bodySpans) {
                elements = .postfixExpression(
                    convertPostfixExpression(peNT.nt, from: peNT.from, to: peNT.to)
                )
            } else if let nestedNT = find("postfixNestedBlocks", in: bodySpans) {
                // postfixNestedBlocks = postfixConditionalCompilationBlock postfixNestedBlocks? .
                // SIBLING nested blocks CHAIN: each takes the previous one as its base, so the
                // right-recursive list folds LEFT — `#if A / #if B … #endif / #if C … #endif` is
                // PostfixIfConfigExpr(base: PostfixIfConfigExpr(base: nil, B), C).
                var chained: ExprSyntax? = nil
                var cursor: NTSpan? = nestedNT
                while let level = cursor {
                    guard let (_, levelSpans) = tileAlternate(level.nt, from: level.from, to: level.to) else {
                        record(.lookupFailed, "no alternate tiles the span", from: level.from, to: level.to)
                        break
                    }
                    if let blockNT = find("postfixConditionalCompilationBlock", in: levelSpans) {
                        chained = convertPostfixConditionalCompilation(
                            blockNT.nt, from: blockNT.from, to: blockNT.to, base: chained
                        )
                    }
                    cursor = find("postfixNestedBlocks", in: levelSpans)
                }
                if let chained {
                    elements = .postfixExpression(chained)
                } else {
                    record(.lookupFailed, "postfixNestedBlocks with no blocks", from: bodyNT.from, to: bodyNT.to)
                }
            } else {
                record(.unhandled, "postfix #if body has no converter: \(alternateKind(bodySpans))",
                       from: bodyNT.from, to: bodyNT.to)
            }
        }
        clauses.append(IfConfigClauseSyntax(
            poundKeyword: keyword,
            condition: condition,
            elements: elements
        ))
    }

    private mutating func convertConditionalCompilationBlock(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> IfConfigDeclSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return IfConfigDeclSyntax(clauses: [])
        }
        var clauses: [IfConfigClauseSyntax] = []
        if let ifNT = find("ifDirectiveClause", in: spans) {
            appendIfConfigClause(ifNT, keyword: .poundIfToken(), withCondition: true, into: &clauses)
        } else {
            record(.lookupFailed, "no ifDirectiveClause child", from: from, to: to)
        }
        if let elseifNT = find("elseifDirectiveClauses", in: spans) {
            collectElseifClauses(elseifNT.nt, from: elseifNT.from, to: elseifNT.to, into: &clauses)
        }
        if let elseNT = find("elseDirectiveClause", in: spans) {
            appendIfConfigClause(elseNT, keyword: .poundElseToken(), withCondition: false, into: &clauses)
        }
        return IfConfigDeclSyntax(
            clauses: IfConfigClauseListSyntax(clauses),
            poundEndif: .poundEndifToken()
        )
    }

    private mutating func collectElseifClauses(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into clauses: inout [IfConfigClauseSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let cNT = find("elseifDirectiveClause", in: spans) {
            appendIfConfigClause(cNT, keyword: .poundElseifToken(), withCondition: true, into: &clauses)
        }
        if let restNT = find("elseifDirectiveClauses", in: spans) {
            collectElseifClauses(restNT.nt, from: restNT.from, to: restNT.to, into: &clauses)
        }
    }

    private mutating func appendIfConfigClause(_ span: NTSpan, keyword: TokenSyntax, withCondition: Bool, into clauses: inout [IfConfigClauseSyntax]) {
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to) else {
            record(.lookupFailed, "no alternate tiles the span", from: span.from, to: span.to)
            return
        }
        var condition: ExprSyntax? = nil
        if withCondition {
            if let condNT = find("compilationCondition", in: spans) {
                var elements: [ExprSyntax] = []
                flattenCompilationCondition(condNT.nt, from: condNT.from, to: condNT.to, into: &elements)
                condition = elements.count == 1
                    ? elements[0]
                    : ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(elements)))
            } else {
                record(.lookupFailed, "directive clause without a condition", from: span.from, to: span.to)
            }
        }
        var items: [CodeBlockItemSyntax] = []
        if let stmtsNT = find("statements", in: spans) {
            items = convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to)
        }
        clauses.append(IfConfigClauseSyntax(
            poundKeyword: keyword,
            condition: condition,
            elements: .statements(CodeBlockItemListSyntax(items))
        ))
    }

    /// compilationCondition = hardIdentifier | booleanLiteral | "(" c ")" | "!" >s< c
    ///                      | c "&&" c | c "||" c | hardIdentifier functionCallArgumentClause .
    ///
    /// swift-syntax parses the condition as an ORDINARY expression, so `a && b && c` is one FLAT
    /// SequenceExpr — the same splice as the infix operators, not nested binary nodes.
    private mutating func flattenCompilationCondition(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [ExprSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        // `c && c` / `c || c`: splice both sides, with the operator between them.
        let subConditions = spans.compactMap { findNonterminal(named: "compilationCondition", sym: $0.0, from: $0.1, to: $0.2) }
        let text = String(input[from..<to])
        if subConditions.count == 2 {
            flattenCompilationCondition(subConditions[0].nt, from: subConditions[0].from, to: subConditions[0].to, into: &elements)
            let op = spansContainKeyword(spans, "&&") ? "&&" : "||"
            elements.append(ExprSyntax(BinaryOperatorExprSyntax(operator: .binaryOperator(op))))
            flattenCompilationCondition(subConditions[1].nt, from: subConditions[1].from, to: subConditions[1].to, into: &elements)
            return
        }
        if let only = subConditions.first {
            if text.hasPrefix("!") {
                var inner: [ExprSyntax] = []
                flattenCompilationCondition(only.nt, from: only.from, to: only.to, into: &inner)
                let operand: ExprSyntax = inner.count == 1
                    ? inner[0] : ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(inner)))
                elements.append(ExprSyntax(PrefixOperatorExprSyntax(operator: .prefixOperator("!"), expression: operand)))
            } else {
                // Parenthesised: swift-syntax gives a one-element TupleExpr.
                var inner: [ExprSyntax] = []
                flattenCompilationCondition(only.nt, from: only.from, to: only.to, into: &inner)
                let operand: ExprSyntax = inner.count == 1
                    ? inner[0] : ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(inner)))
                elements.append(ExprSyntax(TupleExprSyntax(
                    elements: LabeledExprListSyntax([LabeledExprSyntax(expression: operand)])
                )))
            }
            return
        }
        if let boolNT = find("booleanLiteral", in: spans) {
            let value = collectTerminalText(boolNT.nt, from: boolNT.from, to: boolNT.to)
            elements.append(ExprSyntax(BooleanLiteralExprSyntax(literal: .keyword(value == "true" ? .true : .false))))
            return
        }
        if let idNT = find("hardIdentifier", in: spans) {
            let name = collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)
            let reference = ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
            if let clauseNT = find("functionCallArgumentClause", in: spans),
               let (_, clauseSpans) = tileAlternate(clauseNT.nt, from: clauseNT.from, to: clauseNT.to) {
                var args = LabeledExprListSyntax([])
                if let listNT = find("functionCallArgumentList", in: clauseSpans) {
                    args = convertArgumentList(listNT.nt, from: listNT.from, to: listNT.to)
                    if hasTrailingComma(clauseSpans, afterList: "functionCallArgumentList"),
                       var last = args.last {
                        last.trailingComma = .commaToken()
                        args = LabeledExprListSyntax(args.dropLast() + [last])
                    }
                }
                elements.append(ExprSyntax(FunctionCallExprSyntax(
                    calledExpression: reference,
                    leftParen: .leftParenToken(), arguments: args, rightParen: .rightParenToken()
                )))
            } else {
                elements.append(reference)
            }
            return
        }
        record(.unhandled, "compilation condition form has no converter: \(alternateKind(spans))", from: from, to: to)
    }

    // MARK: - Key paths

    /// keyPathExpression = @prefer "\\" keyPathRootType keyPathComponents? .
    /// keyPathExpression =         "\\" keyPathComponents .
    ///
    /// The component rules are a FLAG MACHINE: `keyPathComponents` /
    /// `keyPathComponentsAfterProperty` / `keyPathPivot*` / `keyPathBareTail` exist only to track
    /// whether a dotted `.?` / `.!` / `.[` is still legal after what came before. swift-syntax has
    /// no such structure — just a flat `KeyPathComponentList` — so the machine is flattened here.
    /// That is the same call as the infix splice: the grammar's shape encodes a CONSTRAINT, not a
    /// tree, so the converter reshapes rather than the grammar.
    private mutating func convertKeyPathExpression(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            return missingExpr(.lookupFailed, "no alternate tiles the span", from: from, to: to)
        }
        var root: TypeSyntax? = nil
        if let rootNT = find("keyPathRootType", in: spans),
           let (_, rSpans) = tileAlternate(rootNT.nt, from: rootNT.from, to: rootNT.to) {
            if let baseNT = find("keyPathRootBase", in: rSpans),
               let (_, bSpans) = tileAlternate(baseNT.nt, from: baseNT.from, to: baseNT.to) {
                if let nameNT = find("typeName", in: bSpans) {
                    var generics: GenericArgumentClauseSyntax? = nil
                    if let gNT = find(firstOf: ["typeGenericArgumentClause", "genericArgumentClause"], in: bSpans) {
                        generics = convertGenericArgumentClause(gNT.nt, from: gNT.from, to: gNT.to)
                    }
                    // `\main::Foo.bar` — the root's `typeName` may be module-qualified, and its
                    // raw text would be `main::Foo`.
                    var rootSelector: ModuleSelectorSyntax? = nil
                    var rootName = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
                    if rootName.contains("::"),
                       let (_, rootSpans) = tileAlternate(nameNT.nt, from: nameNT.from, to: nameNT.to) {
                        rootSelector = moduleSelector(in: rootSpans)
                        if let cut = rootName.range(of: "::") { rootName = String(rootName[cut.upperBound...]) }
                    }
                    root = TypeSyntax(IdentifierTypeSyntax(
                        moduleSelector: rootSelector,
                        // `\Self.foo` — `Self` is a keyword token, as everywhere it names a type.
                        name: (rootName == "Self" && rootSelector == nil) ? .keyword(.Self) : .identifier(rootName),
                        genericArgumentClause: generics
                    ))
                } else {
                    root = convertType(baseNT.nt, from: baseNT.from, to: baseNT.to)
                }
            }
        }
        // keyPathRootType     = keyPathRootBase keyPathRootOptionals? .
        // keyPathRootOptionals = keyPathRootOptional keyPathRootOptionals? .
        // keyPathRootOptional  = >s< optionalMark | >s< forceMark .
        // `\X?` and `\X!` wrap the ROOT TYPE, one node per mark, applied outermost-last so
        // `\X??` nests correctly.
        if let rootNT = find("keyPathRootType", in: spans),
           let (_, rSpans) = tileAlternate(rootNT.nt, from: rootNT.from, to: rootNT.to),
           var optionals = find("keyPathRootOptionals", in: rSpans),
           var base = root {
            while true {
                guard let (_, oSpans) = tileAlternate(optionals.nt, from: optionals.from, to: optionals.to) else {
                    record(.lookupFailed, "no alternate tiles the span", from: optionals.from, to: optionals.to)
                    break
                }
                if let markNT = find("keyPathRootOptional", in: oSpans),
                   let (_, mSpans) = tileAlternate(markNT.nt, from: markNT.from, to: markNT.to) {
                    // `optionalMark` / `forceMark` are `-` TERMINALS (`/\?/`, `/!/`), so `find`
                    // cannot see them — every `\X!` was coming out as `\X?`.
                    if findTerminal(named: "forceMark", in: mSpans) != nil {
                        base = TypeSyntax(ImplicitlyUnwrappedOptionalTypeSyntax(
                            wrappedType: base, exclamationMark: .exclamationMarkToken()
                        ))
                    } else {
                        base = TypeSyntax(OptionalTypeSyntax(
                            wrappedType: base, questionMark: .postfixQuestionMarkToken()
                        ))
                    }
                }
                guard let next = find("keyPathRootOptionals", in: oSpans) else { break }
                optionals = next
            }
            root = base
        }
        var components: [KeyPathComponentSyntax] = []
        if let compNT = find("keyPathComponents", in: spans) {
            collectKeyPathComponents(compNT.nt, from: compNT.from, to: compNT.to, into: &components)
        }
        return ExprSyntax(KeyPathExprSyntax(
            backslash: .backslashToken(),
            root: root,
            components: KeyPathComponentListSyntax(components)
        ))
    }

    /// Walks the flag machine in source order, appending one flat component per hop.
    private mutating func collectKeyPathComponents(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into components: inout [KeyPathComponentSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        // The tails (`keyPathComponentsAfterProperty?`, `keyPathBareTail?`) sit inside OPT
        // brackets, so `directName` returns nil for them and the walk stopped after the first
        // component. `findNonterminal` digs through brackets, which is what this needs.
        for (sym, f, t) in spans where f < t {
            if let d = findNonterminal(named: "keyPathProperty", sym: sym, from: f, to: t) {
                appendKeyPathProperty(d.nt, from: d.from, to: d.to, into: &components)
                continue
            }
            var handled = false
            for pivot in ["keyPathPivotFirst", "keyPathPivot", "keyPathBareComponent"] {
                if let d = findNonterminal(named: pivot, sym: sym, from: f, to: t) {
                    appendKeyPathPivot(d.nt, from: d.from, to: d.to, into: &components)
                    handled = true
                    break
                }
            }
            if handled { continue }
            for tail in ["keyPathComponents", "keyPathComponentsAfterProperty", "keyPathBareTail"] {
                if let d = findNonterminal(named: tail, sym: sym, from: f, to: t) {
                    collectKeyPathComponents(d.nt, from: d.from, to: d.to, into: &components)
                    break
                }
            }
        }
    }

    /// keyPathProperty  = "." keyPathMemberName .
    /// keyPathMemberName = moduleSelector? softIdentifier | decimalDigits
    ///                   | moduleSelector? softIdentifier "(" keyPathArgumentLabels ")" .
    private mutating func appendKeyPathProperty(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into components: inout [KeyPathComponentSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to),
              let nameNT = find("keyPathMemberName", in: spans),
              let (_, nSpans) = tileAlternate(nameNT.nt, from: nameNT.from, to: nameNT.to) else {
            record(.lookupFailed, "keyPathProperty without a member name", from: from, to: to)
            return
        }
        // keyPathMemberName = … | moduleSelector? softIdentifier "(" keyPathArgumentLabels ")" .
        // `\Foo.method(a:)` — an unapplied METHOD reference, whose labels belong to the name as
        // DeclNameArguments (the same shape as a compound decl reference).
        var declArgs: DeclNameArgumentsSyntax? = nil
        var text = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
        // `\Foo.BarKit::bar` — the selector is its own node, so trim it out of the NAME text.
        if let cut = text.range(of: "::") { text = String(text[cut.upperBound...]) }
        if let labelsNT = find("keyPathArgumentLabels", in: nSpans) {
            var arguments: [DeclNameArgumentSyntax] = []
            collectKeyPathArgumentLabels(labelsNT.nt, from: labelsNT.from, to: labelsNT.to, into: &arguments)
            declArgs = DeclNameArgumentsSyntax(arguments: DeclNameArgumentListSyntax(arguments))
            // The collected text spans the whole `name(a:b:)`, so trim it back to the name.
            if let open = text.firstIndex(of: "(") { text = String(text[text.startIndex..<open]) }
        }
        components.append(KeyPathComponentSyntax(
            period: .periodToken(),
            component: .property(KeyPathPropertyComponentSyntax(
                declName: DeclReferenceExprSyntax(
                    moduleSelector: moduleSelector(in: nSpans),
                    baseName: declNameToken(text),
                    argumentNames: declArgs
                )
            ))
        ))
    }

    /// keyPathArgumentLabels = keyPathArgumentLabel keyPathArgumentLabels? .
    /// keyPathArgumentLabel  = identifier ---( "inout" "_" ) ":" | "_" ":" .
    private mutating func collectKeyPathArgumentLabels(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into arguments: inout [DeclNameArgumentSyntax]
    ) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let oneNT = find("keyPathArgumentLabel", in: spans) {
            var text = collectTerminalText(oneNT.nt, from: oneNT.from, to: oneNT.to)
            if text.hasSuffix(":") { text.removeLast() }
            arguments.append(DeclNameArgumentSyntax(
                name: text == "_" ? .wildcardToken() : .identifier(text),
                colon: .colonToken()
            ))
        }
        if let restNT = find("keyPathArgumentLabels", in: spans) {
            collectKeyPathArgumentLabels(restNT.nt, from: restNT.from, to: restNT.to, into: &arguments)
        }
    }

    /// The `?` / `!` / `[args]` hops. Each may or may not be dotted, and the leading `.` belongs
    /// to the component in swift-syntax's shape.
    private mutating func appendKeyPathPivot(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into components: inout [KeyPathComponentSyntax]) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        // `keyPathPivot = keyPathPivotFirst .` is a pass-through wrapper.
        if let innerNT = find("keyPathPivotFirst", in: spans) {
            appendKeyPathPivot(innerNT.nt, from: innerNT.from, to: innerNT.to, into: &components)
            return
        }
        if let propNT = find("keyPathProperty", in: spans) {
            appendKeyPathProperty(propNT.nt, from: propNT.from, to: propNT.to, into: &components)
            return
        }
        let text = String(input[from..<to])
        let period: TokenSyntax? = text.hasPrefix(".") ? .periodToken() : nil

        if spansContainKeyword(spans, "[") || find("functionCallArgumentList", in: spans) != nil {
            var args = LabeledExprListSyntax([])
            if let listNT = find("functionCallArgumentList", in: spans) {
                args = convertArgumentList(listNT.nt, from: listNT.from, to: listNT.to)
            }
            components.append(KeyPathComponentSyntax(
                period: period,
                component: .subscript(KeyPathSubscriptComponentSyntax(
                    leftSquare: .leftSquareToken(), arguments: args, rightSquare: .rightSquareToken()
                ))
            ))
            return
        }
        if find("optionalMark", in: spans) != nil || text.hasSuffix("?") {
            components.append(KeyPathComponentSyntax(
                period: period,
                component: .optional(KeyPathOptionalComponentSyntax(
                    questionOrExclamationMark: .postfixQuestionMarkToken()
                ))
            ))
            return
        }
        if find("forceMark", in: spans) != nil || text.hasSuffix("!") {
            components.append(KeyPathComponentSyntax(
                period: period,
                component: .optional(KeyPathOptionalComponentSyntax(
                    questionOrExclamationMark: .exclamationMarkToken()
                ))
            ))
            return
        }
        record(.unhandled, "key-path component form has no converter: \(alternateKind(spans))", from: from, to: to)
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
        var items: [CodeBlockItemSyntax] = []
        if let stmtsNT = find("statements", in: spans) {
            items = convertStatements(stmtsNT.nt, from: stmtsNT.from, to: stmtsNT.to)
        }
        return ClosureExprSyntax(
            leftBrace: .leftBraceToken(),
            signature: signature,
            statements: CodeBlockItemListSyntax(items),
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
        let throwsClause = throwsClauseSyntax(in: spans)
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
            attributes: attributeList(in: spans),
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
        let list = NTSpan(nt: nt, from: from, to: to)
        for nameNT in collectListElements(named: "closureParameterName", in: list, recursiveListName: "closureShorthandNameList") {
            let text = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
            names.append(ClosureShorthandParameterSyntax(
                name: text == "_" ? .wildcardToken() : .identifier(text)
            ))
        }
    }

    /// closureParameter      = attributes? [ parameterDeclarationModifiers ] closureParameterNames typeAnnotation? .
    /// closureParameterNames = externalParameterName closureParameterName | closureParameterName .
    private mutating func collectClosureParameters(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into params: inout [ClosureParameterSyntax]) {
        let list = NTSpan(nt: nt, from: from, to: to)
        for pNT in collectListElements(named: "closureParameter", in: list, recursiveListName: "closureParameterList") {
            guard let (_, pSpans) = tileAlternate(pNT.nt, from: pNT.from, to: pNT.to) else {
                record(.lookupFailed, "no alternate tiles closure parameter span", from: pNT.from, to: pNT.to)
                continue
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
                attributes: attributeList(in: pSpans),
                firstName: first,
                secondName: second,
                colon: type == nil ? nil : .colonToken(),
                type: type
            ))
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
        let list = NTSpan(nt: nt, from: from, to: to)
        for itemNT in collectListElements(named: "captureListItem", in: list, recursiveListName: "captureListItems") {
            guard let (_, iSpans) = tileAlternate(itemNT.nt, from: itemNT.from, to: itemNT.to) else {
                record(.lookupFailed, "no alternate tiles capture item span", from: itemNT.from, to: itemNT.to)
                continue
            }
            var specifier: ClosureCaptureSpecifierSyntax? = nil
            if let specNT = find("captureSpecifier", in: iSpans) {
                let text = collectTerminalText(specNT.nt, from: specNT.from, to: specNT.to)
                if let open = text.firstIndex(of: "(") {
                    // captureSpecifier = "unowned" "(" ( "safe" | "unsafe" ) ")" .
                    // swift-syntax keeps the PARENS as tokens and spells `safe`/`unsafe` as
                    // keywords; an `.identifier` detail with no parens read the same in source but
                    // is a different tree.
                    let detail = String(text[text.index(after: open)...].dropLast())
                        .trimmingCharacters(in: .whitespaces)
                    specifier = ClosureCaptureSpecifierSyntax(
                        specifier: modifierToken(String(text[text.startIndex..<open])
                            .trimmingCharacters(in: .whitespaces)),
                        leftParen: .leftParenToken(),
                        detail: detail == "safe" ? .keyword(.safe) : .keyword(.unsafe),
                        rightParen: .rightParenToken()
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
        if hasTrailingComma(spans, afterList: "arrayLiteralItems"), !elements.isEmpty {
            elements[elements.count - 1] = elements[elements.count - 1].with(\.trailingComma, .commaToken())
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
            } else if let teNT = find("typeExpression", in: itemSpans),
                      let (_, teSpans) = tileAlternate(teNT.nt, from: teNT.from, to: teNT.to),
                      let typeNT = find("type", in: teSpans) {
                // arrayLiteralItem = typeExpression .   typeExpression = type .
                // A FUNCTION type takes the flat-sequence shape (no outer parens here, unlike
                // `"(" functionType ")"`); anything else is a plain TypeExpr.
                if let (_, typeSpans) = tileAlternate(typeNT.nt, from: typeNT.from, to: typeNT.to),
                   let ftNT = find("functionType", in: typeSpans),
                   let sequence = functionTypeAsSequence(ftNT) {
                    elements.append(ArrayElementSyntax(expression: sequence))
                } else {
                    elements.append(ArrayElementSyntax(expression: typeAsExpression(
                        convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
                    )))
                }
            } else {
                record(.unhandled, "array element has no converter: \(alternateKind(itemSpans))",
                       from: itemNT.from, to: itemNT.to)
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
        // SE-0470 trailing comma, kept on the LAST element.
        if hasTrailingComma(spans, afterList: "dictionaryLiteralItems"), !elements.isEmpty {
            elements[elements.count - 1] = elements[elements.count - 1]
                .with(\.trailingComma, .commaToken())
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
        // `(String,)` — SE-0470 trailing comma, which swift-syntax keeps on the LAST element.
        if hasTrailingComma(spans, afterList: "tupleElementList"), !elements.isEmpty {
            elements[elements.count - 1] = elements[elements.count - 1]
                .with(\.trailingComma, .commaToken())
        }
        return ExprSyntax(TupleExprSyntax(
            leftParen: .leftParenToken(),
            elements: LabeledExprListSyntax(elements),
            rightParen: .rightParenToken()
        ))
    }

    private mutating func collectTupleElements(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [LabeledExprSyntax]) {
        // tupleElementList = tupleElement | tupleElement "," tupleElementList .
        let list = NTSpan(nt: nt, from: from, to: to)
        for elNT in collectListElements(named: "tupleElement", in: list, recursiveListName: "tupleElementList") {
            appendTupleElement(elNT, into: &elements)
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
        if find("postfixExpression", in: spans) != nil {
            return missingExpr(.unhandled, "chained implicit member (.a.b) not converted", from: from, to: to)
        }
        guard let nameNT = find("softIdentifier", in: spans) else {
            return missingExpr(.lookupFailed, "no softIdentifier child", from: from, to: to)
        }
        let name = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
        return ExprSyntax(MemberAccessExprSyntax(
            period: .periodToken(),
            declName: DeclReferenceExprSyntax(
                moduleSelector: moduleSelector(in: spans),
                // `.self` needs `keyword(self)`, but NOT the full member-name map: that one reads
                // a backtick-escaped name as an operator (`.\`escaped\`` broke on it).
                baseName: (name == "self" || name == "Self") ? .keyword(name == "self" ? .self : .Self)
                                                             : .identifier(name)
            )
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

        if find("argumentNames", in: spans) != nil {
            record(.unhandled, "member access with argument names not converted", from: from, to: to)
        }
        if let pccNT = find("postfixConditionalCompilationBlock", in: spans) {
            return convertPostfixConditionalCompilation(pccNT.nt, from: pccNT.from, to: pccNT.to, base: base)
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
        let member = ExprSyntax(MemberAccessExprSyntax(
            base: base,
            period: .periodToken(),
            declName: DeclReferenceExprSyntax(
                moduleSelector: moduleSelector(in: spans),
                // After `::` the name is plain: `x.Swift::Self` is an identifier, not
                // `keyword(Self)`. Without a selector, member position keeps its own mapping.
                baseName: find("moduleSelector", in: spans) != nil && (name == "Self" || name == "self")
                    ? .identifier(name)
                    : declNameToken(name)
            )
        ))
        // `x.f<Int>` wraps in GenericSpecializationExpr, exactly as a bare `f<Int>` does.
        if let gcNT = find("genericArgumentClause", in: spans) {
            return ExprSyntax(GenericSpecializationExprSyntax(
                expression: member,
                genericArgumentClause: convertGenericArgumentClause(gcNT.nt, from: gcNT.from, to: gcNT.to)
            ))
        }
        return member
    }

    /// moduleSelector = @excludedFrom(valueBindingPattern) hardIdentifier "::" >n< .
    ///
    /// SE-0491 `Module::name`. swift-syntax does NOT model this as a member access: the selector
    /// hangs off the referring node itself (`DeclReferenceExpr`, `IdentifierType`, `MemberType`,
    /// `MacroExpansionExpr`/`Decl`), so the name token stays exactly where it would be without it.
    private mutating func moduleSelector(
        in spans: [(GrammarNode, CharPosition, CharPosition)]
    ) -> ModuleSelectorSyntax? {
        guard let msNT = find("moduleSelector", in: spans),
              let (_, msSpans) = tileAlternate(msNT.nt, from: msNT.from, to: msNT.to),
              let idNT = find("hardIdentifier", in: msSpans) else { return nil }
        return ModuleSelectorSyntax(
            moduleName: .identifier(collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)),
            colonColon: .colonColonToken()
        )
    }

    /// declarationThrowsClause = throwsClause | "rethrows" .
    /// throwsClause            = "throws" | "throws" "(" type ")" .
    ///
    /// FIVE sites need this — do statement, initializer, function signature, closure signature,
    /// function type — and each had its own copy. THREE of them dropped the thrown TYPE of
    /// `throws(any Error)` entirely. Accepts either the `declarationThrowsClause` wrapper or a
    /// bare `throwsClause` among the given spans.
    private mutating func throwsClauseSyntax(
        in spans: [(GrammarNode, CharPosition, CharPosition)]
    ) -> ThrowsClauseSyntax? {
        var searchSpans = spans
        if let dtcNT = find("declarationThrowsClause", in: spans) {
            guard let (_, wrapped) = tileAlternate(dtcNT.nt, from: dtcNT.from, to: dtcNT.to) else {
                record(.lookupFailed, "no alternate tiles the span", from: dtcNT.from, to: dtcNT.to)
                return nil
            }
            // The `rethrows` alternate has no `throwsClause` child at all.
            if find("throwsClause", in: wrapped) == nil {
                return ThrowsClauseSyntax(throwsSpecifier: .keyword(.rethrows))
            }
            searchSpans = wrapped
        }
        guard let thNT = find("throwsClause", in: searchSpans) else { return nil }
        var thrownType: TypeSyntax? = nil
        if let (_, thSpans) = tileAlternate(thNT.nt, from: thNT.from, to: thNT.to),
           let typeNT = find("type", in: thSpans) {
            thrownType = convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
        }
        return ThrowsClauseSyntax(
            throwsSpecifier: .keyword(.throws),
            leftParen: thrownType == nil ? nil : .leftParenToken(),
            type: thrownType,
            rightParen: thrownType == nil ? nil : .rightParenToken()
        )
    }

    /// A function declaration's NAME token.
    ///
    /// `func ==` uses a binaryOperator token — but this is NOT `declNameToken`, which is for
    /// MEMBER position and remaps far more: reusing it made `func \`class\`()` a binaryOperator
    /// (an escaped name starts with a backtick, which is not alphanumeric) and turned `self`,
    /// `init`, `_` and digit names into keywords/wildcards/literals. In declaration-name position
    /// only the operator case differs from a plain identifier.
    private func functionNameToken(_ name: String) -> TokenSyntax {
        guard let first = name.unicodeScalars.first,
              !CharacterSet.alphanumerics.contains(first),
              first != "_", first != "$", first != "`"
        else { return .identifier(name) }
        return .binaryOperator(name)
    }

    /// A function TYPE read as swift-syntax reads it in expression position: a FLAT SequenceExpr
    /// of the parameter clause (a TupleExpr), an ArrowExpr carrying the effects, and the return
    /// type. There is no "function type in expression position" node, so the shape is synthesised.
    /// Used both for `"(" functionType ")"` and for a bare `typeExpression` array element.
    private mutating func functionTypeAsSequence(_ span: NTSpan) -> ExprSyntax? {
        guard let (_, ftSpans) = tileAlternate(span.nt, from: span.from, to: span.to) else {
            record(.lookupFailed, "no alternate tiles the span", from: span.from, to: span.to)
            return nil
        }
        var sequence: [ExprSyntax] = []
        if let clauseNT = find("functionTypeArgumentClause", in: ftSpans),
           let (_, clauseSpans) = tileAlternate(clauseNT.nt, from: clauseNT.from, to: clauseNT.to) {
            var parameters: [TupleTypeElementSyntax] = []
            if let listNT = find("functionTypeArgumentList", in: clauseSpans) {
                collectFunctionTypeArguments(listNT.nt, from: listNT.from, to: listNT.to, into: &parameters)
            }
            var args: [LabeledExprSyntax] = []
            for (index, element) in parameters.enumerated() {
                args.append(LabeledExprSyntax(
                    label: element.firstName,
                    colon: element.firstName == nil ? nil : .colonToken(),
                    expression: typeAsExpression(element.type),
                    trailingComma: index == parameters.count - 1 ? nil : .commaToken()
                ))
            }
            sequence.append(ExprSyntax(TupleExprSyntax(
                leftParen: .leftParenToken(),
                elements: LabeledExprListSyntax(args),
                rightParen: .rightParenToken()
            )))
        }
        let isAsync = spansContainKeyword(ftSpans, "async")
        let throwsClause = throwsClauseSyntax(in: ftSpans)
        sequence.append(ExprSyntax(ArrowExprSyntax(
            effectSpecifiers: (isAsync || throwsClause != nil)
                ? TypeEffectSpecifiersSyntax(
                    asyncSpecifier: isAsync ? .keyword(.async) : nil, throwsClause: throwsClause)
                : nil,
            arrow: .arrowToken()
        )))
        if let retNT = find("type", in: ftSpans) {
            // A nested arrow return (`-> (inout () -> Void) -> Void`) is itself a function type
            // and splices into the SAME flat sequence.
            if let (_, retSpans) = tileAlternate(retNT.nt, from: retNT.from, to: retNT.to),
               let nestedNT = find("functionType", in: retSpans),
               let nested = functionTypeAsSequence(nestedNT),
               let nestedSequence = nested.as(SequenceExprSyntax.self) {
                sequence.append(contentsOf: nestedSequence.elements)
            } else {
                sequence.append(typeAsExpression(convertType(retNT.nt, from: retNT.from, to: retNT.to)))
            }
        }
        return ExprSyntax(SequenceExprSyntax(elements: ExprListSyntax(sequence)))
    }

    /// A TYPE appearing in expression position. swift-syntax spells a type that could ALSO be an
    /// expression as that expression — `Void` is a `DeclReferenceExpr`, not a `TypeExpr` — and
    /// wraps only the type-only forms (`inout Int`, `any P`, function types) in a `TypeExpr`.
    private func typeAsExpression(_ type: TypeSyntax) -> ExprSyntax {
        if let identifier = type.as(IdentifierTypeSyntax.self),
           identifier.genericArgumentClause == nil,
           identifier.moduleSelector == nil,
           case .identifier(let name) = identifier.name.tokenKind {
            return ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
        }
        return ExprSyntax(TypeExprSyntax(type: type))
    }

    /// The token inside an `IdentifierPattern`. `if let self = self` binds `self`, and
    /// swift-syntax spells the BOUND name with a keyword token — an `.identifier("self")` reads
    /// identically in a dump and still differs.
    private func identifierPatternToken(_ name: String) -> TokenSyntax {
        switch name {
        case "self": return .keyword(.self)
        case "Self": return .keyword(.Self)
        default:     return .identifier(name)
        }
    }

    /// The token inside a `DeclReferenceExpr` used as a member name. The spelling alone
    /// does not fix the token KIND, and swift-syntax is specific about it:
    ///   `x.0`    → integerLiteral (tuple-element access, not an identifier)
    ///   `T.self` → keyword(self)  (likewise `.Self`)
    /// Getting this wrong produces a tree that reads identically in a dump but differs.
    private func declNameToken(_ name: String) -> TokenSyntax {
        if !name.isEmpty && name.allSatisfy(\.isNumber) { return .integerLiteral(name) }
        switch name {
        case "self":      return .keyword(.self)
        case "Self":      return .keyword(.Self)
        // Only `init` becomes a keyword in member position — probe-verified that swift-syntax
        // keeps `deinit` and `subscript` as IDENTIFIERS there (testSubscriptDeinitMembers).
        case "init":      return .keyword(.`init`)
        case "_":         return .wildcardToken()
        default:
            // An operator used as a member/decl name (`x.^`, `func ^`) is a binaryOperator
            // token, not an identifier — no operator character is legal in an identifier.
            // A BACKTICK-escaped name (`\`self\``, `\`class\``) is an identifier, not an operator.
            // Omitting the backtick here made every escaped name a binaryOperator, and the same
            // omission bit `functionNameToken` independently — see its note.
            if let first = name.unicodeScalars.first,
               !CharacterSet.alphanumerics.contains(first),
               first != "_", first != "$", first != "`" {
                return .binaryOperator(name)
            }
            return .identifier(name)
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
                if hasTrailingComma(clauseSpans, afterList: "functionCallArgumentList"), var last = args.last {
                    last.trailingComma = .commaToken()
                    args = LabeledExprListSyntax(args.dropLast() + [last])
                }
            }
        } else if trailing == nil {
            return missingExpr(.lookupFailed, "call with neither argument clause nor trailing closure", from: from, to: to)
        }

        // `View[…] { … }` — with NO argument clause, a trailing closure on a SUBSCRIPT belongs to
        // that SubscriptCallExpr (which has its own `trailingClosure`), not to a FunctionCallExpr
        // wrapped around it.
        if !hasParens, trailing != nil,
           let subscriptCall = callee.as(SubscriptCallExprSyntax.self),
           subscriptCall.trailingClosure == nil {
            return ExprSyntax(subscriptCall
                .with(\.trailingClosure, trailing)
                .with(\.additionalTrailingClosures, additional))
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
        if let d = find("macroExpansionExpression", in: spans) {
            return convertMacroExpansionExpression(d.nt, from: d.from, to: d.to)
        }
        if let d = find("keyPathExpression", in: spans) {
            return convertKeyPathExpression(d.nt, from: d.from, to: d.to)
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
        // moduleGenericIdentifier = moduleSelector identifier ---( "_" ) genericArgumentClause? .
        // SE-0491 `Module::name`. `findTerminal` sees the QUALIFIED name and not the module's own
        // identifier, because `moduleSelector` is a nonterminal and terminal lookup descends only
        // through brackets. After `::` any keyword is a name, so the token kind goes through
        // `declNameToken` just as in member position.
        if let mgNT = find("moduleGenericIdentifier", in: spans),
           let (_, mgSpans) = tileAlternate(mgNT.nt, from: mgNT.from, to: mgNT.to),
           let idNT = findTerminal(named: "identifier", in: mgSpans) {
            // Token kinds after `::` are SELECTIVE, measured against the reference dumps:
            // `Swift::init` is `keyword(init)` but `Swift::Self` is an `identifier` — even though
            // a bare `Self` in expression position IS `keyword(Self)`. So neither "all keywords"
            // nor "all identifiers" is right; only `Self` differs from member position.
            let qualified = collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)
            let reference = ExprSyntax(DeclReferenceExprSyntax(
                moduleSelector: moduleSelector(in: mgSpans),
                baseName: (qualified == "Self" || qualified == "self")
                    ? .identifier(qualified)
                    : declNameToken(qualified)
            ))
            if let gcNT = find("genericArgumentClause", in: mgSpans) {
                return ExprSyntax(GenericSpecializationExprSyntax(
                    expression: reference,
                    genericArgumentClause: convertGenericArgumentClause(gcNT.nt, from: gcNT.from, to: gcNT.to)
                ))
            }
            return reference
        }
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
        // primaryExpression = hardIdentifier "(" argumentNames ")" .
        // An unapplied reference by FULL compound name — `foo(x:)`, `` `escaped function`(x:) ``.
        // swift-syntax keeps the labels on the reference as `DeclNameArguments`, not as a call.
        if let namesNT = find("argumentNames", in: spans),
           let idNT = find("hardIdentifier", in: spans) {
            var arguments: [DeclNameArgumentSyntax] = []
            collectDeclNameArguments(namesNT.nt, from: namesNT.from, to: namesNT.to, into: &arguments)
            return ExprSyntax(DeclReferenceExprSyntax(
                baseName: .identifier(collectTerminalText(idNT.nt, from: idNT.from, to: idNT.to)),
                argumentNames: DeclNameArgumentsSyntax(
                    arguments: DeclNameArgumentListSyntax(arguments)
                )
            ))
        }
        // primaryExpression = "(" functionType ")" .
        // swift-syntax has no "function type in expression position" node: it reads the arrow form
        // as a FLAT SequenceExpr — the parameter clause as a TupleExpr, then an ArrowExpr, then the
        // return type — and the surrounding parens as a TupleExpr around that.
        if let ftNT = find("functionType", in: spans),
           let sequence = functionTypeAsSequence(ftNT) {
            // The `"(" … ")"` of THIS alternate is a TupleExpr around the sequence.
            return ExprSyntax(TupleExprSyntax(
                leftParen: .leftParenToken(),
                elements: LabeledExprListSyntax([LabeledExprSyntax(expression: sequence)]),
                rightParen: .rightParenToken()
            ))
        }
        // primaryExpression = moduleSelector propertyWrapperProjection .   `Swift::$foo`.
        // `propertyWrapperProjection` is a `-` TERMINAL, so it needs `findTerminal` — `find`
        // matches only nonterminals and silently missed it.
        if let pwNT = findTerminal(named: "propertyWrapperProjection", in: spans) {
            return ExprSyntax(DeclReferenceExprSyntax(
                moduleSelector: moduleSelector(in: spans),
                baseName: .identifier(collectTerminalText(pwNT.nt, from: pwNT.from, to: pwNT.to))
            ))
        }
        // primaryExpression = anyType .   `Any` used as a VALUE (`Any.self`).
        if find("anyType", in: spans) != nil {
            return ExprSyntax(TypeExprSyntax(type: IdentifierTypeSyntax(name: .keyword(.Any))))
        }
        // primaryExpression = selfType .   `Self` used as a VALUE (`discard Self`).
        if find("selfType", in: spans) != nil {
            return ExprSyntax(DeclReferenceExprSyntax(baseName: .keyword(.Self)))
        }
        // primaryExpression = "(" moduleSelector? operator ")" .
        // Operator-as-value, e.g. `(/)`, `(+)`, `(Swift::+)` per SE-0491. swift-syntax keeps the
        // parentheses as a TupleExpr and spells the reference with a binaryOperator token — an
        // `.identifier` would not match even with the same text.
        if let opNT = find("operator", in: spans) {
            let text = collectTerminalText(opNT.nt, from: opNT.from, to: opNT.to)
            return ExprSyntax(TupleExprSyntax(elements: LabeledExprListSyntax([
                LabeledExprSyntax(expression: ExprSyntax(
                    DeclReferenceExprSyntax(
                        moduleSelector: moduleSelector(in: spans),
                        baseName: .binaryOperator(text)
                    )
                ))
            ])))
        }
        // primaryExpression = attribute type .
        // A TYPE in expression position — `[@convention(c) (Int32) -> Int32]`, `@Sendable () -> Void`.
        // swift-syntax wraps it in TypeExpr, with the attribute on an AttributedType.
        if let attrNT = find("attribute", in: spans), let typeNT = find("type", in: spans) {
            var base = convertType(typeNT.nt, from: typeNT.from, to: typeNT.to)
            var attributeItems: [AttributeListSyntax.Element] = []
            if let attribute = convertAttribute(attrNT.nt, from: attrNT.from, to: attrNT.to) {
                attributeItems.append(.attribute(attribute))
            }
            var specifierItems: [TypeSpecifierListSyntax.Element] = []
            // `@isolated(any) @convention(swift) () -> ()` reaches the inner attribute through
            // `type = attribute type`, which builds its own AttributedType. swift-syntax keeps
            // exactly ONE, so merge rather than nest.
            if let inner = base.as(AttributedTypeSyntax.self) {
                attributeItems.append(contentsOf: inner.attributes)
                specifierItems.append(contentsOf: inner.specifiers)
                base = inner.baseType
            }
            return ExprSyntax(TypeExprSyntax(type: AttributedTypeSyntax(
                specifiers: TypeSpecifierListSyntax(specifierItems),
                attributes: AttributeListSyntax(attributeItems),
                baseType: base
            )))
        }
        // primaryExpression = boxedProtocolType .   `any P` as a value.
        if let bpNT = find("boxedProtocolType", in: spans),
           let (_, bpSpans) = tileAlternate(bpNT.nt, from: bpNT.from, to: bpNT.to),
           let baseNT = find("type", in: bpSpans) {
            return ExprSyntax(TypeExprSyntax(type: SomeOrAnyTypeSyntax(
                someOrAnySpecifier: .keyword(.any),
                constraint: convertType(baseNT.nt, from: baseNT.from, to: baseNT.to)
            )))
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
            // extendedRegularExpressionLiteral - @builder .  `#/…/#`, with the pound
            // delimiters as their own tokens either side of the slashes.
            let pounds = text.prefix(while: { $0 == "#" })
            let inner = text.dropFirst(pounds.count)
            if !pounds.isEmpty, inner.hasPrefix("/"), text.hasSuffix(String(pounds)) {
                let body = inner.dropFirst().dropLast(1 + pounds.count)
                let poundToken = TokenSyntax.regexPoundDelimiter(String(pounds))
                return ExprSyntax(RegexLiteralExprSyntax(
                    openingPounds: poundToken,
                    openingSlash: .regexSlashToken(),
                    regex: .regexLiteralPattern(String(body)),
                    closingSlash: .regexSlashToken(),
                    closingPounds: poundToken
                ))
            }
            return missingExpr(.unhandled, "regex literal form has no converter", from: from, to: to)
        }
        return missingExpr(.unhandled, "literal kind has no converter: \(alternateKind(spans))", from: from, to: to)
    }

    private mutating func convertNumericLiteral(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // numericLiteral = signedIntegerLiteral | signedFloatingPointLiteral .
        // Classify by spelling rather than by alternate: the two alternates differ
        // only in which literal terminal they reach, and the text decides it.
        var text = collectTerminalText(nt, from: from, to: to)
        // `signedIntegerLiteral = [ "-" >s< ] integerLiteral` — the SIGN is not part of the
        // literal token in swift-syntax; `-17` is a PrefixOperatorExpr over `17`.
        var negated = false
        if text.hasPrefix("-") {
            text.removeFirst()
            negated = true
        }
        let literal: ExprSyntax
        if text.contains(".") || text.contains("e") || text.contains("E") || text.contains("p") || text.contains("P") {
            literal = ExprSyntax(FloatLiteralExprSyntax(literal: .floatLiteral(text)))
        } else {
            literal = ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral(text)))
        }
        guard negated else { return literal }
        return ExprSyntax(PrefixOperatorExprSyntax(
            operator: .prefixOperator("-"), expression: literal
        ))
    }

    /// Split a MULTILINE literal body into `StringSegment` texts.
    ///
    /// The boundaries are probe-confirmed against swift-syntax — see `MultilineSegmentProbe`,
    /// which prints the reference segments for every fixture below. A segment ends after:
    ///
    ///   • a real line break — the break STAYS in the segment (`"Six⏎"`, `"Zeta⏎"`, `""`)
    ///   • a `\n` ESCAPE — the two escape characters STAY in the segment (`"Five\n"`, `"⏎"`, …)
    ///   • a `\` + line-break continuation — BOTH are elided, belonging to no segment
    ///
    /// `\t`, `\"`, `\\` and `\u{…}` do NOT break, so "split at every escape" is wrong; only the
    /// ones that end a line of the value or of the source do. Splitting on real newlines alone
    /// was also wrong — it merged `"Five\n"` with the newline that follows it.
    ///
    /// In a RAW literal the escape introducer is `\` plus the delimiter's own `#` count, so a bare
    /// `\n` there is literal text and breaks nothing. A body ending in a bare introducer is a
    /// continuation whose line break was the closing delimiter's own newline (already removed by
    /// the caller): it elides, and swift-syntax emits no trailing empty segment for it.
    ///
    /// An EMPTY body yields one empty segment — `\"\"\"⏎⏎    \"\"\"` (a blank line) has exactly
    /// that. The zero-segment case is `\"\"\"⏎    \"\"\"`, where there is no content line at all;
    /// only the caller can tell those apart, since both reach here with an empty body.
    private func multilineSegmentTexts(_ body: String, pounds: Int) -> [String] {
        let intro = "\\" + String(repeating: "#", count: pounds)
        var out: [String] = []
        var cur = ""
        var i = body.startIndex
        var endedOnElidedContinuation = false

        /// Consume a line break at `j`, treating CRLF as one. Returns nil if there is none.
        func lineBreakEnd(at j: String.Index) -> String.Index? {
            guard j < body.endIndex else { return nil }
            if body[j] == "\r" {
                let k = body.index(after: j)
                return (k < body.endIndex && body[k] == "\n") ? body.index(after: k) : k
            }
            return body[j] == "\n" ? body.index(after: j) : nil
        }

        while i < body.endIndex {
            if let breakEnd = lineBreakEnd(at: i) {
                cur += body[i..<breakEnd]
                out.append(cur)
                cur = ""
                i = breakEnd
                continue
            }
            if body[i...].hasPrefix(intro) {
                let after = body.index(i, offsetBy: intro.count)
                guard after < body.endIndex else {
                    out.append(cur)
                    cur = ""
                    endedOnElidedContinuation = true
                    break
                }
                if body[after] == "n" {
                    cur += intro + "n"
                    out.append(cur)
                    cur = ""
                    i = body.index(after: after)
                    continue
                }
                // A continuation may carry trailing horizontal whitespace before its line break.
                var j = after
                while j < body.endIndex, body[j] == " " || body[j] == "\t" { j = body.index(after: j) }
                if let breakEnd = lineBreakEnd(at: j) {
                    out.append(cur)
                    cur = ""
                    i = breakEnd
                    continue
                }
                // Any other escape: consume the introducer AND the escaped character together, so
                // that the second `\` of `\\` cannot be mistaken for a fresh introducer.
                cur += intro
                cur.append(body[after])
                i = body.index(after: after)
                continue
            }
            cur.append(body[i])
            i = body.index(after: i)
        }
        if !endedOnElidedContinuation { out.append(cur) }
        return out
    }

    /// Convert an `attributes?` child if present. Every declaration, parameter and closure
    /// signature in the grammar carries one; dropping it silently produced an empty
    /// `AttributeList` where swift-syntax had entries.
    private mutating func attributeList(in spans: [(GrammarNode, CharPosition, CharPosition)]) -> AttributeListSyntax {
        guard let attrNT = find("attributes", in: spans) else { return AttributeListSyntax([]) }
        return convertAttributes(attrNT.nt, from: attrNT.from, to: attrNT.to)
    }

    /// One element of an `AttributedType`'s `specifiers` list.
    ///
    /// parameterModifier = "inout" | "borrowing" | "consuming" | "isolated" | "_const" | "sending" | "__shared" | "__owned" .
    /// parameterModifier = "nonisolated" >s< "(" "nonsending" ")" .
    /// parameterModifier = "dependsOn" >s< "(" "scoped"? identifierList ")" .
    ///
    /// Only the first alternate is a `SimpleTypeSpecifier`; the parenthesised ones have their own
    /// node types, so a text-based `contains("(")` check reported them all as unhandled.
    private mutating func typeSpecifier(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition
    ) -> TypeSpecifierListSyntax.Element {
        let text = collectTerminalText(nt, from: from, to: to)
        if text.hasPrefix("nonisolated") {
            // The argument is always `(nonsending)` — the grammar admits no other spelling.
            return .nonisolatedTypeSpecifier(NonisolatedTypeSpecifierSyntax(
                nonisolatedKeyword: .keyword(.nonisolated),
                argument: text.contains("(")
                    ? NonisolatedSpecifierArgumentSyntax(nonsendingKeyword: .keyword(.nonsending))
                    : nil
            ))
        }
        if text.hasPrefix("dependsOn") {
            record(.unhandled, "dependsOn lifetime type specifier not converted", from: from, to: to)
        }
        return .simpleTypeSpecifier(SimpleTypeSpecifierSyntax(specifier: typeSpecifierToken(text)))
    }

    /// Did the parse take a MULTILINE string form? Read the ALTERNATE rather than re-deriving the
    /// classification from the characters (TODO 29): four grammar terminals share the `"` prefix,
    /// so a text sniff can — and did — reach the opposite conclusion from the scanner.
    ///
    /// staticStringLiteral = singleLineStringLiteral | multilineStringLiteral .
    /// staticStringLiteral = @excludedFrom(availableAttribute) extendedSinglelineStringLiteral .
    /// staticStringLiteral = @excludedFrom(availableAttribute) extendedMultilineStringLiteral .
    /// interpolatedStringLiteral = @excludedFrom(availableAttribute) singleLineInterpolatedStringLiteral .
    /// interpolatedStringLiteral = @excludedFrom(availableAttribute) multilineInterpolatedStringLiteral .
    ///
    /// The four static forms are `-` TERMINALS, so they need `findTerminal`; the two interpolated
    /// forms are nonterminals assembled from Head/Part/Tail terminals, so they need `find`.
    /// `nil` means neither level identified a form — the caller decides what to do about that.
    private mutating func tookMultilineStringForm(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> Bool? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else { return nil }
        // Callers may hand us the `staticStringLiteral` node itself (e.g. a `@convention` cType),
        // in which case the four terminals are already at this level.
        for (name, multiline) in [("multilineStringLiteral", true), ("extendedMultilineStringLiteral", true),
                                  ("singleLineStringLiteral", false), ("extendedSinglelineStringLiteral", false)] {
            if findTerminal(named: name, in: spans) != nil { return multiline }
        }
        if let staticNT = find("staticStringLiteral", in: spans),
           let (_, staticSpans) = tileAlternate(staticNT.nt, from: staticNT.from, to: staticNT.to) {
            if findTerminal(named: "multilineStringLiteral", in: staticSpans) != nil { return true }
            if findTerminal(named: "extendedMultilineStringLiteral", in: staticSpans) != nil { return true }
            if findTerminal(named: "singleLineStringLiteral", in: staticSpans) != nil { return false }
            if findTerminal(named: "extendedSinglelineStringLiteral", in: staticSpans) != nil { return false }
            return nil
        }
        if let interpNT = find("interpolatedStringLiteral", in: spans),
           let (_, interpSpans) = tileAlternate(interpNT.nt, from: interpNT.from, to: interpNT.to) {
            if find("multilineInterpolatedStringLiteral", in: interpSpans) != nil { return true }
            if find("singleLineInterpolatedStringLiteral", in: interpSpans) != nil { return false }
        }
        return nil
    }

    private mutating func convertStringLiteral(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ExprSyntax {
        // stringLiteral = staticStringLiteral | interpolatedStringLiteral .
        // interpolatedStringLiteral = @excludedFrom(availableAttribute) singleLineInterpolatedStringLiteral .
        // interpolatedStringLiteral = @excludedFrom(availableAttribute) multilineInterpolatedStringLiteral .
        // `find` digs through brackets but not through nonterminals, so descend both levels.
        if let (_, spans) = tileAlternate(nt, from: from, to: to),
           let interp = find("interpolatedStringLiteral", in: spans),
           let (_, interpSpans) = tileAlternate(interp.nt, from: interp.from, to: interp.to) {
            if let single = find("singleLineInterpolatedStringLiteral", in: interpSpans),
               let expr = convertInterpolatedStringLiteral(single.nt, from: single.from, to: single.to,
                                                           multiline: false) {
                return expr
            }
            if let multi = find("multilineInterpolatedStringLiteral", in: interpSpans),
               let expr = convertInterpolatedStringLiteral(multi.nt, from: multi.from, to: multi.to,
                                                           multiline: true) {
                return expr
            }
        }
        // Collect all text between quotes
        let fullText = collectTerminalText(nt, from: from, to: to)
        // Raw (`#"…"#`) and multiline (`"""…"""`) forms MUST be tested before the plain
        // single-line branch below: `"""…"""` also starts and ends with `"`, so the simple
        // branch matched it first and produced a single-quote token with the delimiters as
        // content. swift-syntax carries the pounds as their own tokens and uses a distinct
        // `multilineStringQuote`.
        let pounds = fullText.prefix(while: { $0 == "#" })
        let afterPounds = fullText.dropFirst(pounds.count)
        // Single/multiline comes from the ALTERNATE the parse took, never from the characters:
        // four terminals share the `"` prefix, and a text sniff read `#""""#` — a SINGLE-LINE raw
        // string whose content is `""` — as an empty multiline one, synthesising delimiters the
        // source never had (testFalseMultilineDelimiters). If the form cannot be identified that
        // is a converter bug, not an unhandled form, so say so loudly and fall back to the old
        // sniff only to keep the rest of the tree usable.
        let isMultiline: Bool
        if let took = tookMultilineStringForm(nt, from: from, to: to) {
            isMultiline = took
        } else {
            record(.lookupFailed, "string literal matched no known form", from: from, to: to)
            isMultiline = afterPounds.hasPrefix("\"\"\"")
                && afterPounds.dropFirst(3).first.map { $0.isNewline } == true
        }
        if isMultiline || (!pounds.isEmpty && afterPounds.hasPrefix("\"")) {
            // `\"\"\"⏎    \"\"\"` has NO content line — the one line break present is the opener's, so
            // nothing remains between it and the closer and swift-syntax emits zero segments. A
            // blank line supplies a SECOND break and so does have a (empty) content line.
            var hasContentLine = false
            let quoteLen = isMultiline ? 3 : 1
            var body = String(afterPounds.dropFirst(quoteLen).dropLast(quoteLen + pounds.count))
            if isMultiline {
                // The newline after the opener is a delimiter, and so is the final newline plus
                // whatever indentation precedes the closer. That indentation is ALSO stripped
                // from every content line — `\"\"\"⏎    abc⏎    \"\"\"` has the segment `abc`,
                // not `    abc` — so it must be captured before it is discarded.
                if body.hasPrefix("\r\n") { body.removeFirst(2) } else if body.hasPrefix("\n") { body.removeFirst() }
                var indent = ""
                if let lastNewline = body.lastIndex(of: "\n") {
                    indent = String(body[body.index(after: lastNewline)...])
                    body = String(body[body.startIndex..<lastNewline])
                    if body.hasSuffix("\r") { body.removeLast() }
                    hasContentLine = true
                }
                if !indent.isEmpty {
                    body = body.split(separator: "\n", omittingEmptySubsequences: false)
                        .map { $0.hasPrefix(indent) ? String($0.dropFirst(indent.count)) : String($0) }
                        .joined(separator: "\n")
                }
            }
            let poundToken: TokenSyntax? = pounds.isEmpty ? nil : .rawStringPoundDelimiter(String(pounds))
            let quote: TokenSyntax = isMultiline ? .multilineStringQuoteToken() : .stringQuoteToken()
            // Multiline segmentation is escape-sensitive, so it needs its own walk; a single-line
            // raw string has no line breaks and is always exactly one segment.
            let texts = isMultiline
                ? (hasContentLine ? multilineSegmentTexts(body, pounds: pounds.count) : [])
                : [body]
            let segments = texts.map { text in
                StringLiteralSegmentListSyntax.Element.stringSegment(StringSegmentSyntax(
                    content: .stringSegment(text)
                ))
            }
            return ExprSyntax(StringLiteralExprSyntax(
                openingPounds: poundToken,
                openingQuote: quote,
                segments: StringLiteralSegmentListSyntax(segments),
                closingQuote: quote,
                closingPounds: poundToken
            ))
        }

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
    /// singleLineInterpolatedStringLiteral = interpolatedStringLiteralHead functionCallArgumentList
    ///     { interpolatedStringLiteralPart functionCallArgumentList } interpolatedStringLiteralTail .
    /// multilineInterpolatedStringLiteral  = the same shape over the `multiline…` terminals.
    ///
    /// Head is `"abc\(`, each Part is `)mid\(`, Tail is `)ghi"` — so literal text and
    /// interpolations strictly alternate, and walking the pieces in SOURCE ORDER handles any
    /// number of interpolations. The MULTILINE form differs only in its delimiters and in needing
    /// the opener's line break, the closer's indentation, and escape-sensitive segment splitting —
    /// exactly the rules `multilineSegmentTexts` already encodes for the static form.
    private mutating func convertInterpolatedStringLiteral(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, multiline: Bool
    ) -> ExprSyntax? {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "interpolated literal: no alternate tiles the span", from: from, to: to)
            return nil
        }
        let prefix = multiline ? "multiline" : ""
        let headName = prefix + (multiline ? "InterpolatedStringLiteralHead" : "interpolatedStringLiteralHead")
        let partName = prefix + (multiline ? "InterpolatedStringLiteralPart" : "interpolatedStringLiteralPart")
        let tailName = prefix + (multiline ? "InterpolatedStringLiteralTail" : "interpolatedStringLiteralTail")
        var pieces: [NTSpan] = []
        collectInterpolationPieces(spans, names: [headName, partName, tailName, "functionCallArgumentList"],
                                   into: &pieces)
        pieces.sort { $0.from < $1.from }
        guard pieces.first?.nt.name == headName, pieces.last?.nt.name == tailName else {
            record(.unhandled, "interpolated literal pieces: \(pieces.map(\.nt.name).joined(separator: "+"))",
                   from: from, to: to)
            return nil
        }
        let quote = multiline ? "\"\"\"" : "\""
        // The closer's INDENTATION is stripped from every content line, and it is only visible in
        // the tail, so it has to be read before any piece is split.
        var indent = ""
        if multiline, let tail = pieces.last {
            let tailText = String(input[tail.from..<tail.to])
            if let close = tailText.range(of: quote, options: .backwards) {
                let beforeClose = tailText[tailText.startIndex..<close.lowerBound]
                if let lastNewline = beforeClose.lastIndex(of: "\n") {
                    indent = String(beforeClose[beforeClose.index(after: lastNewline)...])
                }
            }
        }
        /// Strip the closer's indentation from each line, then split on the multiline segment rules.
        func segments(of body: String) -> [StringLiteralSegmentListSyntax.Element] {
            guard multiline else {
                return [.stringSegment(StringSegmentSyntax(content: .stringSegment(body)))]
            }
            var text = body
            if !indent.isEmpty {
                text = text.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { $0.hasPrefix(indent) ? String($0.dropFirst(indent.count)) : String($0) }
                    .joined(separator: "\n")
            }
            return multilineSegmentTexts(text, pounds: 0).map {
                .stringSegment(StringSegmentSyntax(content: .stringSegment($0)))
            }
        }

        var elements: [StringLiteralSegmentListSyntax.Element] = []
        for piece in pieces {
            let text = String(input[piece.from..<piece.to])
            switch piece.nt.name {
            case headName:
                guard text.hasPrefix(quote), text.hasSuffix("\\(") else {
                    record(.unhandled, "interpolated head has an unexpected shape: \(text.debugDescription)", from: piece.from, to: piece.to)
                    return nil
                }
                var body = String(text.dropFirst(quote.count).dropLast(2))
                // The line break after a multiline opener is a delimiter, not content.
                if multiline {
                    if body.hasPrefix("\r\n") { body.removeFirst(2) } else if body.hasPrefix("\n") { body.removeFirst() }
                }
                elements += segments(of: body)
            case partName:
                guard text.hasPrefix(")"), text.hasSuffix("\\(") else {
                    record(.unhandled, "interpolated part has an unexpected shape: \(text.debugDescription)", from: piece.from, to: piece.to)
                    return nil
                }
                elements += segments(of: String(text.dropFirst().dropLast(2)))
            case tailName:
                // The tail SPAN can run past the closing delimiter and include trailing layout, so
                // cut at the LAST delimiter rather than requiring it to end the text.
                guard text.hasPrefix(")"), let close = text.range(of: quote, options: .backwards) else {
                    record(.unhandled, "interpolated tail has an unexpected shape: \(text.debugDescription)", from: piece.from, to: piece.to)
                    return nil
                }
                var body = String(text[text.index(after: text.startIndex)..<close.lowerBound])
                // The final line break plus the closer's indentation are delimiters too.
                if multiline, let lastNewline = body.lastIndex(of: "\n") {
                    body = String(body[body.startIndex..<lastNewline])
                    if body.hasSuffix("\r") { body.removeLast() }
                }
                elements += segments(of: body)
            default:
                elements.append(.expressionSegment(ExpressionSegmentSyntax(
                    backslash: .backslashToken(),
                    leftParen: .leftParenToken(),
                    expressions: convertArgumentList(piece.nt, from: piece.from, to: piece.to),
                    rightParen: .rightParenToken()
                )))
            }
        }
        let quoteToken: TokenSyntax = multiline ? .multilineStringQuoteToken() : .stringQuoteToken()
        return ExprSyntax(StringLiteralExprSyntax(
            openingQuote: quoteToken,
            segments: StringLiteralSegmentListSyntax(elements),
            closingQuote: quoteToken
        ))
    }

    /// The Head/Part/Tail terminals and the argument lists between them, at whatever bracket depth
    /// the EBNF repetition put them.
    private mutating func collectInterpolationPieces(
        _ spans: [(GrammarNode, CharPosition, CharPosition)], names: Set<String>, into pieces: inout [NTSpan]
    ) {
        for (sym, f, t) in spans where f < t {
            if names.contains(sym.name) {
                pieces.append(NTSpan(nt: sym, from: f, to: t))
            } else if sym.kind.isBracket, let (_, inner) = tileAlternate(sym, from: f, to: t) {
                collectInterpolationPieces(inner, names: names, into: &pieces)
            }
        }
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
        // functionCallArgument = @prefer expression | operator | moduleSelector operator .
        // Requiring an `expression` child dropped the operator alternates SILENTLY — no node and
        // no diagnostic — so `reduce(0, +)` lost its second argument entirely.
        let list = NTSpan(nt: nt, from: from, to: to)
        for argNT in collectListElements(named: "functionCallArgument", in: list, recursiveListName: "functionCallArgumentList") {
            guard let (_, argSpans) = tileAlternate(argNT.nt, from: argNT.from, to: argNT.to) else {
                record(.lookupFailed, "no alternate tiles function-call argument span", from: argNT.from, to: argNT.to)
                continue
            }
            var expr: ExprSyntax? = nil
            if let exprNT = find("expression", in: argSpans) {
                expr = convertExpression(exprNT.nt, from: exprNT.from, to: exprNT.to)
            } else if let opNT = find("operator", in: argSpans) {
                // An operator passed as a VALUE. swift-syntax spells the reference with a
                // binaryOperator token; unlike `(+)` there are no parentheses to model here.
                expr = ExprSyntax(DeclReferenceExprSyntax(
                    moduleSelector: moduleSelector(in: argSpans),
                    baseName: .binaryOperator(collectTerminalText(opNT.nt, from: opNT.from, to: opNT.to))
                ))
            }
            if let expr {
                if let labelNT = find("argumentLabel", in: argSpans) {
                    let label = collectTerminalText(labelNT.nt, from: labelNT.from, to: labelNT.to)
                    items.append(LabeledExprSyntax(
                        // `f(_: 1)` — a `_` label is a wildcard token, as in every name position.
                        label: label == "_" ? .wildcardToken() : .identifier(label),
                        colon: .colonToken(),
                        expression: expr
                    ))
                } else {
                    items.append(LabeledExprSyntax(expression: expr))
                }
            } else {
                record(.lookupFailed, "argument with neither an expression nor an operator: \(alternateKind(argSpans))",
                       from: argNT.from, to: argNT.to)
            }
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
        // type = "(" tupleTypeElement ")" .   A PARENTHESISED type is a one-element TupleType in
        // swift-syntax, not the bare type — `(sending T)` and `(label: T)` reach here too, which
        // is why the element (not just a `type`) carries the shape.
        if let elNT = find("tupleTypeElement", in: spans) {
            var elements: [TupleTypeElementSyntax] = []
            appendTupleTypeElement(elNT, into: &elements)
            return TypeSyntax(TupleTypeSyntax(
                leftParen: .leftParenToken(),
                elements: TupleTypeElementListSyntax(elements),
                rightParen: .rightParenToken()
            ))
        }
        // functionType = functionTypeArgumentClause "async"? throwsClause? "->" type .
        if let d = find("functionType", in: spans) {
            return convertFunctionType(d.nt, from: d.from, to: d.to)
        }
        // inlineArrayType = "[" genericArgument >n< "of" genericArgument "]" .   (SE-0453)
        // TWO `genericArgument`s in one alternate — count then element — so walk the spans in
        // order rather than calling `find` twice and getting the first one both times.
        if let iaNT = find("inlineArrayType", in: spans),
           let (_, iaSpans) = tileAlternate(iaNT.nt, from: iaNT.from, to: iaNT.to) {
            var parts: [GenericArgumentSyntax] = []
            for (sym, f, t) in iaSpans where f < t {
                if let gaNT = findNonterminal(named: "genericArgument", sym: sym, from: f, to: t),
                   let argument = genericArgument(gaNT) {
                    parts.append(argument)
                }
            }
            guard parts.count == 2 else {
                return missingType(.lookupFailed, "inline array without a count and an element",
                                   from: iaNT.from, to: iaNT.to)
            }
            return TypeSyntax(InlineArrayTypeSyntax(
                leftSquare: .leftSquareToken(),
                count: parts[0],
                separator: .keyword(.of),
                element: parts[1],
                rightSquare: .rightSquareToken()
            ))
        }
        // Callers may hand us the composition node ITSELF rather than a `type` wrapping it —
        // `collectGenericParameters` does exactly that — in which case `protocolCompositionType`
        // is this node and not a child, so key off the element instead.
        if find("protocolCompositionElement", in: spans) != nil {
            var elements: [CompositionTypeElementSyntax] = []
            collectCompositionElements(nt, from: from, to: to, into: &elements)
            for i in elements.indices.dropLast() {
                elements[i] = elements[i].with(\.ampersand, .binaryOperator("&"))
            }
            return TypeSyntax(CompositionTypeSyntax(
                elements: CompositionTypeElementListSyntax(elements)
            ))
        }
        // protocolCompositionType = protocolCompositionElement "&" protocolCompositionContinuation .
        if let pcNT = find("protocolCompositionType", in: spans) {
            var elements: [CompositionTypeElementSyntax] = []
            collectCompositionElements(pcNT.nt, from: pcNT.from, to: pcNT.to, into: &elements)
            for i in elements.indices.dropLast() {
                elements[i] = elements[i].with(\.ampersand, .binaryOperator("&"))
            }
            return TypeSyntax(CompositionTypeSyntax(
                elements: CompositionTypeElementListSyntax(elements)
            ))
        }
        // type = "~" type .   SE-0390 suppressed/inverse type.
        if let innerNT = find("type", in: spans), spansContainKeyword(spans, "~") {
            return TypeSyntax(SuppressedTypeSyntax(
                withoutTilde: .prefixOperator("~"),
                type: convertType(innerNT.nt, from: innerNT.from, to: innerNT.to)
            ))
        }
        // opaqueType = "some" type .
        // boxedProtocolType = "any" >-> ( … ) type .
        // Both are SomeOrAnyType in swift-syntax, distinguished only by the specifier keyword.
        for (rule, keyword) in [("opaqueType", Keyword.some), ("boxedProtocolType", Keyword.any)] {
            guard let d = find(rule, in: spans),
                  let (_, inner) = tileAlternate(d.nt, from: d.from, to: d.to),
                  let baseNT = find("type", in: inner) else { continue }
            return TypeSyntax(SomeOrAnyTypeSyntax(
                someOrAnySpecifier: .keyword(keyword),
                constraint: convertType(baseNT.nt, from: baseNT.from, to: baseNT.to)
            ))
        }
        // type = parameterModifier type .   type = attribute type .
        // swift-syntax wraps both in ONE AttributedType: specifiers (`inout`, `borrowing`,
        // `sending`) go in `specifiers`, `@attr` goes in `attributes`, and the operand is
        // `baseType`. Our grammar is RIGHT-RECURSIVE, so `@autoclosure @escaping T` arrives as
        // three nested `type` nodes; converting each level separately nested an AttributedType
        // inside another one. Peel the whole prefix chain first and wrap exactly once.
        if find("type", in: spans) != nil,
           find(firstOf: ["parameterModifier", "attribute"], in: spans) != nil {
            var specifierItems: [TypeSpecifierListSyntax.Element] = []
            var attributeItems: [AttributeListSyntax.Element] = []
            var cursor: NTSpan? = NTSpan(nt: nt, from: from, to: to)
            var baseType: TypeSyntax? = nil
            while let level = cursor {
                guard let (_, levelSpans) = tileAlternate(level.nt, from: level.from, to: level.to),
                      let innerNT = find("type", in: levelSpans),
                      find(firstOf: ["parameterModifier", "attribute"], in: levelSpans) != nil else {
                    baseType = convertType(level.nt, from: level.from, to: level.to)
                    break
                }
                if let modNT = find("parameterModifier", in: levelSpans) {
                    specifierItems.append(typeSpecifier(modNT.nt, from: modNT.from, to: modNT.to))
                }
                if let attrNT = find("attribute", in: levelSpans),
                   let attribute = convertAttribute(attrNT.nt, from: attrNT.from, to: attrNT.to) {
                    attributeItems.append(.attribute(attribute))
                }
                cursor = innerNT
            }
            return TypeSyntax(AttributedTypeSyntax(
                specifiers: TypeSpecifierListSyntax(specifierItems),
                attributes: AttributeListSyntax(attributeItems),
                baseType: baseType ?? TypeSyntax(MissingTypeSyntax())
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
    /// protocolCompositionType         = protocolCompositionElement "&" protocolCompositionContinuation .
    /// protocolCompositionContinuation = protocolCompositionElement | protocolCompositionType .
    /// protocolCompositionElement      = typeIdentifier | anyType .
    ///
    /// The grammar nests to the right; swift-syntax keeps ONE flat `CompositionType` whose
    /// elements each carry the following `&`, so the nesting is walked out here.
    private mutating func collectCompositionElements(
        _ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [CompositionTypeElementSyntax]
    ) {
        guard let (_, spans) = tileAlternate(nt, from: from, to: to) else {
            record(.lookupFailed, "no alternate tiles the span", from: from, to: to)
            return
        }
        if let elNT = find("protocolCompositionElement", in: spans) {
            elements.append(CompositionTypeElementSyntax(
                type: convertType(elNT.nt, from: elNT.from, to: elNT.to)
            ))
        }
        if let contNT = find("protocolCompositionContinuation", in: spans),
           let (_, contSpans) = tileAlternate(contNT.nt, from: contNT.from, to: contNT.to) {
            if let nestedNT = find("protocolCompositionType", in: contSpans) {
                collectCompositionElements(nestedNT.nt, from: nestedNT.from, to: nestedNT.to, into: &elements)
            } else if let lastNT = find("protocolCompositionElement", in: contSpans) {
                elements.append(CompositionTypeElementSyntax(
                    type: convertType(lastNT.nt, from: lastNT.from, to: lastNT.to)
                ))
            }
        }
    }

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
        // SE-0470 trailing comma, kept on the LAST element.
        if hasTrailingComma(spans, afterList: "tupleTypeElementList"), !elements.isEmpty {
            elements[elements.count - 1] = elements[elements.count - 1]
                .with(\.trailingComma, .commaToken())
        }
        return TypeSyntax(TupleTypeSyntax(
            leftParen: .leftParenToken(),
            elements: TupleTypeElementListSyntax(elements),
            rightParen: .rightParenToken()
        ))
    }

    private mutating func collectTupleTypeElements(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into elements: inout [TupleTypeElementSyntax]) {
        let list = NTSpan(nt: nt, from: from, to: to)
        for elNT in collectListElements(named: "tupleTypeElement", in: list, recursiveListName: "tupleTypeElementList") {
            appendTupleTypeElement(elNT, into: &elements)
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
            if let listNT = find("functionTypeArgumentList", in: clauseSpans) {
                collectFunctionTypeArguments(listNT.nt, from: listNT.from, to: listNT.to, into: &parameters)
            }
            // functionTypeArgumentClause = "(" functionTypeArgumentList "..."? ","? ")" .
            // The `...` sits after the list in the grammar but belongs to the LAST element.
            if spansContainKeyword(clauseSpans, "..."), !parameters.isEmpty {
                parameters[parameters.count - 1] = parameters[parameters.count - 1]
                    .with(\.ellipsis, .ellipsisToken())
            }
            // SE-0470 trailing comma, likewise on the last element.
            if hasTrailingComma(clauseSpans, afterList: "functionTypeArgumentList"), !parameters.isEmpty {
                parameters[parameters.count - 1] = parameters[parameters.count - 1]
                    .with(\.trailingComma, .commaToken())
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
        let throwsClause = throwsClauseSyntax(in: spans)
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
        let list = NTSpan(nt: nt, from: from, to: to)
        for argNT in collectListElements(named: "functionTypeArgument", in: list, recursiveListName: "functionTypeArgumentList") {
            guard let (_, argSpans) = tileAlternate(argNT.nt, from: argNT.from, to: argNT.to) else {
                record(.lookupFailed, "no alternate tiles the span", from: argNT.from, to: argNT.to)
                continue
            }
            if let taNT = find("typeAnnotation", in: argSpans),
               let (_, taSpans) = tileAlternate(taNT.nt, from: taNT.from, to: taNT.to),
               let typeNT = find("type", in: taSpans) {
                let ext = find("externalArgumentLabel", in: argSpans)
                let local = find("localArgumentLabel", in: argSpans)
                var first: TokenSyntax? = nil
                var second: TokenSyntax? = nil
                // `(_ borrowing: Int)` — the two-name form needs the wildcard mapping too.
                if let ext, let local {
                    first = parameterNameToken(ext)
                    second = parameterNameToken(local)
                } else if let only = local ?? ext {
                    first = parameterNameToken(only)
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
        if hasTrailingComma(spans, afterList: "genericArgumentList"), !args.isEmpty {
            args[args.count - 1] = args[args.count - 1].with(\.trailingComma, .commaToken())
        }
        return GenericArgumentClauseSyntax(
            leftAngle: .leftAngleToken(),
            arguments: GenericArgumentListSyntax(args),
            rightAngle: .rightAngleToken()
        )
    }

    /// genericArgument = type | signedIntegerLiteral .
    ///
    /// `GenericArgument.Argument` is a type/expression CHOICE, which is where the integer form of
    /// SE-0453 belongs — a value generic argument is an expression, not a type spelled with digits.
    private mutating func genericArgument(_ span: NTSpan) -> GenericArgumentSyntax? {
        guard let (_, spans) = tileAlternate(span.nt, from: span.from, to: span.to) else {
            record(.lookupFailed, "no alternate tiles the span", from: span.from, to: span.to)
            return nil
        }
        if let typeNT = find("type", in: spans) {
            return GenericArgumentSyntax(
                argument: .type(convertType(typeNT.nt, from: typeNT.from, to: typeNT.to))
            )
        }
        if let litNT = find("signedIntegerLiteral", in: spans) {
            return GenericArgumentSyntax(argument: .expr(ExprSyntax(IntegerLiteralExprSyntax(
                literal: .integerLiteral(collectTerminalText(litNT.nt, from: litNT.from, to: litNT.to))
            ))))
        }
        record(.unhandled, "generic argument form has no converter: \(alternateKind(spans))",
               from: span.from, to: span.to)
        return nil
    }

    private mutating func collectGenericArguments(_ nt: GrammarNode, from: CharPosition, to: CharPosition, into args: inout [GenericArgumentSyntax]) {
        let list = NTSpan(nt: nt, from: from, to: to)
        for gaNT in collectListElements(named: "genericArgument", in: list, recursiveListName: "genericArgumentList") {
            if let argument = genericArgument(gaNT) {
                args.append(argument)
            }
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
        // typeName = hardIdentifier | selfType | moduleSelector identifier ---( "_" ) .
        // The qualified form's TEXT is `Swift::Equatable`, so the selector has to be read as its
        // own node — IdentifierType and MemberType both carry one.
        var selector: ModuleSelectorSyntax? = nil
        var text = collectTerminalText(nameNT.nt, from: nameNT.from, to: nameNT.to)
        if text.contains("::"),
           let (_, nameSpans) = tileAlternate(nameNT.nt, from: nameNT.from, to: nameNT.to) {
            selector = moduleSelector(in: nameSpans)
            if let cut = text.range(of: "::") { text = String(text[cut.upperBound...]) }
        }
        // `Self` is a keyword token only as a LEADING IdentifierType. As a MemberType's NAME
        // (`A.Self`) and after a `::` it is a plain identifier — the same position-dependence as
        // in `derivativeNameType`.
        let isMember = find("typeIdentifier", in: spans) != nil
        let name: TokenSyntax = (text == "Self" && selector == nil && !isMember)
            ? .keyword(.Self) : .identifier(text)

        var generics: GenericArgumentClauseSyntax? = nil
        if let gNT = find(firstOf: ["typeGenericArgumentClause", "genericArgumentClause"], in: spans) {
            generics = convertGenericArgumentClause(gNT.nt, from: gNT.from, to: gNT.to)
        }

        if let baseNT = find("typeIdentifier", in: spans) {
            return TypeSyntax(MemberTypeSyntax(
                baseType: convertTypeIdentifier(baseNT.nt, from: baseNT.from, to: baseNT.to),
                period: .periodToken(),
                moduleSelector: selector,
                name: name,
                genericArgumentClause: generics
            ))
        }
        return TypeSyntax(IdentifierTypeSyntax(
            moduleSelector: selector, name: name, genericArgumentClause: generics
        ))
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
