//
//  GenerateDerivationDiagram.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.22.
//

import Foundation
import AdventMacros

// MARK: - Derivation Node

struct DNode: Hashable {
    let slot: GrammarNode
    let i: Int, k: Int, j: Int
}

// MARK: - BSR Derivation Enumeration

extension MessageParser {
    
    typealias DEdge = (parent: DNode, child: DNode)
    
    /// Enumerate all derivation trees from the BSR set.
    func enumerateBSRDerivations(limit: Int = 10) -> [[DEdge]] {
        let S = grammar.root
        let n = tokens.count - 1
        guard yield.contains(where: { $0.slot == S && $0.i == 0 && $0.j == n }) else { return [] }
        let root = DNode(slot: S, i: 0, k: 0, j: n)
        return expand(root, limit: limit)
    }
    
    /// Expand a node into all its possible derivation subtrees.
    /// Returns a list of derivations, where each derivation is a list of edges
    /// rooted at this node going all the way down to leaves.
    private func expand(_ node: DNode, limit: Int) -> [[DEdge]] {
        let sym = node.slot
        
        // Terminal or epsilon: leaf node, one trivial derivation with no edges
        if [.T, .TI, .C, .B, .EPS].contains(sym.kind) {
            return [[]]
        }
        
        // Nonterminal (LHS): find children from each alternate
        if sym.kind == .N, sym.seq == nil {
            return expandNonterminal(node, limit: limit)
        }
        
        // Nonterminal (RHS reference): redirect to LHS
        if sym.kind == .N, let lhs = sym.alt {
            let lhsNode = DNode(slot: lhs, i: node.i, k: node.k, j: node.j)
            return expand(lhsNode, limit: limit)
        }
        
        // Bracket
        if [.DO, .OPT, .KLN, .POS].contains(sym.kind) {
            return expandBracket(node, limit: limit)
        }
        
        return [[]]
    }
    
    /// For nonterminal X spanning i..j, find all ways to decompose into children.
    /// Each alternate's symbols form a sequence; BSR entries for the last symbol
    /// give us the pivot, then we recursively find pivots for preceding symbols.
    private func expandNonterminal(_ node: DNode, limit: Int) -> [[DEdge]] {
        let X = node.slot
        var results: [[DEdge]] = []
        
        var altNode = X.alt
        while let alt = altNode {
            defer { altNode = alt.alt }
            guard results.count < limit else { break }
            
            var symbols: [GrammarNode] = []
            var s = alt.seq
            while let n = s { if n.kind == .END { break }; symbols.append(n); s = n.seq }
            guard !symbols.isEmpty else { continue }
            
            // Find all ways to tile i..j with these symbols using BSR entries.
            // tileChildren returns lists of DNode children, one per tiling.
            let tilings = tileSymbols(symbols, from: node.i, to: node.j, limit: limit - results.count)
            
            for children in tilings {
                guard results.count < limit else { break }
                // Each child needs to be expanded recursively; cross-product all their derivations
                let childEdges = children.map { (parent: node, child: $0) }
                crossExpand(childEdges, into: &results, limit: limit)
            }
        }
        return results
    }
    
    /// Find all ways to tile the span [from, to] using a sequence of grammar symbols.
    /// Returns arrays of DNode children, one array per valid tiling.
    private func tileSymbols(_ symbols: [GrammarNode], from i: Int, to j: Int, limit: Int) -> [[DNode]] {
        if symbols.count == 1 {
            let sym = symbols[0]
            // Single symbol must cover the entire span
            if [.T, .TI, .C, .B].contains(sym.kind) {
                // Terminal: must be exactly one token
                if j == i + 1 { return [[DNode(slot: sym, i: i, k: i, j: j)]] }
                return []
            }
            if sym.kind == .EPS {
                if i == j { return [[DNode(slot: sym, i: i, k: i, j: j)]] }
                return []
            }
            if sym.kind == .N {
                // Nonterminal: check BSR evidence via its LHS
                if let lhs = sym.alt {
                    if yield.contains(where: { $0.slot == lhs && $0.i == i && $0.j == j }) {
                        return [[DNode(slot: sym, i: i, k: i, j: j)]]
                    }
                }
                return []
            }
            if [.DO, .OPT, .KLN, .POS].contains(sym.kind) {
                // Bracket: check reachability
                if i == j && (sym.kind == .KLN || sym.kind == .OPT) {
                    return [[DNode(slot: sym, i: i, k: i, j: j)]]
                }
                if isReachableByBracket(sym, from: i, to: j) {
                    return [[DNode(slot: sym, i: i, k: i, j: j)]]
                }
                return []
            }
            return []
        }
        
        // Multiple symbols: last symbol uses BSR to find pivots
        let last = symbols.last!
        let prefix = Array(symbols.dropLast())
        let bsrs = yield.filter { $0.slot == last && $0.i == i && $0.j == j }
        
        var results: [[DNode]] = []
        for bsr in bsrs {
            guard results.count < limit else { break }
            let k = bsr.k
            let rightNode = DNode(slot: last, i: k, k: k, j: j)
            
            // Recursively tile prefix over i..k
            let prefixTilings = tileSymbols(prefix, from: i, to: k, limit: limit - results.count)
            for prefixChildren in prefixTilings {
                guard results.count < limit else { break }
                results.append(prefixChildren + [rightNode])
            }
        }
        
        // For brackets as the last symbol, also check if they can cover the span
        // when BSR entries use the bracket node directly (not as a slot)
        if [.DO, .OPT, .KLN, .POS].contains(last.kind) && bsrs.isEmpty {
            // Collect possible start positions via prefix end positions
            let prefixEnds = collectAllTilingEndPositions(prefix, from: i, limit: limit)
            for k in prefixEnds where k <= j {
                guard results.count < limit else { break }
                // Check bracket can cover k..j
                let canMatch: Bool
                if k == j { canMatch = last.kind == .KLN || last.kind == .OPT }
                else { canMatch = isReachableByBracket(last, from: k, to: j) }
                
                if canMatch {
                    let rightNode = DNode(slot: last, i: k, k: k, j: j)
                    let prefixTilings = tileSymbols(prefix, from: i, to: k, limit: limit - results.count)
                    for prefixChildren in prefixTilings {
                        guard results.count < limit else { break }
                        results.append(prefixChildren + [rightNode])
                    }
                }
            }
        }
        
        return results
    }
    
    /// Collect all possible end positions if we tile `symbols` starting from `i`.
    private func collectAllTilingEndPositions(_ symbols: [GrammarNode], from i: Int, limit: Int) -> Set<Int> {
        if symbols.isEmpty { return [i] }
        if symbols.count == 1 {
            return collectEndPositions(for: symbols[0], from: i)
        }
        let firstEnds = collectEndPositions(for: symbols[0], from: i)
        var result: Set<Int> = []
        for end in firstEnds {
            result.formUnion(collectAllTilingEndPositions(Array(symbols.dropFirst()), from: end, limit: limit))
        }
        return result
    }
    
    /// Expand a bracket node.
    private func expandBracket(_ node: DNode, limit: Int) -> [[DEdge]] {
        let bracket = node.slot
        let i = node.i, j = node.j
        
        if i == j { return [[]] }  // empty match
        
        // Find last iteration starts reachable from i
        var lastStarts: Set<Int> = []
        for bsr in yield where bsr.slot == bracket && bsr.j == j {
            if bsr.k >= i && bsr.k < j && isReachableByBracket(bracket, from: i, to: bsr.k) {
                lastStarts.insert(bsr.k)
            }
        }
        
        var results: [[DEdge]] = []
        for k in lastStarts {
            guard results.count < limit else { break }
            if k == i {
                // Single iteration: expand content
                let contentTrees = expandBracketContent(bracket, i: i, j: j, parent: node, limit: limit - results.count)
                results.append(contentsOf: contentTrees)
            } else {
                // Multi-iteration: bracket(i,k) + content(k,j)
                let leftNode = DNode(slot: bracket, i: i, k: i, j: k)
                let contentTrees = expandBracketContent(bracket, i: k, j: j, parent: node, limit: limit - results.count)
                for contentTree in contentTrees {
                    guard results.count < limit else { break }
                    let leftTrees = expandBracket(leftNode, limit: limit - results.count)
                    for leftTree in leftTrees {
                        guard results.count < limit else { break }
                        let edge = (parent: node, child: leftNode)
                        results.append(contentTree + [edge] + leftTree)
                    }
                }
            }
        }
        return results
    }
    
    /// Expand one iteration of bracket content.
    private func expandBracketContent(_ bracket: GrammarNode, i: Int, j: Int, parent: DNode, limit: Int) -> [[DEdge]] {
        var results: [[DEdge]] = []
        
        var altNode = bracket.alt
        while let alt = altNode {
            defer { altNode = alt.alt }
            
            var symbols: [GrammarNode] = []
            var s = alt.seq
            while let n = s { if n.kind == .END { break }; symbols.append(n); s = n.seq }
            guard !symbols.isEmpty else { continue }
            
            let tilings = tileSymbols(symbols, from: i, to: j, limit: limit - results.count)
            for children in tilings {
                guard results.count < limit else { break }
                let childEdges = children.map { (parent: parent, child: $0) }
                crossExpand(childEdges, into: &results, limit: limit)
            }
        }
        return results
    }
    
    /// Given parent→child edges, expand each child recursively and cross-product the results.
    private func crossExpand(_ edges: [DEdge], into results: inout [[DEdge]], limit: Int) {
        // Start with one derivation containing just these edges
        var derivations: [[DEdge]] = [edges]
        
        for edge in edges {
            guard !derivations.isEmpty else { return }
            let childExpansions = expand(edge.child, limit: limit)
            
            var newDerivations: [[DEdge]] = []
            for existing in derivations {
                for childDeriv in childExpansions {
                    guard newDerivations.count < limit else { break }
                    newDerivations.append(existing + childDeriv)
                }
                guard newDerivations.count < limit else { break }
            }
            derivations = newDerivations
        }
        
        for d in derivations {
            guard results.count < limit else { return }
            results.append(d)
        }
    }
}

// MARK: - Graphviz Rendering

private let derivationColors = [
    "#E63946", "#457B9D", "#2A9D8F", "#E9C46A", "#F4A261",
    "#264653", "#6A0572", "#1B998B", "#FF6B6B", "#4ECDC4",
]

private func nodeLabel(_ node: DNode) -> String {
    let s = node.slot
    if s.kind == .N, s.seq == nil { return "\(s.str):\(node.i):\(node.k):\(node.j)" }
    if s.kind == .EPS { return "ε:\(node.i):\(node.k):\(node.j)" }
    if [.T, .TI, .C, .B].contains(s.kind) { return "\"\(s.str)\":\(node.i):\(node.k):\(node.j)" }
    if [.DO, .OPT, .KLN, .POS].contains(s.kind) {
        var endNode = s.alt?.seq
        while let n = endNode { if n.kind == .END { break }; endNode = n.seq }
        if let end = endNode { return "\(end.ebnfDot()):\(node.i):\(node.k):\(node.j)" }
    }
    return "\(s.ebnfDot()):\(node.i):\(node.k):\(node.j)"
}

private func nodeShape(_ node: DNode) -> String {
    let s = node.slot
    if s.kind == .EPS { return "shape = box, style = \"rounded, dashed\", width=0.0, height=0.0" }
    if [.DO, .OPT, .KLN, .POS].contains(s.kind) { return "shape = rectangle, width=0.0, height=0.0" }
    if [.T, .TI, .C, .B].contains(s.kind) || (s.kind == .N && s.seq == nil) {
        return "shape = box, style = rounded, width=0.0, height=0.0"
    }
    return "shape = rectangle, width=0.0, height=0.0"
}

func generateDerivationDiagram(outputFile file: URL, grammar: Grammar, messageParser: MessageParser) throws {
    let allTrees = messageParser.enumerateBSRDerivations()
    
    // Prune epsilon branches
    let prunedTrees: [[(parent: DNode, child: DNode, derivation: Int)]] = allTrees.enumerated().map { (dIdx, edges) in
        var pruned = edges.filter { $0.child.slot.kind != .EPS }
        var changed = true
        while changed {
            changed = false
            let parents = Set(pruned.map { $0.parent })
            let children = Set(pruned.map { $0.child })
            let leaves = children.subtracting(parents)
            let before = pruned.count
            pruned = pruned.filter { edge in
                if leaves.contains(edge.child) { return [.T, .TI, .C, .B].contains(edge.child.slot.kind) }
                return true
            }
            changed = pruned.count != before
        }
        return pruned.map { (parent: $0.parent, child: $0.child, derivation: dIdx) }
    }
    
    guard !prunedTrees.isEmpty else { return }
    
    struct NodeKey: Hashable { let slot: ObjectIdentifier; let i, k, j: Int }
    var keyToID: [NodeKey: String] = [:]
    var orderedNodes: [DNode] = []
    
    func nodeID(_ n: DNode) -> String {
        let key = NodeKey(slot: ObjectIdentifier(n.slot), i: n.i, k: n.k, j: n.j)
        if let id = keyToID[key] { return id }
        let id = "n\(orderedNodes.count)"
        keyToID[key] = id
        orderedNodes.append(n)
        return id
    }
    
    for tree in prunedTrees {
        for edge in tree { _ = nodeID(edge.parent); _ = nodeID(edge.child) }
    }
    
    var dot = """
    digraph Derivations {
      fontname = Menlo
      fontsize = 10
      node [fontname = Menlo, fontsize = 10]
      edge [arrowsize = 0.4]
      rankdir = TB
      ordering = out
      labelloc = t
      label = <\(grammar.root.ebnf().graphvizHTML)>
    
    """
    
    var terminals: [(id: String, node: DNode)] = []
    for n in orderedNodes {
        let id = nodeID(n)
        dot += "  \(id) [\(nodeShape(n)), label = <\(nodeLabel(n).graphvizHTML)>]\n"
        if [.T, .TI, .C, .B].contains(n.slot.kind) { terminals.append((id, n)) }
    }
    
    let sorted = terminals.sorted { $0.node.i < $1.node.i || ($0.node.i == $1.node.i && $0.node.j < $1.node.j) }
    if sorted.count > 1 {
        dot += "  { rank = same; \(sorted.map { $0.id }.joined(separator: "; ")) }\n"
        for i in 0..<(sorted.count - 1) { dot += "  \(sorted[i].id) -> \(sorted[i + 1].id) [style = invis]\n" }
    }
    
    for tree in prunedTrees {
        let dIdx = tree.first?.derivation ?? 0
        let color = derivationColors[dIdx % derivationColors.count]
        var seen: Set<String> = []
        for edge in tree {
            let key = "\(nodeID(edge.parent))->\(nodeID(edge.child))"
            guard seen.insert(key).inserted else { continue }
            dot += "  \(nodeID(edge.parent)) -> \(nodeID(edge.child)) [color = \"\(color)\", penwidth = 1.5]\n"
        }
    }
    
    dot += "}\n"
    try dot.write(to: file, atomically: true, encoding: .utf8)
}
