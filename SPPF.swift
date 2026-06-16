//
//  SPPF.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.04.
//


// Paper: "Derivation representation using binary subtree sets"

/*
func extractSPPF (Υ, Γ) {
    G := empty graph
    let S be the start symbol of Γ
    let n be the extent of Υ
    if Υ has an element of the form (S ::= α, 0, k, n) {
        create a node labelled (S, 0, n) in G
        while G has an extendable leaf node {
            let w = (μ, i, j) be an extendable leaf node of G
            if (μ is a nonterminal X in Γ) {
                for each (X ::= γ, i, k, j) ∈ Υ {
                    mkPN(X ::= γ·, i, k, j, G)
                }
            } else {
                suppose μ is X ::= α · δ
                if (|α| = 1) {
                    mkPN(X ::= α · δ, i, i, j, G)
                } else {
                    for each (α, i, k, j) ∈ Υ {
                        mkPN(X ::= α · δ, i, k, j, G)
                    }
                }
            }
        }
        return G
    }
    
    func mkPN(X ::= α · δ, i, k, j, G) {
        make a node y in G labelled (X ::= α · δ, k)
        if (α = ε) mkN(ε, i, i, y, G)
            if (α = βx, where |x| = 1) {
            mkN(x, k, j, y, G)
            if (|β| = 1) mkN(β, i, k, y, G)
                if (|β| > 1) mkN(X ::= β · xδ, i, k, y, G)
        }
    }
    
    func mkN(Ω, i, j, y, G) {
        if there is not a node labelled (Ω, i, j) in G make one
            add an edge from y to the node (Ω, i, j)
    }

*/

import OSLog
import Foundation
//import AdventMacros

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
    let slot: GrammarNode       // the grammar node (nonterminal, terminal, or slot position)
    let i: CharPosition         // left extent (or pivot k for packed nodes)
    let j: CharPosition?        // right extent (nil for packed nodes)
    var children: [SPPFNode] = []
    var extended = false        // has this node been extended (expanded) already?

    init(kind: SPPFNodeKind, slot: GrammarNode, i: CharPosition, j: CharPosition?) {
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
                return "\(slot.name),\(i),\(j)"
            } else if slot.kind == .EPS {
                return "ε,\(i),\(j)"
            } else if slot.kind.isBracket {
                // Bracket symbol node — use bracket's internal END to get {τ·}
                if let end = slot.bracketEndNode {
                    return "\(end.ebnfDot()),\(i),\(j)"
                }
                return "\(slot.ebnfDot()),\(i),\(j)"
            } else {
                // terminal
                return "\"\(slot.name)\",\(i),\(j)"
            }
        case .intermediate:
            // Dot after the slot node: terminals get "a"·, brackets get {"a"}·
            return "\(slot.ebnfDot()),\(i),\(j)"
        case .packed:
            return "\(slot.ebnfDot()),\(i)"  // i is the pivot k for packed nodes
        }
    }
    
    /// Is this a nonterminal symbol node?
    var isNonterminal: Bool {
        slot.isLHS
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
            if slot.kind.isTerminal { return false }
        }
        return true
    }
    
    var description: String { label }
}

// MARK: - SPPF Node Identity

/// Key for deduplicating symbol and intermediate nodes: (slot, i, j).
struct SPPFNodeKey: Hashable {
    let slot: GrammarNode
    let i: CharPosition
    let j: CharPosition
}

// MARK: - SPPF Extractor

/// Extracts an SPPF (Shared Packed Parse Forest) from the BSR yield stored
/// in each GrammarNode. The SPPF is a compact DAG that represents all parse
/// trees simultaneously through node sharing and packed nodes for ambiguity.
///
/// The algorithm follows the paper "Derivation representation using binary
/// subtree sets" (Scott, 2008). It works as a fixpoint iteration:
///   1. Create a root symbol node (S, 0, n) for the start symbol.
///   2. While there are extendable leaf nodes in the graph:
///      a. For nonterminal leaves: find all matching alternates and create
///         packed nodes with binary decomposition (left prefix, right last-symbol).
///      b. For bracket leaves: expand iteration structure (empty/single/multi).
///      c. For intermediate leaves: decompose using BSR pivot evidence.
///   3. Node sharing via findOrCreateNode ensures the forest remains compact.
///
/// The SPPF uses binary decomposition: each packed node has at most two children
/// (left = prefix of symbols, right = last symbol). This is in contrast to the
/// n-ary parse trees produced by DerivationBuilder.
class SPPFExtractor {
    
    // MARK: - Inputs from parser
    let parser: MessageParser
    let grammar: Grammar
    let input: String

    // MARK: - SPPF extraction state
    var slotIndex: [GrammarNode: Int] = [:]
    var sppfNodes: [SPPFNodeKey: SPPFNode] = [:]
    var sppfAllNodes: [SPPFNode] = []
    var _sppfNonTerminals: [String: GrammarNode] = [:]
    var syntheticEpsilonNode: GrammarNode?

    // MARK: - Initialization

    init(parser: MessageParser, input: String) {
        self.parser = parser
        self.grammar = parser.grammar
        self.input = input
        self._sppfNonTerminals = parser.grammar.nonTerminals
        buildSlotIndex(nonTerminals: parser.grammar.nonTerminals)
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
    
    /// Walk all grammar rules and bracket alternates to build the slotIndex dictionary.
    private func buildSlotIndex(nonTerminals: [String: GrammarNode]) {
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
                if n.kind.isBracket {
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
    
    // MARK: - BSR Helpers
    
    /// All valid end positions for a symbol starting at `from`, derived from BSR evidence
    /// stored in each GrammarNode's yield set.
    ///
    /// - Terminals: span exactly one token (from → from+1) if the token kind matches.
    ///   Schrödinger tokens (ambiguous scanner matches) are checked via the dual chain.
    /// - Nonterminals: the LHS node's yield gives all spans starting at `from`.
    /// - Brackets: follow the iteration chain (k→j) through the bracket's yield.
    ///   For closures (KLN/POS), chain through multiple iterations via BFS.
    ///   Nullable brackets (KLN/OPT) also include `from` itself (empty match).
    /// - Epsilon: matches only at `from` (empty span).
    private func endPositions(_ symbol: GrammarNode, from: CharPosition) -> Set<CharPosition> {
        switch symbol.kind {
        case .T, .TI, .C, .B:
            var positions: Set<CharPosition> = []
            for span in parser.yield(of: symbol) where span.k == from { positions.insert(span.j) }
            return positions
        case .N:
            guard let lhs = symbol.alt else { return [] }
            var positions: Set<CharPosition> = []
            for span in parser.yield(of: lhs) where span.i == from { positions.insert(span.j) }
            return positions
        case .DO, .OPT, .KLN, .POS:
            var positions: Set<CharPosition> = []
            if symbol.kind == .KLN || symbol.kind == .OPT { positions.insert(from) }
            var visited: Set<CharPosition> = []
            var queue = [from]
            while !queue.isEmpty {
                let pos = queue.removeFirst()
                guard visited.insert(pos).inserted else { continue }
                for span in parser.yield(of: symbol) where span.k == pos {
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
    
    /// Chain through a sequence of symbols to find all possible end positions.
    /// Starting from `start`, for each symbol in order, collect where it could end
    /// given all possible start positions from the previous symbol.
    private func chainEndPositions(symbols: [GrammarNode], from start: CharPosition) -> Set<CharPosition> {
        var positions: Set<CharPosition> = [start]
        for symbol in symbols {
            var nextPositions: Set<CharPosition> = []
            for pos in positions {
                nextPositions.formUnion(endPositions(symbol, from: pos))
            }
            positions = nextPositions
        }
        return positions
    }
    
    // MARK: - SPPF Extraction Algorithm
    
    /// Extract an SPPF from the BSR yield, following the paper's algorithm.
    ///
    /// The algorithm is a fixpoint iteration over a growing graph:
    /// 1. Seed with a root symbol node for the start nonterminal.
    /// 2. Repeatedly find leaf nodes that haven't been extended yet.
    /// 3. Extend each leaf by looking up BSR evidence and creating packed nodes.
    /// 4. Stop when no new extendable leaves remain.
    ///
    /// Returns the root SPPFNode, or nil if no parse exists.
    func extractSPPF() -> SPPFNode? {
        let startSymbol = grammar.root
        let extent = input.endIndex  // exclude EOS — EOS token's startIndex == input.endIndex
        let origin = input.startIndex

        // Clear previous SPPF
        sppfNodes = [:]
        sppfAllNodes = []

        // Paper: if Υ has an element of the form (S ::= α, 0, k, n)
        guard parser.yield(of: startSymbol).contains(where: { $0.i == origin && $0.j == extent }) else {
            trace("SPPF: no complete parse found for \(startSymbol.name) spanning 0..\(extent)")
            return nil
        }

        // Paper: create a node labelled (S, 0, n) in G
        let root = findOrCreateNode(kind: .symbol, slot: startSymbol, i: origin, j: extent)
        
        // Paper: while G has an extendable leaf node
        // Each pass may create new nodes, so we snapshot and repeat until stable.
        var changed = true
        while changed {
            changed = false
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
    
    /// Extend an extendable leaf node by creating packed nodes based on BSR evidence.
    ///
    /// Three cases:
    ///   1. Nonterminal symbol node: find all matching alternates, decompose each
    ///      into binary form (prefix + last symbol) with pivot positions.
    ///   2. Bracket symbol node: expand iteration structure (empty/single/multi).
    ///   3. Intermediate node: look up BSR pivots for the grammar slot.
    private func extendNode(_ w: SPPFNode) {
        let i = w.i
        // w is extendable (symbol or intermediate) so j is never nil; packed
        // nodes carry `nil` for j but are never extended.
        let j = w.j!
        
        if w.isNonterminal {
            // Paper: μ is a nonterminal X
            // In our parser, the complete-rule BSR (X, i, k, j) always has k == i
            // (it stores cU, the cluster index). So mkPNforCompleteRule searches
            // the intermediate BSRs to find actual split points for each alternate.
            let X = w.slot
            if parser.yield(of: X).contains(where: { $0.i == i && $0.j == j }) {
                mkPNforCompleteRule(lhs: X, i: i, j: j, parent: w)
            }
        } else if w.kind == .symbol && w.slot.kind.isBracket {
            // Bracket symbol node acting as anonymous nonterminal.
            // Uses bracket-specific expansion that understands iteration structure.
            extendBracketNode(w)
        } else {
            // Paper: μ is X ::= α · δ (an intermediate node)
            let slot = w.slot
            guard let alphaLen = slotIndex[slot] else {
                trace("SPPF: no slot index for \(slot) kind=\(slot.kind)")
                return
            }
            
            if alphaLen == 1 {
                // Paper: if (|α| = 1) mkPN(X ::= α · δ, i, i, j, G)
                // Single symbol before the dot — pivot is at left extent.
                mkPN(slot: slot, i: i, k: i, j: j, parent: w)
            } else if slot.kind.isBracket {
                // Bracket as last symbol of a multi-symbol prefix:
                // BSR pivots for brackets represent iteration starts, not the split
                // between predecessor and bracket. Find where the bracket begins
                // by looking at the predecessor symbol's end positions.
                if let prevSymbol = predecessorSlot(of: slot, steps: 1) {
                    for k in endPositions(prevSymbol, from: i) {
                        mkPN(slot: slot, i: i, k: k, j: j, parent: w)
                    }
                }
            } else {
                // Paper: for each (α, i, k, j) ∈ Υ { mkPN(X ::= α · δ, i, k, j, G) }
                // Look up BSR evidence directly from the slot's yield.
                for span in parser.yield(of: slot) where span.i == i && span.j == j {
                    mkPN(slot: slot, i: i, k: span.k, j: j, parent: w)
                }
            }
        }
    }
    
    /// Extend a bracket (DO/OPT/KLN/POS) symbol node.
    ///
    /// Brackets produce per-iteration BSRs: (bracket, outer_cU, iteration_start, iteration_end).
    /// The SPPF is built left-associatively:
    ///   - Empty match (KLN/OPT only): packed node → ε
    ///   - Single iteration (k == i): packed node → alternate content
    ///   - Multiple iterations: packed node → (bracket(i,k), alternate_content(k,j))
    ///     where k is the last iteration start, creating recursive bracket structure.
    private func extendBracketNode(_ w: SPPFNode) {
        let bracket = w.slot
        let bodyEnd = bracket.bracketEndNode!  // END node = {τ·} slot
        let i = w.i
        // w is a bracket symbol node; only packed nodes carry nil for j.
        let j = w.j!
        
        if i == j {
            // Empty match (KLN/OPT matching nothing) — create packed node with ε child
            let packedNode = SPPFNode(kind: .packed, slot: bodyEnd, i: i, j: nil)
            w.children.append(packedNode)
            sppfAllNodes.append(packedNode)
            
            let epsNode = findOrCreateEpsilonSymbolNode(at: i)
            packedNode.children.append(epsNode)
            return
        }
        
        // Find last iteration starts: BSR spans ending at j give us iteration boundaries.
        var lastIterationStarts: Set<CharPosition> = []
        for span in parser.yield(of: bracket) where span.j == j {
            lastIterationStarts.insert(span.k)
        }
        
        // Filter to starts reachable from i through the bracket's iteration chain.
        let bracketReach = endPositions(bracket, from: i)
        let reachableStarts = lastIterationStarts.filter { k in
            k >= i && k < j && (k == i || bracketReach.contains(k))
        }
        
        for k in reachableStarts {
            if k == i {
                // Single iteration: bracket content matches i→j directly.
                mkBracketIterationContent(bracket: bracket, i: i, j: j, parent: w)
            } else {
                // Multiple iterations: left = bracket(i, k), right = last iteration content(k, j)
                let packedNode = SPPFNode(kind: .packed, slot: bodyEnd, i: k, j: nil)
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
    
    /// Create the SPPF content for one iteration of a bracket spanning (i, j).
    /// Searches the bracket's alternates to find which one matched and decomposes it
    /// into binary form, mirroring mkPNforCompleteRule but for bracket bodies.
    private func mkBracketIterationContent(bracket: GrammarNode, i: CharPosition, j: CharPosition, parent: SPPFNode) {
        let bodyEnd = bracket.bracketEndNode!  // END node = {τ·} slot
        
        // Walk the bracket's alternates
        var altNode = bracket.alt
        while let alt = altNode {
            defer { altNode = alt.alt }
            
            let symbols = alt.bodySymbols
            guard !symbols.isEmpty else { continue }
            
            let last = symbols.last!
            
            if symbols.count == 1 {
                // Single-symbol alternate: check for BSR evidence
                let spans = parser.yield(of: last).filter { $0.i == i && $0.j == j }
                if spans.contains(where: { $0.k == i }) {
                    if parent.kind == .packed {
                        let child = makeSymbolOrIntermediateNode(for: last, i: i, j: j)
                        parent.children.append(child)
                    } else {
                        // Parent is the bracket symbol node (single iteration case)
                        let packedNode = SPPFNode(kind: .packed, slot: bodyEnd, i: i, j: nil)
                        parent.children.append(packedNode)
                        sppfAllNodes.append(packedNode)
                        
                        let child = makeSymbolOrIntermediateNode(for: last, i: i, j: j)
                        packedNode.children.append(child)
                    }
                }
            } else {
                // Multi-symbol alternate: find pivots and decompose
                let lastSpans = parser.yield(of: last).filter { $0.i == i && $0.j == j }
                for span in lastSpans {
                    let k = span.k
                    
                    if parent.kind == .packed {
                        // Already inside a packed node (multi-iteration case).
                        // Create an intermediate node for the bracket body.
                        let intermediateChild = findOrCreateNode(kind: .intermediate, slot: last, i: i, j: j)
                        parent.children.append(intermediateChild)
                    } else {
                        // Parent is the bracket symbol node (single iteration case)
                        let packedNode = SPPFNode(kind: .packed, slot: bodyEnd, i: k, j: nil)
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
    
    /// Find or create an epsilon symbol node at position `pos`.
    private func findOrCreateEpsilonSymbolNode(at pos: CharPosition) -> SPPFNode {
        // Try to find an existing EPS grammar node in the grammar
        if syntheticEpsilonNode == nil {
            outer: for (_, nt) in _sppfNonTerminals {
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
            syntheticEpsilonNode = GrammarNode(kind: .EPS, name: "ε")
        }
        
        let node = findOrCreateNode(kind: .symbol, slot: syntheticEpsilonNode!, i: pos, j: pos)
        node.extended = true
        return node
    }
    
    /// Paper: mkPN(X ::= α · δ, i, k, j, G)
    /// Creates a packed node labelled with the grammar slot and pivot k,
    /// then decomposes α = βx into right child (x, k→j) and left child.
    ///
    /// The binary decomposition:
    ///   - Right child: always the last symbol x of α, spanning (k, j)
    ///   - Left child depends on |β|:
    ///     - |β| = 0: no left child (single symbol, handled elsewhere)
    ///     - |β| = 1: symbol node for β, spanning (i, k)
    ///     - |β| > 1: intermediate node for the slot before x, spanning (i, k)
    private func mkPN(slot: GrammarNode, i: CharPosition, k: CharPosition, j: CharPosition, parent: SPPFNode) {
        // Paper: make a node y in G labelled (X ::= α · δ, k)
        let packedNode = SPPFNode(kind: .packed, slot: slot, i: k, j: nil)
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
    /// Search through X's alternates to find which ones have BSR evidence for this span,
    /// and create packed nodes with binary decomposition for each valid alternate.
    ///
    /// For single-symbol alternates: check direct BSR evidence at the last symbol.
    /// For multi-symbol alternates: find pivot positions by chaining through prefix
    /// symbols' end positions, then validate the last symbol can reach j.
    private func mkPNforCompleteRule(lhs: GrammarNode, i: CharPosition, j: CharPosition, parent: SPPFNode) {
        var altNode = lhs.alt
        while let alt = altNode {
            defer { altNode = alt.alt }
            
            let symbols = alt.bodySymbols
            guard !symbols.isEmpty else { continue }
            
            let last = symbols.last!
            let symbolCount = symbols.count
            
            if symbolCount == 1 {
                // Single-symbol alternate: pivot is i, the only child spans (i, j)
                let spans = parser.yield(of: last).filter { $0.i == i && $0.j == j }
                let hasDirect = spans.contains { $0.k == i }
                let hasBracket = last.kind.isBracket && !spans.isEmpty
                
                if hasDirect || hasBracket {
                    let packedNode = SPPFNode(kind: .packed, slot: last, i: i, j: nil)
                    parent.children.append(packedNode)
                    sppfAllNodes.append(packedNode)
                    
                    let child = makeSymbolOrIntermediateNode(for: last, i: i, j: j)
                    packedNode.children.append(child)
                }
            } else {
                // Multi-symbol alternate: find pivot positions where last symbol starts.
                // Chain through prefix symbols to find reachable positions, then validate
                // that the last symbol can actually reach j from that position.
                var pivots = chainEndPositions(symbols: Array(symbols.dropLast()), from: i)
                if last.kind == .KLN || last.kind == .OPT { pivots.insert(j) }
                pivots = pivots.filter { $0 >= i && $0 <= j }
                
                for k in pivots where endPositions(last, from: k).contains(j) {
                    let packedNode = SPPFNode(kind: .packed, slot: last, i: k, j: nil)
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
    
    /// Handle mkPN for an intermediate slot BSR.
    /// Decomposes α = βx where x is the slot (last symbol of α):
    ///   - Right child: symbol/intermediate node for x spanning (k, j)
    ///   - Left child: depends on |β| (see mkPN documentation)
    private func mkPNforSlot(slot: GrammarNode, i: CharPosition, k: CharPosition, j: CharPosition, packedNode: SPPFNode) {
        guard let alphaLen = slotIndex[slot] else { return }
        
        // Paper: α = βx where |x| = 1
        let betaLen = alphaLen - 1
        
        // Right child: mkN(x, k, j, y, G)
        let rightChild = makeSymbolOrIntermediateNode(for: slot, i: k, j: j)
        packedNode.children.append(rightChild)
        
        if betaLen == 1 {
            // Paper: if (|β| = 1) mkN(β, i, k, y, G)
            if let prevSymbol = predecessorSlot(of: slot, steps: 1) {
                let leftChild = makeSymbolOrIntermediateNode(for: prevSymbol, i: i, j: k)
                packedNode.children.append(leftChild)
            }
        } else if betaLen > 1 {
            // Paper: if (|β| > 1) mkN(X ::= β · xδ, i, k, y, G)
            if let prevSlot = predecessorSlot(of: slot, steps: 1) {
                let leftChild = findOrCreateNode(kind: .intermediate, slot: prevSlot, i: i, j: k)
                packedNode.children.append(leftChild)
            }
        }
        // if betaLen == 0: no left child (single-symbol case handled in extendNode)
    }
    
    /// Create the appropriate SPPF node for a grammar symbol:
    ///   - RHS nonterminal → symbol node for its LHS definition (enables sharing)
    ///   - Terminal/epsilon → symbol node (marked as non-extendable)
    ///   - Bracket → symbol node (acts like anonymous nonterminal)
    ///   - Other → intermediate node (grammar slot position)
    private func makeSymbolOrIntermediateNode(for node: GrammarNode, i: CharPosition, j: CharPosition) -> SPPFNode {
        switch node.kind {
        case .N:
            if node.isLHS {
                return findOrCreateNode(kind: .symbol, slot: node, i: i, j: j)
            } else {
                // RHS nonterminal: redirect to the LHS definition for node sharing
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
    
    /// Paper: mkN(Ω, i, j, y, G) — find or create a node labelled (Ω, i, j).
    /// Node deduplication ensures the SPPF remains a compact DAG rather than a tree.
    private func findOrCreateNode(kind: SPPFNodeKind, slot: GrammarNode, i: CharPosition, j: CharPosition) -> SPPFNode {
        let key = SPPFNodeKey(slot: slot, i: i, j: j)
        if let existing = sppfNodes[key] {
            return existing
        }
        let node = SPPFNode(kind: kind, slot: slot, i: i, j: j)
        sppfNodes[key] = node
        sppfAllNodes.append(node)
        return node
    }
}

// MARK: - Graphviz SPPF Diagram Generation

/// Generate a Graphviz dot file for the SPPF.
/// Node shapes follow the paper's conventions:
///   - Symbol nodes (nonterminals, terminals): rounded rectangles
///   - Intermediate nodes (grammar slots): rectangles
///   - Packed nodes: rectangles (labelled with pivot)
func generateSPPFDiagram(outputFile file: URL, root: SPPFNode) throws {
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
            if node.slot.kind == .EPS {
                dot += "  \(id) [shape = box, style = \"rounded, dashed\", width=0.0, height=0.0, label = <\(escapedLabel)>]\n"
            } else if node.slot.kind.isBracket {
                // Bracket closure subtree roots display as intermediate nodes (rectangles)
                dot += "  \(id) [shape = rectangle, width=0.0, height=0.0, label = <\(escapedLabel)>]\n"
            } else {
                dot += "  \(id) [shape = box, style = rounded, width=0.0, height=0.0, label = <\(escapedLabel)>]\n"
            }
        case .intermediate:
            dot += "  \(id) [shape = rectangle, width=0.0, height=0.0, label = <\(escapedLabel)>]\n"
        case .packed:
            dot += "  \(id) [shape = rectangle, width=0.0, height=0.0, label = \"\(escapedLabel)\"]\n"
        }
    }
    
    // Emit edges — sort children by left extent so leaves read left-to-right
    for node in allReachable {
        let parentID = nodeID(node)
        let sortedChildren = node.children.sorted { $0.i < $1.i }
        for child in sortedChildren {
            let childID = nodeID(child)
            dot += "  \(parentID) -> \(childID)\n"
        }
    }
    
    dot += "}\n"
    
    try dot.write(to: file, atomically: true, encoding: .utf8)
}
