//
//  GenerateDerivationDiagram.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.22.
//

import Foundation
import OSLog

// MARK: - Parse Tree Node

class ParseTreeNode: CustomStringConvertible {
    let name: String
    /// Source slice covered by this node when it's a leaf (terminal or
    /// boundary). `nil` for non-terminal interior nodes — those are described
    /// by their children. Replaces the old `token: Token?` field that
    /// indirected through the scanner-produced token array.
    let image: Substring?
    let from: CharPosition
    let to: CharPosition
    var children: [ParseTreeNode] = []
    var isAmbiguous = false
    var isMissing = false
    var isTerminal: Bool { image != nil }

    init(_ name: String, from: CharPosition, to: CharPosition, image: Substring? = nil) {
        self.name = name
        self.image = image
        self.from = from
        self.to = to
    }

    var description: String {
        if let image { return "\(name)(\"\(image)\")" }
        if isMissing { return "\(name) <missing>" }
        return "\(name)[\(children.count)]"
    }

    func dump(indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        if isMissing { return "\(pad)\(name) <missing>\n" }
        if let image {
            if image.isEmpty { return "\(pad)\(name)\n" }
            return "\(pad)\(name) \"\(image)\"\n"
        }
        var result = "\(pad)\(name)\n"
        for child in children {
            result += child.dump(indent: indent + 1)
        }
        return result
    }
}

// MARK: - Derivation Builder

/// Builds concrete parse trees from BSR yield evidence on GrammarNodes.
/// EBNF brackets are transparent — their contents are inlined as direct children.
class DerivationBuilder {
    let parser: MessageParser
    let grammar: Grammar
    let input: String

    private var expanding = Set<NodeSpan>()
    private var endCache = [NodePos: Set<CharPosition>]()
    private var endGuard = Set<NodePos>()

    private struct NodeSpan: Hashable { let id: ObjectIdentifier; let from, to: CharPosition }
    private struct NodePos: Hashable  { let id: ObjectIdentifier; let from: CharPosition }

    init(parser: MessageParser, input: String) {
        self.parser = parser
        self.grammar = parser.grammar
        self.input = input
    }

    func buildAllTrees(limit: Int = 10) -> [ParseTreeNode] {
        let n = input.endIndex
        let origin = input.startIndex
        guard parser.yield(of: grammar.root).contains(where: { $0.i == origin && $0.j == n }) else { return [] }
        return treesFor(grammar.root, from: origin, to: n, limit: limit)
    }

    // MARK: Tree Construction

    private func treesFor(_ nt: GrammarNode, from: CharPosition, to: CharPosition, limit: Int) -> [ParseTreeNode] {
        let key = NodeSpan(id: ObjectIdentifier(nt), from: from, to: to)
        guard expanding.insert(key).inserted else { return [] }
        defer { expanding.remove(key) }

        let expansions = expandAlternates(nt, from: from, to: to, limit: limit)
        let skeletons = Set(expansions.map { $0.map { "\($0.name)/\($0.from)/\($0.to)" }.joined(separator: "|") })
        let ambiguous = skeletons.count > 1
        return expansions.map { children in
            let node = ParseTreeNode(nt.name, from: from, to: to)
            node.children = children
            node.isAmbiguous = ambiguous
            return node
        }
    }

    /// Walk alternates of a node, tile each body over [from, to].
    private func expandAlternates(_ node: GrammarNode, from: CharPosition, to: CharPosition, limit: Int) -> [[ParseTreeNode]] {
        var results = [[ParseTreeNode]]()
        var alt = node.alt
        while let a = alt {
            defer { alt = a.alt }
            guard results.count < limit else { break }
            let body = a.bodySymbols.filter { $0.kind != .EPS }
            if body.isEmpty {
                if from == to { results.append([]) }
            } else {
                results.append(contentsOf: tileBody(body, from: from, to: to, limit: limit - results.count))
            }
        }
        return results
    }

    /// Tile body symbols left-to-right using BSR end positions as split points.
    private func tileBody(_ symbols: [GrammarNode], from: CharPosition, to: CharPosition, limit: Int) -> [[ParseTreeNode]] {
        guard let first = symbols.first else { return from == to ? [[]] : [] }
        let rest = Array(symbols.dropFirst())
        var results = [[ParseTreeNode]]()
        for mid in endPositions(first, from: from) where mid <= to {
            guard results.count < limit else { break }
            for head in symbolChildren(first, from: from, to: mid, limit: limit) {
                guard results.count < limit else { break }
                for tail in tileBody(rest, from: mid, to: to, limit: limit - results.count) {
                    guard results.count < limit else { break }
                    results.append(head + tail)
                }
            }
        }
        return results
    }

    /// Build children for one symbol. Brackets are transparent (contents inlined as siblings).
    private func symbolChildren(_ sym: GrammarNode, from: CharPosition, to: CharPosition, limit: Int) -> [[ParseTreeNode]] {
        switch sym.kind {
        case .T, .TI, .C:
            // Exact grammar-defined content of this terminal; falls back to
            // the BSR span (which includes trailing trivia) if no commit is
            // recorded — shouldn't happen in well-formed parses.
            let image = parser.terminalImage(startingAt: from) ?? input[from..<to]
            return [[ParseTreeNode(sym.name, from: from, to: to, image: image)]]
        case .B:
            // Boundary: zero-length predicate; no source content.
            return [[ParseTreeNode(sym.name, from: from, to: to, image: input[from..<from])]]
        case .N:
            guard let lhs = sym.alt else { return [] }
            return treesFor(lhs, from: from, to: to, limit: limit).map { [$0] }
        case .DO, .OPT, .KLN, .POS:
            let r = expandIterations(sym, from: from, to: to, limit: limit)
            return r.isEmpty && (sym.kind == .KLN || sym.kind == .OPT) ? [[]] : r
        default:
            return [[]]
        }
    }

    /// Chain bracket iterations over [from, to]. Closures recurse for additional iterations.
    private func expandIterations(_ bracket: GrammarNode, from: CharPosition, to: CharPosition, limit: Int) -> [[ParseTreeNode]] {
        if from == to { return [[]] }
        var results = [[ParseTreeNode]]()
        for end in iterationEndPositions(bracket, from: from) where end <= to && end > from {
            guard results.count < limit else { break }
            for head in expandAlternates(bracket, from: from, to: end, limit: limit - results.count) {
                guard results.count < limit else { break }
                if end == to {
                    results.append(head)
                } else if bracket.kind.isClosure {
                    for tail in expandIterations(bracket, from: end, to: to, limit: limit - results.count) {
                        guard results.count < limit else { break }
                        results.append(head + tail)
                    }
                }
            }
        }
        return results
    }

    // MARK: - Single Deterministic AST

    struct Diagnostic: CustomStringConvertible {
        let message: String
        let node: String
        let from: CharPosition
        let to: CharPosition
        let candidateCount: Int

        var description: String {
            "\(node) [\(from)..\(to)]: \(message) (\(candidateCount) candidates)"
        }
    }

    private(set) var diagnostics: [Diagnostic] = []

    func buildAST() -> ParseTreeNode? {
        diagnostics = []
        let n = input.endIndex
        let origin = input.startIndex
        guard parser.yield(of: grammar.root).contains(where: { $0.i == origin && $0.j == n }) else {
            Logger.ui.warning("AST: no complete parse found")
            return nil
        }
        let root = buildASTNode(grammar.root, from: origin, to: n)
        if !diagnostics.isEmpty {
            Logger.ui.warning("AST: \(self.diagnostics.count, privacy: .public) residual ambiguities")
            for d in diagnostics {
                Logger.ui.warning("  \(d.description, privacy: .public)")
            }
        }
        return root
    }

    private func buildASTNode(_ nt: GrammarNode, from: CharPosition, to: CharPosition) -> ParseTreeNode {
        let key = NodeSpan(id: ObjectIdentifier(nt), from: from, to: to)
        guard expanding.insert(key).inserted else {
            let node = ParseTreeNode(nt.name, from: from, to: to)
            node.isMissing = true
            return node
        }
        defer { expanding.remove(key) }

        let node = ParseTreeNode(nt.name, from: from, to: to)
        node.children = buildASTAlternate(nt, from: from, to: to)
        return node
    }

    private func buildASTAlternate(_ node: GrammarNode, from: CharPosition, to: CharPosition) -> [ParseTreeNode] {
        var candidates: [(alt: GrammarNode, children: [ParseTreeNode])] = []
        var alt = node.alt
        while let a = alt {
            defer { alt = a.alt }
            let body = a.bodySymbols.filter { $0.kind != .EPS }
            if body.isEmpty {
                if from == to { candidates.append((a, [])) }
            } else if let tiled = tileASTBody(body, from: from, to: to) {
                candidates.append((a, tiled))
            }
        }

        if candidates.count > 1 {
            diagnostics.append(Diagnostic(
                message: "ambiguous alternate",
                node: node.name,
                from: from, to: to,
                candidateCount: candidates.count
            ))
        }

        return candidates.first?.children ?? []
    }

    private func tileASTBody(_ symbols: [GrammarNode], from: CharPosition, to: CharPosition) -> [ParseTreeNode]? {
        guard let first = symbols.first else { return from == to ? [] : nil }
        let rest = Array(symbols.dropFirst())

        var candidates: [ParseTreeNode]? = nil
        var candidateCount = 0

        for mid in endPositions(first, from: from) where mid <= to {
            guard let head = buildASTSymbol(first, from: from, to: mid) else { continue }
            guard let tail = tileASTBody(rest, from: mid, to: to) else { continue }
            if candidateCount == 0 {
                candidates = [head] + tail
            }
            candidateCount += 1
        }

        if candidateCount > 1 {
            diagnostics.append(Diagnostic(
                message: "ambiguous pivot",
                node: symbols.first?.name ?? "?",
                from: from, to: to,
                candidateCount: candidateCount
            ))
        }

        return candidates
    }

    private func buildASTSymbol(_ sym: GrammarNode, from: CharPosition, to: CharPosition) -> ParseTreeNode? {
        switch sym.kind {
        case .T, .TI, .C:
            let image = parser.terminalImage(startingAt: from) ?? input[from..<to]
            return ParseTreeNode(sym.name, from: from, to: to, image: image)

        case .B:
            // Boundary: zero-length predicate; no source content.
            return ParseTreeNode(sym.name, from: from, to: to, image: input[from..<from])

        case .N:
            guard let lhs = sym.alt else { return nil }
            return buildASTNode(lhs, from: from, to: to)

        case .DO, .OPT, .KLN, .POS:
            return buildASTBracket(sym, from: from, to: to)

        default:
            return nil
        }
    }

    private func buildASTBracket(_ bracket: GrammarNode, from: CharPosition, to: CharPosition) -> ParseTreeNode? {
        let node = ParseTreeNode(bracket.name, from: from, to: to)
        if from == to { return node }

        if !bracket.kind.isClosure {
            node.children.append(contentsOf: buildASTAlternate(bracket, from: from, to: to))
            return node
        }

        var pos = from
        while pos < to {
            let ends = iterationEndPositions(bracket, from: pos).filter { $0 > pos && $0 <= to }
            if ends.isEmpty { break }

            if ends.count > 1 {
                diagnostics.append(Diagnostic(
                    message: "ambiguous iteration extent",
                    node: bracket.name,
                    from: pos, to: to,
                    candidateCount: ends.count
                ))
            }

            let end = ends.min()!
            node.children.append(contentsOf: buildASTAlternate(bracket, from: pos, to: end))
            pos = end
        }
        return node
    }

    // MARK: - BSR End Position Queries

    private func endPositions(_ sym: GrammarNode, from: CharPosition) -> Set<CharPosition> {
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
                while !queue.isEmpty {
                    let pos = queue.removeFirst()
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

    /// End positions after exactly one bracket iteration, computed by chaining
    /// end positions through each alternate's body symbols.
    private func iterationEndPositions(_ bracket: GrammarNode, from: CharPosition) -> Set<CharPosition> {
        var positions = Set<CharPosition>()
        var alt = bracket.alt
        while let a = alt {
            let body = a.bodySymbols.filter { $0.kind != .EPS }
            if body.isEmpty {
                positions.insert(from)
            } else {
                var frontier: Set<CharPosition> = [from]
                for sym in body {
                    frontier = frontier.reduce(into: Set()) { $0.formUnion(endPositions(sym, from: $1)) }
                    if frontier.isEmpty { break }
                }
                positions.formUnion(frontier)
            }
            alt = a.alt
        }
        return positions
    }
}

// MARK: - Graphviz Rendering

func generateDerivationDiagram(outputFile file: URL, parser: MessageParser, input: String) throws {
    let trees = DerivationBuilder(parser: parser, input: input).buildAllTrees()
    let title = parser.grammar.root.ebnf().graphvizHTML

    guard !trees.isEmpty else {
        try """
        digraph Derivations {
          fontname=Menlo; fontsize=10; node [fontname=Menlo, fontsize=10]
          labelloc=t; label=<\(title)>
          n [shape=box, label=<No derivations>]
        }
        """.write(to: file, atomically: true, encoding: .utf8)
        return
    }

    var dot = """
    digraph Derivations {
      fontname=Menlo; fontsize=10
      node [fontname=Menlo, fontsize=10]
      edge [arrowsize=0.5]
      rankdir=TB; ordering=out; labelloc=t
      label=<\(title)>

    """

    if trees.count > 1 {
        for (i, tree) in trees.enumerated() {
            dot += "  subgraph cluster_\(i) {\n"
            dot += "    label=\"Derivation \(i + 1)\"; style=dashed\n"
            dot += renderTree(tree, prefix: "d\(i)_")
            dot += "  }\n\n"
        }
    } else {
        dot += renderTree(trees[0], prefix: "")
    }

    dot += "}\n"
    try dot.write(to: file, atomically: true, encoding: .utf8)
}

/// Render a parse tree as Graphviz nodes and edges.
/// Terminal leaves are aligned at the bottom with invisible ordering edges.
private func renderTree(_ tree: ParseTreeNode, prefix: String) -> String {
    var dot = ""
    var n = 0
    var leaves: [(id: String, pos: CharPosition)] = []

    func emit(_ node: ParseTreeNode) -> String {
        let id = "\(prefix)n\(n)"; n += 1
        if node.isTerminal {
            let image = String(node.image!)
            if image.isEmpty {
                dot += "  \(id) [shape=box, width=0, height=0, color=gray50, fontcolor=gray50, label=<\(node.name.graphvizHTML)>]\n"
            } else {
                dot += "  \(id) [shape=box, width=0, height=0, label=<\(image.graphvizHTML)>]\n"
            }
            leaves.append((id, node.from))
        } else {
            let extra = node.isAmbiguous ? ", color=red, penwidth=2.0" : ""
            dot += "  \(id) [shape=ellipse, width=0, height=0, label=<\(node.name.graphvizHTML)>\(extra)]\n"
        }
        for child in node.children { dot += "  \(id) -> \(emit(child))\n" }
        return id
    }

    _ = emit(tree)

    let sorted = leaves.sorted { $0.pos < $1.pos }
    if sorted.count > 1 {
        dot += "  { rank=same; \(sorted.map(\.id).joined(separator: "; ")) }\n"
        for i in 0..<sorted.count - 1 {
            dot += "  \(sorted[i].id) -> \(sorted[i + 1].id) [style=invis]\n"
        }
    }
    return dot
}
