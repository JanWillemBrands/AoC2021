//
//  SPPF.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.04.
//

/*
 Paper: "Derivation representation using binary subtree sets"
 
 extractSPPF (Υ, Γ) {
 G := empty graph
 let S be the start symbol of Γ
 let n be the extent of Υ
 if Υ has an element of the form (S ::= α, 0, k, n) {
 create a node labelled (S, 0, n) in G
 while G has an extendable leaf node {
 let w = (μ, i, j) be an extendable leaf node of G
 if (μ is a nonterminal X in Γ) {
 for each (X ::= γ, i, k, j) ∈ Υ { mkPN(X ::= γ·, i, k, j, G) } }
 else {
 suppose μ is X ::= α · δ
 if (|α| = 1) mkPN(X ::= α · δ, i, i, j, G)
 else for each (α, i, k, j) ∈ Υ { mkPN(X ::= α · δ, i, k, j, G) }}}
 return G }
 
 mkPN(X ::= α · δ, i, k, j, G) {
 make a node y in G labelled (X ::= α · δ, k)
 if (α = ε) mkN(ε, i, i, y, G)
 if (α = βx, where |x| = 1) {
 mkN(x, k, j, y, G)
 if (|β| = 1) mkN(β, i, k, y, G)
 if (|β| > 1) mkN(X ::= β · xδ, i, k, y, G) } }
 
 mkN(Ω, i, j, y, G) {
 if there is not a node labelled (Ω, i, j) in G make one
 add an edge from y to the node (Ω, i, j) } }
 */

import Foundation

// MARK: - SPPF Node Types

/// The three kinds of SPPF nodes, following the paper's conventions.
enum SPPFNodeKind {
    case symbol         // nonterminal or terminal: drawn as ellipse
    case intermediate   // grammar slot X ::= α · β with |α| > 1: drawn as rectangle
    case packed         // packed node (X ::= α · β, k): drawn as small filled circle
}

/// An SPPF node in the shared packed parse forest.
/// Symbol and intermediate nodes are identified by (slot, i, j).
/// Packed nodes are identified by (slot, k) and are children of symbol/intermediate nodes.
class SPPFNode: CustomStringConvertible {
    let kind: SPPFNodeKind
    let slot: GrammarNode   // the grammar node (nonterminal, terminal, or slot position)
    let i: Int              // left extent (or pivot k for packed nodes)
    let j: Int              // right extent (unused for packed nodes, set to -1)
    var children: [SPPFNode] = []
    var extended = false    // has this node been extended (expanded) already?
    
    init(kind: SPPFNodeKind, slot: GrammarNode, i: Int, j: Int) {
        self.kind = kind
        self.slot = slot
        self.i = i
        self.j = j
    }
    
    /// Label for display
    var label: String {
        switch kind {
        case .symbol:
            if isNonterminal {
                return "\(slot.str), \(i), \(j)"
            } else if slot.kind == .EPS {
                return "ε, \(i), \(j)"
            } else if [.DO, .OPT, .KLN, .POS].contains(slot.kind) {
                // Bracket acting as anonymous nonterminal — show only bracket content, not continuation
                return "\(slot.bracketLabel()), \(i), \(j)"
            } else {
                // terminal
                return "\"\(slot.str)\", \(i), \(j)"
            }
        case .intermediate:
            return "\(slot.ebnfDot()), \(i), \(j)"
        case .packed:
            return "\(slot.ebnfDot()), \(i)"  // i is the pivot k for packed nodes
        }
    }
    
    /// Is this a nonterminal symbol node?
    var isNonterminal: Bool {
        slot.kind == .N && slot.seq == nil
    }
    
    /// Is this node extendable? (a leaf that is not a terminal, epsilon, or packed)
    var isExtendable: Bool {
        guard children.isEmpty && !extended else { return false }
        if kind == .packed { return false }
        // Only symbol nodes for terminals/epsilon are non-extendable.
        // Intermediate nodes whose slot happens to be a terminal ARE extendable
        // (they represent grammar positions X ::= α · β that need decomposition).
        if kind == .symbol {
            if slot.kind == .EPS { return false }
            if [.T, .TI, .C, .B].contains(slot.kind) { return false }
        }
        return true
    }
    
    var description: String { label }
}

// MARK: - SPPF Node Identity

/// Key for deduplicating symbol and intermediate nodes: (slot, i, j).
struct SPPFNodeKey: Hashable {
    let slot: GrammarNode
    let i: Int
    let j: Int
}

// MARK: - Slot Index Computation

/// Precomputed mapping from grammar node → number of symbols before (and including) it
/// in its containing alternate. This gives |α| for the BSR element at that slot.
///
/// For a rule S = "a" B "c":
///   ALT.seq → T("a") → N(B) → T("c") → END
///   slotIndex:  1        2       3        (END not indexed)
///
/// |α| for a BSR element with node L equals slotIndex[L].
var slotIndex: [GrammarNode: Int] = [:]

/// Walk all grammar rules and bracket alternates to build the slotIndex dictionary.
func buildSlotIndex() {
    slotIndex = [:]
    for (_, nonterminal) in nonTerminals {
        indexAlternates(nonterminal.alt)
    }
}

/// Index alternates starting from an ALT node chain.
private func indexAlternates(_ alt: GrammarNode?) {
    var current = alt
    while let altNode = current {
        // Walk the seq chain of this alternate, counting symbols
        var node = altNode.seq
        var index = 0
        while let n = node {
            if n.kind == .END { break }
            
            // Recurse into bracket alternates
            if [.DO, .OPT, .KLN, .POS].contains(n.kind) {
                indexAlternates(n.alt)
            }
            
            index += 1
            slotIndex[n] = index
            node = n.seq
        }
        current = altNode.alt
    }
}

/// Get the grammar node that is `steps` positions before `node` in its seq chain.
/// Returns nil if we can't walk back that far.
/// Since nodes don't have back-pointers, we find the containing ALT and walk forward.
func predecessorSlot(of node: GrammarNode, steps: Int) -> GrammarNode? {
    guard let targetIndex = slotIndex[node], targetIndex > steps else { return nil }
    let targetPos = targetIndex - steps
    
    // Find the containing ALT by walking forward through the seq chain to the END node.
    // The END node's alt pointer gives us the ALT node for this alternate.
    // This works correctly for nodes inside brackets (unlike toplevels() which always
    // walks to the top-level nonterminal).
    var endNode: GrammarNode? = node
    while let n = endNode {
        if n.kind == .END {
            break
        }
        endNode = n.seq
    }
    guard let end = endNode, end.kind == .END, let alt = end.alt else { return nil }
    
    var current = alt.seq
    while let n = current {
        if n.kind == .END { break }
        if slotIndex[n] == targetPos { return n }
        current = n.seq
    }
    return nil
}

// MARK: - BSR Lookup Helpers

/// Find all BSR elements where node matches the LHS nonterminal (complete rules)
/// with the given left extent i and right extent j.
/// Paper: (X ::= γ, i, k, j) ∈ Υ
func bsrForNonterminal(_ X: GrammarNode, i: Int, j: Int) -> [BSR] {
    bsrSet.filter { bsr in
        bsr.node == X && bsr.i == i && bsr.j == j
    }
}

/// Find all BSR elements where the node is a specific intermediate slot
/// with the given left extent i and right extent j.
/// Paper: (α, i, k, j) ∈ Υ
func bsrForSlot(_ slot: GrammarNode, i: Int, j: Int) -> [BSR] {
    bsrSet.filter { bsr in
        bsr.node == slot && bsr.i == i && bsr.j == j
    }
}

// MARK: - SPPF Extraction Algorithm

/// The SPPF graph: maps node keys to nodes for deduplication.
var sppfNodes: [SPPFNodeKey: SPPFNode] = [:]

/// All SPPF nodes in creation order (for iteration).
var sppfAllNodes: [SPPFNode] = []

/// Extract an SPPF from the BSR set, following the paper's algorithm.
/// - Parameters:
///   - startSymbol: the grammar's start nonterminal (LHS node, kind .N, seq == nil)
///   - extent: the input length (number of tokens excluding EOS)
/// - Returns: the root SPPFNode, or nil if no parse exists
func extractSPPF(startSymbol: GrammarNode, extent: Int) -> SPPFNode? {
    // Build slot index for |α| computation
    buildSlotIndex()
    
    // Clear previous SPPF
    sppfNodes = [:]
    sppfAllNodes = []
    
    // Paper: if Υ has an element of the form (S ::= α, 0, k, n)
    let rootBSRs = bsrForNonterminal(startSymbol, i: 0, j: extent)
    guard !rootBSRs.isEmpty else {
        print("SPPF: no complete parse found for \(startSymbol.str) spanning 0..\(extent)")
        return nil
    }
    
    // Paper: create a node labelled (S, 0, n) in G
    let root = findOrCreateNode(kind: .symbol, slot: startSymbol, i: 0, j: extent)
    
    // Paper: while G has an extendable leaf node
    var changed = true
    while changed {
        changed = false
        // Snapshot the list since we'll be adding nodes during iteration
        let snapshot = sppfAllNodes
        for node in snapshot {
            if node.isExtendable {
                node.extended = true
                changed = true
                extendNode(node)
            }
        }
    }
    
    return root
}

/// Extend an extendable leaf node.
/// Paper: the body of the "while G has an extendable leaf node" loop.
private func extendNode(_ w: SPPFNode) {
    let i = w.i
    let j = w.j
    
    if w.isNonterminal {
        // Paper: μ is a nonterminal X
        // for each (X ::= γ, i, k, j) ∈ Υ { mkPN(X ::= γ·, i, k, j, G) }
        //
        // In our parser, the complete-rule BSR (X, i, k, j) always has k == i
        // (it stores cU, the cluster index, not a meaningful pivot). So we don't
        // use k from the complete-rule BSR. Instead, mkPNforCompleteRule searches
        // the intermediate BSRs to find actual split points for each alternate.
        let X = w.slot
        let matches = bsrForNonterminal(X, i: i, j: j)
        if !matches.isEmpty {
            mkPNforCompleteRule(lhs: X, i: i, j: j, parent: w)
        }
    } else if w.kind == .symbol && [.DO, .OPT, .KLN, .POS].contains(w.slot.kind) {
        // Bracket symbol node acting as anonymous nonterminal.
        // BSR i field is the outer caller's cU, not the bracket's start position,
        // so we use a bracket-specific expansion that understands iteration structure.
        // NOTE: intermediate nodes whose slot is a bracket go through the else branch below.
        extendBracketNode(w)
    } else {
        // Paper: μ is X ::= α · δ (an intermediate node)
        let slot = w.slot
        guard let alphaLen = slotIndex[slot] else {
            print("SPPF: no slot index for \(slot) kind=\(slot.kind)")
            return
        }
        
        if alphaLen == 1 {
            // Paper: if (|α| = 1) mkPN(X ::= α · δ, i, i, j, G)
            mkPN(slot: slot, i: i, k: i, j: j, parent: w)
        } else if [.DO, .OPT, .KLN, .POS].contains(slot.kind) {
            // Bracket as last symbol of an intermediate prefix:
            // BSR pivots for brackets represent iteration starts, NOT the
            // split between preceding symbols and the bracket. We need to find
            // where the bracket itself begins by looking at the predecessor symbol.
            if let prevSymbol = predecessorSlot(of: slot, steps: 1) {
                let pivots = collectEndPositions(for: prevSymbol, from: i)
                for k in pivots {
                    mkPN(slot: slot, i: i, k: k, j: j, parent: w)
                }
            }
        } else {
            // Paper: for each (α, i, k, j) ∈ Υ { mkPN(X ::= α · δ, i, k, j, G) }
            let matches = bsrForSlot(slot, i: i, j: j)
            for bsr in matches {
                mkPN(slot: slot, i: i, k: bsr.k, j: j, parent: w)
            }
        }
    }
}

/// Extend a bracket (DO/OPT/KLN/POS) symbol node.
///
/// Brackets produce per-iteration BSRs: `(bracket, outer_cU, iteration_start, iteration_end)`.
/// The SPPF for a bracket is built left-associatively:
///   - For empty match (KLN/OPT only): packed node → ε
///   - For single iteration: packed node → alternate content
///   - For multiple iterations: packed node → (bracket(i,k), alternate_content(k,j))
///     where k is the last iteration start.
private func extendBracketNode(_ w: SPPFNode) {
    let bracket = w.slot
    let i = w.i
    let j = w.j
    
    if i == j {
        // Empty match (KLN/OPT matching nothing)
        // Create packed node with ε child
        let packedNode = SPPFNode(kind: .packed, slot: bracket, i: i, j: -1)
        w.children.append(packedNode)
        sppfAllNodes.append(packedNode)
        
        // Create an epsilon symbol node. Use an EPS grammar node if available,
        // otherwise use the bracket itself as a stand-in (marked as epsilon in the label).
        let epsNode = findOrCreateEpsilonSymbolNode(at: i)
        packedNode.children.append(epsNode)
        return
    }
    
    // Find all iteration boundaries by looking at bracket BSRs ending at j.
    // BSR format: (bracket, outer_cU, k=iteration_start, j=iteration_end)
    // We want iterations ending at j to find the last iteration start.
    var lastIterationStarts: Set<Int> = []
    for bsr in bsrSet where bsr.node == bracket && bsr.j == j {
        lastIterationStarts.insert(bsr.k)
    }
    
    // Also, for KLN/POS that re-enter, we need to trace WHICH iteration starts 
    // are reachable from position i through the iteration chain.
    let reachableStarts = lastIterationStarts.filter { k in
        k >= i && k <= j && isReachableByBracket(bracket, from: i, to: k)
    }
    
    for k in reachableStarts {
        if k == i {
            // Single iteration: bracket content matches i→j directly.
            // Decompose into the alternate's symbols.
            mkBracketIterationContent(bracket: bracket, i: i, j: j, parent: w)
        } else {
            // Multiple iterations: left = bracket(i, k), right = last iteration content(k, j)
            let packedNode = SPPFNode(kind: .packed, slot: bracket, i: k, j: -1)
            w.children.append(packedNode)
            sppfAllNodes.append(packedNode)
            
            // Right child: content of one iteration spanning (k, j)
            mkBracketIterationContent(bracket: bracket, i: k, j: j, parent: packedNode)
            
            // Left child: bracket itself spanning (i, k) — recursive structure
            let leftChild = findOrCreateNode(kind: .symbol, slot: bracket, i: i, j: k)
            packedNode.children.append(leftChild)
        }
    }
}

/// Check if a bracket can reach position `to` from position `from` through its iteration chain.
/// Follows the chain of iteration BSRs: from → p₁ → p₂ → ... → to.
private func isReachableByBracket(_ bracket: GrammarNode, from: Int, to: Int) -> Bool {
    if from == to { return true }
    
    var visited: Set<Int> = []
    var queue: [Int] = [from]
    
    while !queue.isEmpty {
        let pos = queue.removeFirst()
        guard visited.insert(pos).inserted else { continue }
        if pos == to { return true }
        
        // Follow iterations starting at pos
        for bsr in bsrSet where bsr.node == bracket && bsr.k == pos {
            if bsr.j <= to {
                queue.append(bsr.j)
            }
        }
    }
    return false
}

/// Create the SPPF content for one iteration of a bracket spanning (i, j).
/// Searches the bracket's alternates to find which one matched and decomposes it.
private func mkBracketIterationContent(bracket: GrammarNode, i: Int, j: Int, parent: SPPFNode) {
    // Walk the bracket's alternates
    var altNode = bracket.alt
    while let alt = altNode {
        defer { altNode = alt.alt }
        
        // Collect symbols in this alternate
        var symbols: [GrammarNode] = []
        var node = alt.seq
        while let n = node {
            if n.kind == .END { break }
            symbols.append(n)
            node = n.seq
        }
        
        guard !symbols.isEmpty else { continue }
        
        let last = symbols.last!
        
        if symbols.count == 1 {
            // Single-symbol alternate: check for BSR (symbol, i, i, j)
            // Inside a bracket iteration, BSRs have i=cU=bracket_cluster_index
            let bsrs = bsrForSlot(last, i: i, j: j)
            if bsrs.contains(where: { $0.k == i }) {
                // For single-iteration case, add directly to parent
                if parent.kind == .packed {
                    let child = makeSymbolOrIntermediateNode(for: last, i: i, j: j)
                    parent.children.append(child)
                } else {
                    // parent is the bracket symbol node itself (single iteration case)
                    let packedNode = SPPFNode(kind: .packed, slot: last, i: i, j: -1)
                    parent.children.append(packedNode)
                    sppfAllNodes.append(packedNode)
                    
                    let child = makeSymbolOrIntermediateNode(for: last, i: i, j: j)
                    packedNode.children.append(child)
                }
            }
        } else {
            // Multi-symbol alternate: find pivots and decompose
            // For bracket alternates, BSRs have i=bracket_cluster_index
            let lastBSRs = bsrForSlot(last, i: i, j: j)
            for bsr in lastBSRs {
                let k = bsr.k
                
                if parent.kind == .packed {
                    // Already inside a packed node (multi-iteration case).
                    // The parent packed node already has the bracket-prefix as left child.
                    // We need to add the iteration content as an intermediate node
                    // that represents the bracket alternate's body, keeping binary structure.
                    // Use the last symbol as an intermediate node label: (last, i, j)
                    let intermediateChild = findOrCreateNode(kind: .intermediate, slot: last, i: i, j: j)
                    parent.children.append(intermediateChild)
                    // The intermediate node will be extended during the fixpoint loop,
                    // which will decompose it into its constituent symbols.
                } else {
                    // parent is the bracket symbol node itself (single iteration case)
                    let packedNode = SPPFNode(kind: .packed, slot: last, i: k, j: -1)
                    parent.children.append(packedNode)
                    sppfAllNodes.append(packedNode)
                    
                    // Right child: last symbol spanning (k, j)
                    let rightChild = makeSymbolOrIntermediateNode(for: last, i: k, j: j)
                    packedNode.children.append(rightChild)
                    
                    if symbols.count == 2 {
                        let leftChild = makeSymbolOrIntermediateNode(for: symbols[0], i: i, j: k)
                        packedNode.children.append(leftChild)
                    } else {
                        let prevSlot = symbols[symbols.count - 2]
                        let leftChild = findOrCreateNode(kind: .intermediate, slot: prevSlot, i: i, j: k)
                        packedNode.children.append(leftChild)
                    }
                }
            }
        }
    }
}

/// A synthetic epsilon grammar node used for empty bracket matches.
/// Created lazily so we only have one shared instance.
private var syntheticEpsilonNode: GrammarNode?

/// Find or create an epsilon symbol node at position `pos`.
private func findOrCreateEpsilonSymbolNode(at pos: Int) -> SPPFNode {
    // Try to find an existing EPS grammar node in the grammar
    if syntheticEpsilonNode == nil {
        outer: for (_, nt) in nonTerminals {
            var alt = nt.alt
            while let a = alt {
                var node = a.seq
                while let n = node {
                    if n.kind == .EPS {
                        syntheticEpsilonNode = n
                        break outer
                    }
                    if n.kind == .END { break }
                    node = n.seq
                }
                alt = a.alt
            }
        }
    }
    
    // If no EPS node exists in the grammar, create a synthetic one
    if syntheticEpsilonNode == nil {
        syntheticEpsilonNode = GrammarNode(kind: .EPS, str: "ε")
    }
    
    let node = findOrCreateNode(kind: .symbol, slot: syntheticEpsilonNode!, i: pos, j: pos)
    node.extended = true
    return node
}

/// Paper: mkPN(X ::= α · δ, i, k, j, G)
/// Creates a packed node and its children for an intermediate slot.
/// - Parameters:
///   - slot: the grammar slot L (a symbol node within an alternate, NOT the LHS nonterminal)
///   - i: left extent
///   - k: pivot
///   - j: right extent
///   - parent: the symbol or intermediate node to attach the packed node to
private func mkPN(slot: GrammarNode, i: Int, k: Int, j: Int, parent: SPPFNode) {
    // Paper: make a node y in G labelled (X ::= α · δ, k)
    let packedNode = SPPFNode(kind: .packed, slot: slot, i: k, j: -1)
    parent.children.append(packedNode)
    sppfAllNodes.append(packedNode)
    
    if slot.kind == .EPS {
        // Paper: if (α = ε) mkN(ε, i, i, y, G)
        let epsNode = findOrCreateNode(kind: .symbol, slot: slot, i: i, j: i)
        epsNode.extended = true // epsilon nodes are never extendable
        packedNode.children.append(epsNode)
        
    } else {
        // Intermediate slot: the slot node IS the last symbol of α (or a bracket/nonterminal)
        // |α| = slotIndex[slot]
        mkPNforSlot(slot: slot, i: i, k: k, j: j, packedNode: packedNode)
    }
}

/// Handle a complete nonterminal: X matched from i to j.
/// Search through X's alternates to find which ones have BSRs spanning (i, ?, j),
/// and create packed nodes with appropriate children for each.
///
/// In our parser, the complete-rule BSR (X, i, cU, j) always stores k=cU=i, so we
/// cannot use it as a pivot. Instead, we look at intermediate BSRs for the last slot
/// of each alternate: if |α| == 1, the slot BSR is (lastSymbol, i, i, j); if |α| > 1,
/// the slot BSR is (lastSymbol, i, k, j) for various split points k.
private func mkPNforCompleteRule(lhs: GrammarNode, i: Int, j: Int, parent: SPPFNode) {
    // Try each alternate of X
    var altNode = lhs.alt
    while let alt = altNode {
        defer { altNode = alt.alt }
        
        // Collect all symbols in this alternate into an array
        var symbols: [GrammarNode] = []
        var node = alt.seq
        while let n = node {
            if n.kind == .END { break }
            symbols.append(n)
            node = n.seq
        }
        
        guard !symbols.isEmpty else { continue }
        
        let last = symbols.last!
        let symbolCount = symbols.count
        
        if symbolCount == 1 {
            // Single-symbol alternate: pivot is i, the only child spans (i, j)
            // Check that this symbol has BSR evidence for matching (i, j)
            let bsrs = bsrForSlot(last, i: i, j: j)
            let hasDirect = bsrs.contains(where: { $0.k == i })
            // For brackets, also check if the bracket has ANY BSRs that reach j
            let hasBracket = [.DO, .OPT, .KLN, .POS].contains(last.kind)
                && bsrForNonterminal(last, i: i, j: j).isEmpty == false
            
            if hasDirect || hasBracket {
                let packedNode = SPPFNode(kind: .packed, slot: last, i: i, j: -1)
                parent.children.append(packedNode)
                sppfAllNodes.append(packedNode)
                
                let child = makeSymbolOrIntermediateNode(for: last, i: i, j: j)
                packedNode.children.append(child)
            }
        } else {
            // Multi-symbol alternate: find all valid pivot positions (where last symbol starts).
            // Strategy: collect all positions reachable by the prefix (all symbols except last).
            let pivots = findPivots(symbols: symbols, i: i, j: j)
            
            for k in pivots where canSymbolMatch(last, from: k, to: j) {
                let packedNode = SPPFNode(kind: .packed, slot: last, i: k, j: -1)
                parent.children.append(packedNode)
                sppfAllNodes.append(packedNode)
                
                // Right child: last symbol spanning (k, j)
                let rightChild = makeSymbolOrIntermediateNode(for: last, i: k, j: j)
                packedNode.children.append(rightChild)
                
                if symbolCount == 2 {
                    // Left child: the first symbol spanning (i, k)
                    let leftChild = makeSymbolOrIntermediateNode(for: symbols[0], i: i, j: k)
                    packedNode.children.append(leftChild)
                } else {
                    // Left child: intermediate node for the second-to-last symbol, spanning (i, k)
                    let prevSlot = symbols[symbolCount - 2]
                    let leftChild = findOrCreateNode(kind: .intermediate, slot: prevSlot, i: i, j: k)
                    packedNode.children.append(leftChild)
                }
            }
        }
    }
}

/// Find all valid pivot positions for a multi-symbol alternate.
/// The pivot is where the last symbol starts (= where the prefix ends).
///
/// IMPORTANT: We cannot use `bsrForSlot(last, i, j)` because the BSR `i` field stores
/// the cluster index (cU), not the true left extent. Instead, we find pivots by collecting
/// all positions reachable by the prefix symbols from position `i`.
///
/// For 2-symbol alternates: collect end positions of symbols[0] from `i`.
/// For 3+-symbol alternates: collect end positions of symbols[count-2] from `i`.
/// For bracket last symbols, also handle nullable brackets (KLN/OPT matching empty → pivot = j).
private func findPivots(symbols: [GrammarNode], i: Int, j: Int) -> Set<Int> {
    let last = symbols.last!
    
    var pivots: Set<Int>
    if symbols.count == 2 {
        pivots = collectEndPositions(for: symbols[0], from: i)
    } else {
        // For 3+ symbols, we need to chain through the prefix.
        // collectEndPositions gives positions reachable from `i` by one symbol.
        // For symbols[count-2], we need it to start from wherever symbols[0..count-3] end.
        // Recursively chain: start from i, find ends of symbol[0], then ends of symbol[1], etc.
        pivots = chainEndPositions(symbols: Array(symbols.dropLast()), from: i)
    }
    
    // For nullable bracket last symbols, also include j as a valid pivot
    // (the bracket matches empty).
    if [.KLN, .OPT].contains(last.kind) {
        pivots.insert(j)
    }
    
    // Filter: pivots must be in [i, j]
    return pivots.filter { $0 >= i && $0 <= j }
}

/// Chain through a sequence of symbols to find all possible end positions.
/// Starting from `start`, for each symbol in order, collect where it could end
/// given all possible start positions from the previous symbol.
private func chainEndPositions(symbols: [GrammarNode], from start: Int) -> Set<Int> {
    var positions: Set<Int> = [start]
    for symbol in symbols {
        var nextPositions: Set<Int> = []
        for pos in positions {
            nextPositions.formUnion(collectEndPositions(for: symbol, from: pos))
        }
        positions = nextPositions
    }
    return positions
}

/// Collect all positions where a bracket could start such that it spans from that position to `target`.
/// Traces backwards through the bracket's iteration chain.
/// Only returns positions >= `lowerBound`.
private func collectBracketStartPositions(for bracket: GrammarNode, reaching target: Int, from lowerBound: Int) -> Set<Int> {
    var starts: Set<Int> = []
    
    // For single-iteration brackets (DO), find BSRs where bsr.j == target
    // The k value is where the iteration started = the bracket start.
    for bsr in bsrSet where bsr.node == bracket && bsr.j == target {
        if bsr.k >= lowerBound {
            starts.insert(bsr.k)
        }
    }
    
    // For multi-iteration brackets (KLN/POS), the bracket could have started earlier.
    // Trace backwards: if the bracket started at p and an iteration goes from p to q,
    // then p is a valid start if there's a chain from q to target.
    if bracket.kind == .KLN || bracket.kind == .POS {
        // We already have the final iteration starts (from BSRs ending at target).
        // Now trace backwards to find earlier starts.
        var visited: Set<Int> = []
        var queue = Array(starts)
        
        while !queue.isEmpty {
            let pos = queue.removeFirst()
            guard visited.insert(pos).inserted else { continue }
            
            // Find iterations that END at pos — their k values are earlier starts
            for bsr in bsrSet where bsr.node == bracket && bsr.j == pos {
                if bsr.k >= lowerBound && bsr.k < pos {
                    starts.insert(bsr.k)
                    queue.append(bsr.k)
                }
            }
        }
    }
    
    return starts
}

/// Check if a symbol can match the span from `from` to `to`.
/// Uses BSR evidence to verify that the symbol actually parsed this span.
private func canSymbolMatch(_ symbol: GrammarNode, from: Int, to: Int) -> Bool {
    if from == to {
        // Empty span: only epsilon and nullable brackets can match
        if symbol.kind == .EPS { return true }
        if symbol.kind == .KLN || symbol.kind == .OPT { return true }
        return false
    }
    
    switch symbol.kind {
    case .T, .TI, .C, .B:
        // Terminal: must span exactly one token
        return to == from + 1
    case .N:
        // Nonterminal (RHS instance): check if the LHS has a complete-rule BSR
        if let lhs = symbol.alt {
            return !bsrForNonterminal(lhs, i: from, j: to).isEmpty
        }
        return false
    case .DO, .OPT, .KLN, .POS:
        // Bracket: check if the bracket can reach `to` from `from`
        return isReachableByBracket(symbol, from: from, to: to)
    case .EPS:
        return from == to
    default:
        return true  // intermediate slots — don't filter
    }
}

/// Collect all positions reachable (as end positions) by a symbol starting from `start`.
///
/// For brackets (KLN/POS/OPT/DO): follow the iteration chain in BSRs.
///   Each iteration BSR has (bracket, outer_cU, k=iteration_start, j=iteration_end).
///   We follow k → j chains starting from `start` to find all reachable positions.
///
/// For terminals: `start+1` if a BSR exists with `k == start`.
///
/// For nonterminals: `j` from BSRs of the RHS node where `k == start`.
private func collectEndPositions(for symbol: GrammarNode, from start: Int) -> Set<Int> {
    var positions: Set<Int> = []
    
    if [.DO, .OPT, .KLN, .POS].contains(symbol.kind) {
        // Bracket: follow iteration chain from `start`.
        // Each bracket BSR has k=iteration_start, j=iteration_end.
        // Start position `start` is where the bracket begins.
        // For KLN/OPT, the bracket can also match empty → include `start`.
        if symbol.kind == .KLN || symbol.kind == .OPT {
            positions.insert(start)
        }
        
        var visited: Set<Int> = []
        var queue: [Int] = [start]
        
        while !queue.isEmpty {
            let pos = queue.removeFirst()
            guard visited.insert(pos).inserted else { continue }
            
            // Find all BSRs for iterations starting at this position
            for bsr in bsrSet where bsr.node == symbol && bsr.k == pos {
                positions.insert(bsr.j)
                // For KLN/POS, the end of one iteration can start another
                if symbol.kind == .KLN || symbol.kind == .POS {
                    queue.append(bsr.j)
                }
            }
        }
    } else {
        // Non-bracket: BSRs where symbol matches starting at `start`
        for bsr in bsrSet where bsr.node == symbol && bsr.k == start {
            positions.insert(bsr.j)
        }
    }
    
    return positions
}

/// Handle mkPN for an intermediate slot BSR.
private func mkPNforSlot(slot: GrammarNode, i: Int, k: Int, j: Int, packedNode: SPPFNode) {
    guard let alphaLen = slotIndex[slot] else { return }
    
    // Paper: α = βx where |x| = 1
    // x is `slot` itself (the last symbol of α)
    // β is everything before x
    let betaLen = alphaLen - 1
    
    // Right child: mkN(x, k, j, y, G)
    let rightChild = makeSymbolOrIntermediateNode(for: slot, i: k, j: j)
    packedNode.children.append(rightChild)
    
    if betaLen == 1 {
        // Paper: if (|β| = 1) mkN(β, i, k, y, G)
        // β is the single symbol before x
        if let prevSymbol = predecessorSlot(of: slot, steps: 1) {
            let leftChild = makeSymbolOrIntermediateNode(for: prevSymbol, i: i, j: k)
            packedNode.children.append(leftChild)
        }
    } else if betaLen > 1 {
        // Paper: if (|β| > 1) mkN(X ::= β · xδ, i, k, y, G)
        // The intermediate node label is the slot one position before `slot`
        if let prevSlot = predecessorSlot(of: slot, steps: 1) {
            let leftChild = findOrCreateNode(kind: .intermediate, slot: prevSlot, i: i, j: k)
            packedNode.children.append(leftChild)
        }
    }
    // if betaLen == 0: no left child (single-symbol case, but this shouldn't happen
    // because |α| = 1 is handled in extendNode, not here)
}

/// Create a symbol node for a terminal or nonterminal, or route brackets appropriately.
private func makeSymbolOrIntermediateNode(for node: GrammarNode, i: Int, j: Int) -> SPPFNode {
    switch node.kind {
    case .N:
        if node.seq == nil {
            // LHS nonterminal reference (shouldn't happen here)
            return findOrCreateNode(kind: .symbol, slot: node, i: i, j: j)
        } else {
            // RHS nonterminal: the symbol is the nonterminal being called.
            // node.alt points to the LHS definition.
            return findOrCreateNode(kind: .symbol, slot: node.alt!, i: i, j: j)
        }
    case .T, .TI, .C, .B:
        let n = findOrCreateNode(kind: .symbol, slot: node, i: i, j: j)
        n.extended = true // terminals are never extendable
        return n
    case .EPS:
        let n = findOrCreateNode(kind: .symbol, slot: node, i: i, j: j)
        n.extended = true
        return n
    case .DO, .OPT, .KLN, .POS:
        // Brackets act like anonymous nonterminals
        return findOrCreateNode(kind: .symbol, slot: node, i: i, j: j)
    default:
        // Intermediate slot
        return findOrCreateNode(kind: .intermediate, slot: node, i: i, j: j)
    }
}

/// Paper: mkN(Ω, i, j, y, G) — find or create a node labelled (Ω, i, j)
private func findOrCreateNode(kind: SPPFNodeKind, slot: GrammarNode, i: Int, j: Int) -> SPPFNode {
    let key = SPPFNodeKey(slot: slot, i: i, j: j)
    if let existing = sppfNodes[key] {
        return existing
    }
    let node = SPPFNode(kind: kind, slot: slot, i: i, j: j)
    sppfNodes[key] = node
    sppfAllNodes.append(node)
    return node
}

// MARK: - Graphviz SPPF Diagram Generation

/// Generate a Graphviz dot file for the SPPF.
/// Node shapes follow the paper's conventions:
///   - Symbol nodes (nonterminals, terminals): ellipse
///   - Intermediate nodes (grammar slots): rectangle
///   - Packed nodes: small filled circle
func generateSPPFDiagram(root: SPPFNode, to file: URL) throws {
    var dot = """
    digraph SPPF {
      fontname = Menlo
      fontsize = 10
      node [fontname = Menlo, fontsize = 10]
      edge [arrowsize = 0.4]
      rankdir = "TB"
      ordering = out
    
    """
    
    // Assign stable IDs to all nodes
    var nodeIDs: [ObjectIdentifier: String] = [:]
    var nextID = 0
    
    func nodeID(_ node: SPPFNode) -> String {
        let oid = ObjectIdentifier(node)
        if let id = nodeIDs[oid] { return id }
        let id = "n\(nextID)"
        nextID += 1
        nodeIDs[oid] = id
        return id
    }
    
    // Collect all reachable nodes via BFS
    var visited: Set<ObjectIdentifier> = []
    var queue: [SPPFNode] = [root]
    var allReachable: [SPPFNode] = []
    
    while !queue.isEmpty {
        let node = queue.removeFirst()
        let oid = ObjectIdentifier(node)
        guard visited.insert(oid).inserted else { continue }
        allReachable.append(node)
        for child in node.children {
            queue.append(child)
        }
    }
    
    // Emit nodes
    for node in allReachable {
        let id = nodeID(node)
        let escapedLabel = node.label.graphvizHTML
        
        switch node.kind {
        case .symbol:
            if node.isNonterminal || [.DO, .OPT, .KLN, .POS].contains(node.slot.kind) {
                // Nonterminal or bracket: ellipse
                dot += "  \(id) [shape = ellipse, label = <\(escapedLabel)>]\n"
            } else if node.slot.kind == .EPS {
                // Epsilon: small ellipse
                dot += "  \(id) [shape = ellipse, label = <\(escapedLabel)>, style = dashed]\n"
            } else {
                // Terminal: ellipse
                dot += "  \(id) [shape = ellipse, label = <\(escapedLabel)>]\n"
            }
            
        case .intermediate:
            // Intermediate: rectangle
            dot += "  \(id) [shape = rectangle, label = <\(escapedLabel)>]\n"
            
        case .packed:
            // Packed: small filled circle with tooltip
            dot += "  \(id) [shape = circle, width = 0.15, height = 0.15, fixedsize = true, style = filled, fillcolor = black, label = \"\", tooltip = \"\(node.label)\"]\n"
        }
    }
    
    // Emit edges
    for node in allReachable {
        let parentID = nodeID(node)
        for child in node.children {
            let childID = nodeID(child)
            dot += "  \(parentID) -> \(childID)\n"
        }
    }
    
    dot += "}\n"
    
    try dot.write(to: file, atomically: true, encoding: .utf8)
}

