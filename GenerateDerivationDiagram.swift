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
    let from: Int
    let to: Int
    var children: [ParseTreeNode] = []
    var isTerminal: Bool { token != nil }
    
    init(name: String, from: Int, to: Int, token: Token? = nil) {
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
    
    init(grammar: Grammar, tokens: [Token]) {
        self.grammar = grammar
        self.tokens = tokens
    }
    
    /// Entry point: build all parse trees rooted at the grammar's start symbol.
    func buildAllTrees(limit: Int = 10) -> [ParseTreeNode] {
        let n = tokens.count - 1
        guard grammar.root.yield.contains(where: { $0.i == 0 && $0.j == n }) else { return [] }
        return buildNonterminalTrees(grammar.root, from: 0, to: n, limit: limit)
    }
    
    // MARK: - Tree Construction
    
    /// Build all parse trees for a nonterminal over [from, to].
    /// Each tree is a ParseTreeNode whose children come from expanding one alternate.
    private func buildNonterminalTrees(_ nt: GrammarNode, from: Int, to: Int, limit: Int) -> [ParseTreeNode] {
        expandAlternates(nt, from: from, to: to, limit: limit).map { children in
            let node = ParseTreeNode(name: nt.name, from: from, to: to)
            node.children = children
            return node
        }
    }
    
    /// Walk the alternate chain of a grammar node (nonterminal or bracket),
    /// expanding each alternate's body over [from, to].
    /// Returns child lists — each list is one valid way to fill the span.
    private func expandAlternates(_ node: GrammarNode, from: Int, to: Int, limit: Int) -> [[ParseTreeNode]] {
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
    private func expandBody(_ symbols: [GrammarNode], from: Int, to: Int, limit: Int) -> [[ParseTreeNode]] {
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
    private func buildSymbolChildren(_ sym: GrammarNode, from: Int, to: Int, limit: Int) -> [[ParseTreeNode]] {
        switch sym.kind {
        case .T, .TI, .C, .B:
            return [[ParseTreeNode(name: sym.name, from: from, to: to, token: tokens[from])]]
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
    
    /// Chain bracket iterations over [from, to], returning flat child lists.
    /// EBNF brackets are transparent in the parse tree — no bracket node appears.
    /// Instead, each iteration's body symbols are expanded and concatenated as siblings.
    /// For closures (KLN/POS), iterations chain forward: [from,k₁] + [k₁,k₂] + ... + [kₙ,to].
    private func expandIterations(_ bracket: GrammarNode, from: Int, to: Int, limit: Int) -> [[ParseTreeNode]] {
        if from == to { return [[]] }
        var results: [[ParseTreeNode]] = []
        // Each BSR span (i, k=iterStart, j=iterEnd) in the bracket's yield
        // records one iteration boundary.
        for span in bracket.yield where span.k == from && span.j <= to {
            guard results.count < limit else { break }
            let iterContent = expandAlternates(bracket, from: from, to: span.j, limit: limit - results.count)
            if span.j == to {
                // Last (or only) iteration reaches the target — done.
                results.append(contentsOf: iterContent)
            } else if bracket.kind.isClosure {
                // More iterations follow — recurse for the tail [span.j, to].
                for head in iterContent {
                    guard results.count < limit else { break }
                    for tail in expandIterations(bracket, from: span.j, to: to, limit: limit - results.count) {
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
    ///   - Brackets: follow the iteration chain (k→j) through the bracket's yield.
    ///     For closures (KLN/POS), chain through multiple iterations via BFS.
    ///     Nullable brackets (KLN/OPT) also include `from` itself (empty match).
    ///   - Epsilon: matches only at `from` (empty span).
    private func endPositions(_ symbol: GrammarNode, from: Int) -> Set<Int> {
        switch symbol.kind {
        case .T, .TI, .C, .B:
            guard from < tokens.count - 1 else { return [] }
            var tok = tokens[from]
            repeat {
                if tok.kind == symbol.name { return [from + 1] }
                guard let next = tok.dual else { return [] }
                tok = next
            } while true
        case .N:
            guard let lhs = symbol.alt else { return [] }
            var positions: Set<Int> = []
            for span in lhs.yield where span.i == from { positions.insert(span.j) }
            return positions
        case .DO, .OPT, .KLN, .POS:
            var positions: Set<Int> = []
            if symbol.kind == .KLN || symbol.kind == .OPT { positions.insert(from) }
            var visited: Set<Int> = []
            var queue = [from]
            while !queue.isEmpty {
                let pos = queue.removeFirst()
                guard visited.insert(pos).inserted else { continue }
                for span in symbol.yield where span.k == pos {
                    positions.insert(span.j)
                    if symbol.kind.isClosure { queue.append(span.j) }
                }
            }
            return positions
        case .EPS:
            return [from]
        default:
            return []
        }
    }
}

// MARK: - Graphviz Rendering

/// Generate a Graphviz dot file visualizing parse trees as a classic syntax tree diagram.
/// Nonterminals are drawn as ellipses, terminals as boxes with the token text.
/// For ambiguous grammars, each derivation is shown in a separate subgraph cluster.
func generateDerivationDiagram(outputFile file: URL, grammar: Grammar, tokens: [Token]) throws {
    let trees = DerivationBuilder(grammar: grammar, tokens: tokens).buildAllTrees()
    guard !trees.isEmpty else { return }
    
    var dot = """
    digraph Derivations {
      fontname = Menlo
      fontsize = 10
      node [fontname = Menlo, fontsize = 10]
      edge [arrowsize = 0.5]
      rankdir = TB
      ordering = out
      labelloc = t
      label = <\(grammar.root.ebnf().graphvizHTML)>
    
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
    var terminals: [(id: String, pos: Int)] = []
    
    func emit(_ node: ParseTreeNode) -> String {
        let id = "\(prefix)n\(n)"; n += 1
        if node.isTerminal {
            dot += "  \(id) [shape = box, width=0.0, height=0.0, label = <\(String(node.token!.image).graphvizHTML)>]\n"
            terminals.append((id, node.from))
        } else {
            dot += "  \(id) [shape = ellipse, width=0.0, height=0.0, label = <\(node.name.graphvizHTML)>]\n"
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
