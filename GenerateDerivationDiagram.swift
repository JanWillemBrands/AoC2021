//
//  GenerateDerivationDiagram.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.22.
//

import Foundation

// MARK: - Parse Tree Node

class ParseTreeNode {
    let name: String
    let token: Token?             // non-nil for terminal leaves
    let from: TokenPosition
    let to: TokenPosition
    var children: [ParseTreeNode] = []
    var isTerminal: Bool { token != nil }

    init(name: String, from: TokenPosition, to: TokenPosition, token: Token? = nil) {
        self.name = name
        self.from = from
        self.to = to
        self.token = token
    }
}

// MARK: - Derivation Builder

/// Builds concrete parse trees directly from the BSR (Binary Subtree Representation)
/// yield set produced by the GLL parser. Each GrammarNode carries its own yield
/// (a set of BinarySpan(i,k,j) triples recording which spans it matched).
///
/// The algorithm works by recursive descent over the grammar structure:
///   1. Start from the root nonterminal spanning the full input.
///   2. For each nonterminal, try each alternate's body symbols.
///   3. Tile the body symbols left-to-right over the span using `endPositions`
///      to find valid split points from the BSR evidence.
///   4. Terminals become leaf nodes; nonterminals recurse; EBNF brackets
///      (groups, options, closures) are transparent — their iteration content
///      is inlined as direct children of the enclosing nonterminal.
///
/// For ambiguous grammars, multiple trees are returned (up to `limit`).

class DerivationBuilder {
    let grammar: Grammar
    let tokens: [Token]
    
    /// Tracks active nonterminal expansions on the current call path to break cycles.
    private var activeExpansions: Set<ExpansionKey> = []
    
    private struct ExpansionKey: Hashable {
        let node: ObjectIdentifier
        let from: TokenPosition
        let to: TokenPosition
    }

    /// Memo key for end-position queries.
    private struct EndKey: Hashable {
        let node: ObjectIdentifier
        let from: TokenPosition
    }

    /// Cache of end positions for (symbol, from) queries.
    private var endPositionsMemo: [EndKey: Set<TokenPosition>] = [:]
    /// Recursion guard for end-position queries to prevent cycles.
    private var activeEndQueries: Set<EndKey> = []
    
    init(grammar: Grammar, tokens: [Token]) {
        self.grammar = grammar
        self.tokens = tokens
    }
    
    /// Entry point: build all parse trees rooted at the grammar's start symbol.
    func buildAllTrees(limit: Int = 10) -> [ParseTreeNode] {
        let n = TokenPosition(token: tokens.count - 1)
        guard grammar.root.yield.contains(where: { $0.i == .zero && $0.j == n }) else { return [] }
        return buildNonterminalTrees(grammar.root, from: .zero, to: n, limit: limit)
    }
    
    // MARK: - Tree Construction
    
    /// Build all parse trees for a nonterminal over [from, to].
    /// Each tree is a ParseTreeNode whose children come from expanding one alternate.
    private func buildNonterminalTrees(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition, limit: Int) -> [ParseTreeNode] {
        let key = ExpansionKey(node: ObjectIdentifier(nt), from: from, to: to)
        guard activeExpansions.insert(key).inserted else { return [] }
        defer { activeExpansions.remove(key) }
        
        return expandAlternates(nt, from: from, to: to, limit: limit).map { children in
            let node = ParseTreeNode(name: nt.name, from: from, to: to)
            node.children = children
            return node
        }
    }
    
    /// Walk the alternate chain of a grammar node (nonterminal or bracket),
    /// expanding each alternate's body over [from, to].
    /// Returns child lists — each list is one valid way to fill the span.
    private func expandAlternates(_ node: GrammarNode, from: TokenPosition, to: TokenPosition, limit: Int) -> [[ParseTreeNode]] {
        var results: [[ParseTreeNode]] = []
        var altNode = node.alt
        while let alt = altNode {
            defer { altNode = alt.alt }
            guard results.count < limit else { break }
            let symbols = alt.bodySymbols.filter { $0.kind != .EPS }
            if symbols.isEmpty {
                if from == to { results.append([]) }
                continue
            }
            results.append(contentsOf: expandBody(symbols, from: from, to: to, limit: limit - results.count))
        }
        return results
    }
    
    /// Expand a sequence of body symbols over [from, to] by scanning left-to-right.
    /// For each symbol, `endPositions` provides the valid split points from BSR evidence.
    /// The cross-product of all symbol positions is computed inline through recursion.
    private func expandBody(_ symbols: [GrammarNode], from: TokenPosition, to: TokenPosition, limit: Int) -> [[ParseTreeNode]] {
        guard let first = symbols.first else {
            return from == to ? [[]] : []
        }
        let rest = Array(symbols.dropFirst())
        var results: [[ParseTreeNode]] = []
        for mid in endPositions(first, from: from) where mid <= to {
            guard results.count < limit else { break }
            for children in buildSymbolChildren(first, from: from, to: mid, limit: limit) {
                guard results.count < limit else { break }
                for restChildren in expandBody(rest, from: mid, to: to, limit: limit - results.count) {
                    guard results.count < limit else { break }
                    results.append(children + restChildren)
                }
            }
        }
        return results
    }
    
    /// Build child nodes for a single grammar symbol over [from, to].
    /// Returns options of sibling-lists:
    ///   - Terminal: one option with one leaf node
    ///   - Nonterminal: one option per ambiguous parse, each containing one subtree
    ///   - Bracket: one option per interpretation, each a flat list of inlined children
    ///   - EPS: one option with zero children
    private func buildSymbolChildren(_ sym: GrammarNode, from: TokenPosition, to: TokenPosition, limit: Int) -> [[ParseTreeNode]] {
        switch sym.kind {
        case .T, .TI, .C:
            guard tokens.indices.contains(from.tokenIndex) else { return [] }
            return [[ParseTreeNode(name: sym.name, from: from, to: to, token: tokens[from.tokenIndex])]]
        case .B:
            return [[ParseTreeNode(name: sym.name, from: from, to: to, token: emptyMarkerToken(at: from, kind: sym.name))]]
        case .N:
            guard let lhs = sym.alt else { return [] }
            return buildNonterminalTrees(lhs, from: from, to: to, limit: limit).map { [$0] }
        case .DO, .OPT, .KLN, .POS:
            let lists = expandIterations(sym, from: from, to: to, limit: limit)
            return lists.isEmpty && (sym.kind == .KLN || sym.kind == .OPT) ? [[]] : lists
        case .EPS:
            return [[]]
        default:
            return [[]]
        }
    }

    /// Create a zero-width marker token anchored in the source input for display-only leaves.
    private func emptyMarkerToken(at position: TokenPosition, kind: String) -> Token? {
        guard !tokens.isEmpty else { return nil }
        let clamped = max(0, min(position.tokenIndex, tokens.count - 1))
        let anchor = tokens[clamped]
        let base = anchor.image.base
        let idx = anchor.image.startIndex
        return Token(image: base[idx..<idx], kind: kind)
    }
    
    /// Chain bracket iterations over [from, to], returning flat child lists.
    /// EBNF brackets are transparent in the parse tree — no bracket node appears.
    /// Instead, each iteration's body symbols are expanded and concatenated as siblings.
    /// Iteration boundaries are inferred from alternate-body end positions, not directly
    /// from `bracket.yield.k` (which may not encode user-visible iteration starts).
    private func expandIterations(_ bracket: GrammarNode, from: TokenPosition, to: TokenPosition, limit: Int) -> [[ParseTreeNode]] {
        if from == to { return [[]] }
        var results: [[ParseTreeNode]] = []
        // Compute one-iteration end points from bracket alternates.
        for end in oneIterationEndPositions(for: bracket, from: from) where end <= to {
            guard results.count < limit else { break }
            let iterContent = expandAlternates(bracket, from: from, to: end, limit: limit - results.count)
            if end == to {
                // Last (or only) iteration reaches the target — done.
                results.append(contentsOf: iterContent)
            } else if bracket.kind.isClosure {
                // Closure chaining must advance; nullable loop bodies can produce
                // zero-length spans (j == from), which would recurse forever.
                guard end > from else { continue }
                // More iterations follow — recurse for the tail [span.j, to].
                for head in iterContent {
                    guard results.count < limit else { break }
                    for tail in expandIterations(bracket, from: end, to: to, limit: limit - results.count) {
                        guard results.count < limit else { break }
                        results.append(head + tail)
                    }
                }
            }
        }
        return results
    }
    
    // MARK: - BSR Helpers
    
    /// All valid end positions for a symbol starting at `from`, derived from BSR evidence.
    /// This is the key function that connects the grammar structure to the parse evidence:
    ///   - Terminals: span exactly one token (from → from+1) if the token kind matches.
    ///   - Nonterminals: the LHS node's yield gives all spans starting at `from`.
    ///   - Brackets: compute one-iteration ends from alternate bodies, then:
    ///     DO/OPT use one step; KLN/POS take transitive closure over repeated steps.
    ///     Nullable brackets (KLN/OPT) also include `from` itself (empty match).
    ///   - Epsilon: matches only at `from` (empty span).
    private func endPositions(_ symbol: GrammarNode, from: TokenPosition) -> Set<TokenPosition> {
        let key = EndKey(node: ObjectIdentifier(symbol), from: from)
        if let cached = endPositionsMemo[key] { return cached }
        guard activeEndQueries.insert(key).inserted else { return [] }
        defer { activeEndQueries.remove(key) }

        let result: Set<TokenPosition>
        switch symbol.kind {
        case .T, .TI, .C, .B:
            var positions: Set<TokenPosition> = []
            for span in symbol.yield where span.k == from { positions.insert(span.j) }
            result = positions
        case .N:
            guard let lhs = symbol.alt else { return [] }
            var positions: Set<TokenPosition> = []
            for span in lhs.yield where span.i == from { positions.insert(span.j) }
            result = positions
        case .DO, .OPT, .KLN, .POS:
            var positions: Set<TokenPosition> = []
            if symbol.kind == .KLN || symbol.kind == .OPT { positions.insert(from) }
            if symbol.kind.isClosure {
                // Closure: transitively chain one-iteration matches.
                var visited: Set<TokenPosition> = []
                var queue = [from]
                while !queue.isEmpty {
                    let pos = queue.removeFirst()
                    guard visited.insert(pos).inserted else { continue }
                    for end in oneIterationEndPositions(for: symbol, from: pos) {
                        positions.insert(end)
                        if end > pos { queue.append(end) }
                    }
                }
            } else {
                // DO/OPT: single iteration only.
                positions.formUnion(oneIterationEndPositions(for: symbol, from: from))
            }
            result = positions
        case .EPS:
            result = [from]
        default:
            result = []
        }
        endPositionsMemo[key] = result
        return result
    }

    /// End positions for exactly one bracket iteration starting at `from`.
    /// Computed from alternate bodies using recursive end-position chaining.
    private func oneIterationEndPositions(for bracket: GrammarNode, from: TokenPosition) -> Set<TokenPosition> {
        var positions: Set<TokenPosition> = []
        var altNode = bracket.alt
        while let alt = altNode {
            let symbols = alt.bodySymbols.filter { $0.kind != .EPS }
            if symbols.isEmpty {
                positions.insert(from)
            } else {
                positions.formUnion(chainEndPositions(symbols: symbols, from: from))
            }
            altNode = alt.alt
        }
        return positions
    }

    /// All end positions after matching the symbol chain once, starting at `from`.
    private func chainEndPositions(symbols: [GrammarNode], from start: TokenPosition) -> Set<TokenPosition> {
        var frontier: Set<TokenPosition> = [start]
        for symbol in symbols {
            var next: Set<TokenPosition> = []
            for pos in frontier {
                next.formUnion(endPositions(symbol, from: pos))
            }
            if next.isEmpty { return [] }
            frontier = next
        }
        return frontier
    }
}

// MARK: - Graphviz Rendering

/// Generate a Graphviz dot file visualizing parse trees as a classic syntax tree diagram.
/// Nonterminals are drawn as ellipses, terminals as boxes with the token text.
/// For ambiguous grammars, each derivation is shown in a separate subgraph cluster.
func generateDerivationDiagram(outputFile file: URL, grammar: Grammar, tokens: [Token]) throws {
    let trees = DerivationBuilder(grammar: grammar, tokens: tokens).buildAllTrees()
    guard !trees.isEmpty else {
        let dot = """
        digraph Derivations {
          fontname = Menlo
          fontsize = 10
          node [fontname = Menlo, fontsize = 10]
          labelloc = t
          label = <\(grammar.root.ebnf().withLayoutGlyphs.graphvizHTML)>
          noDerivation [shape = box, label = <No derivations for current parse>]
        }
        """
        try dot.write(to: file, atomically: true, encoding: .utf8)
        return
    }
    
    var dot = """
    digraph Derivations {
      fontname = Menlo
      fontsize = 10
      node [fontname = Menlo, fontsize = 10]
      edge [arrowsize = 0.5]
      rankdir = TB
      ordering = out
      labelloc = t
      label = <\(grammar.root.ebnf().withLayoutGlyphs.graphvizHTML)>
    
    """
    
    if trees.count > 1 {
        for (i, tree) in trees.enumerated() {
            dot += "  subgraph cluster_\(i) {\n"
            dot += "    label = \"Derivation \(i + 1)\"\n"
            dot += "    style = dashed\n"
            dot += renderTreeBody(tree, prefix: "d\(i)_")
            dot += "  }\n\n"
        }
    } else {
        dot += renderTreeBody(trees[0], prefix: "")
    }
    
    dot += "}\n"
    try dot.write(to: file, atomically: true, encoding: .utf8)
}

/// Render a single parse tree as Graphviz node/edge declarations.
/// Terminal leaves are forced to the same rank at the bottom with invisible
/// ordering edges to maintain left-to-right reading order.
private func renderTreeBody(_ tree: ParseTreeNode, prefix: String) -> String {
    var dot = ""
    var n = 0
    var terminals: [(id: String, pos: TokenPosition)] = []
    
    func emit(_ node: ParseTreeNode) -> String {
        let id = "\(prefix)n\(n)"; n += 1
        if node.isTerminal {
            let text = String(node.token!.image).isEmpty ? node.name : String(node.token!.image)
            dot += "  \(id) [shape = box, width=0.0, height=0.0, label = <\(text.withLayoutGlyphs.graphvizHTML)>]\n"
            terminals.append((id, node.from))
        } else {
            dot += "  \(id) [shape = ellipse, width=0.0, height=0.0, label = <\(node.name.withLayoutGlyphs.graphvizHTML)>]\n"
        }
        for child in node.children {
            dot += "  \(id) -> \(emit(child))\n"
        }
        return id
    }
    
    _ = emit(tree)
    
    let sorted = terminals.sorted { $0.pos < $1.pos }
    if sorted.count > 1 {
        dot += "  { rank = same; \(sorted.map(\.id).joined(separator: "; ")) }\n"
        for i in 0..<(sorted.count - 1) {
            dot += "  \(sorted[i].id) -> \(sorted[i + 1].id) [style = invis]\n"
        }
    }
    return dot
}
