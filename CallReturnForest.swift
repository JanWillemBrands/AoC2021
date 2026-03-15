//
//  CallReturnForest.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

// "Derivation representation using binary subtree sets"
// https://pure.royalholloway.ac.uk/ws/portalfiles/portal/33174042/Accepted_Manuscript.pdf

// Paper: CRF = Call Return Forest
// Paper: P = contingent return set (pops)
// Paper: cL = current grammar slot, cI = current input index, cU = current cluster index

import Foundation


// Lightweight value type for CRF dictionary keys or
// a return edge in the CRF. Matches the paper's crfNode (L, i).
public struct Position: Hashable, Comparable, CustomStringConvertible {
    public let slot: GrammarNode
    public let index: Int
    
    public var description: String {
        slot.description + "." + index.description
    }
    
    var ebnfDot: String {
        slot.ebnfDot() + "," + index.description
    }
    
    public static func < (lhs: Position, rhs: Position) -> Bool {
        lhs.description < rhs.description
    }
}

// A return edge in the CRF. Matches the paper's crfNode (L, i).
//public struct Position: Hashable, CustomStringConvertible {
//    public let slot: GrammarNode       // L: the RHS nonterminal call site
//    public let index: Int              // i: the caller's cluster index
//    
//    public var description: String {
//        slot.description + "." + index.description
//    }
//}

// Cluster node in the CRF. Mutable, identity-based.
// Represents clusterNode (X, k) from the paper.
public final class Cluster: CustomStringConvertible {
    public let slot: GrammarNode   // the LHS nonterminal (X)
    public let index: Int          // input position (k)
    
    var returns: Set<Position> = []
    var pops: Set<Int> = []        // Paper: P — contingent returns
    
    init(slot: GrammarNode, index: Int) {
        self.slot = slot
        self.index = index
    }
    
    public var description: String {
        slot.description + "." + index.description
    }
    
    var ebnfDot: String {
        slot.ebnfDot() + "," + index.description
    }
}


// MARK: - MessageParser CRF Operations

extension MessageParser {

    // Paper: ntAdd(X, j) — add descriptors for all alternates of a bracket/nonterminal
    func addDecscriptorsForAlternates(X: GrammarNode, k: Int, i: Int) {
        assert([.N, .DO, .OPT, .ALT, .KLN, .POS].contains(X.kind), "Called \(#function) on a GrammarNode \(X) which is not a bracket")
        var current = X.alt
        while let alt = current {
            if testSelect(slot: alt, bracket: X) {
                addDescriptor(L: alt.seq!, k: k, i: i)
            }
            current = alt.alt
        }
    }
    
    // Paper: call(L, i, j) — enter a nonterminal
    func call() {
        // cL points to the RHS nonterminal node
        // cL.alt points to the LHS nonterminal node
        
        // Create the return edge: (L=cL, i=cU)
        let returnEdge = Position(slot: cL, index: cU)
        
        // Find or create the cluster node for (X=cL.alt!, k=cI)
        let clusterKey = Position(slot: cL.alt!, index: cI)
        
        if let existingCluster = crf[clusterKey] {
            // Cluster already exists — add the return edge if new
            if existingCluster.returns.insert(returnEdge).inserted {
                // Add descriptors for previous pop actions from that cluster
                for pop in existingCluster.pops {
                    addDescriptor(L: cL.seq!, k: cU, i: pop)
                    addYield(L: cL, i: cU, k: cI, j: pop)
                }
            }
        } else {
            // Create new cluster
            let newCluster = Cluster(slot: cL.alt!, index: cI)
            crf[clusterKey] = newCluster
            newCluster.returns.insert(returnEdge)
            addDecscriptorsForAlternates(X: cL.alt!, k: cI, i: cI)
        }
    }
    
    // Paper: rtn(X, k, j) — return from a nonterminal
    func rtn(X: GrammarNode) {
        let clusterKey = Position(slot: X, index: cU)
        guard let cluster = crf[clusterKey] else { return }
        
        if cluster.pops.insert(cI).inserted {
            for rtn in cluster.returns {
                addDescriptor(L: rtn.slot.seq!, k: rtn.index, i: cI)
                addYield(L: rtn.slot, i: rtn.index, k: cU, j: cI)
            }
        }
    }
    
    // bracketCall — enter a bracket (DO, OPT, KLN, POS)
    // Similar to call() but the bracket node IS the "nonterminal" — no indirection through .alt
    func bracketCall(bracket: GrammarNode) {
        // Create return edge: (L=bracket, i=cU) — records where to return
        let returnEdge = Position(slot: bracket, index: cU)
        
        // Find or create cluster for (bracket, cI)
        let clusterKey = Position(slot: bracket, index: cI)
        
        if let existingCluster = crf[clusterKey] {
            if existingCluster.returns.insert(returnEdge).inserted {
                for pop in existingCluster.pops {
                    // Continue past bracket with restored outer cU
                    addDescriptor(L: bracket.seq!, k: cU, i: pop)
                    addYield(L: bracket, i: cU, k: cI, j: pop)
                }
            }
        } else {
            let newCluster = Cluster(slot: bracket, index: cI)
            crf[clusterKey] = newCluster
            newCluster.returns.insert(returnEdge)
            // Dispatch alternates inside the bracket
            addDecscriptorsForAlternates(X: bracket, k: cI, i: cI)
        }
    }
    
    // bracketRtn — return from a bracket
    // Similar to rtn() but also handles KLN/POS re-entry
    func bracketRtn(bracket: GrammarNode) {
        let clusterKey = Position(slot: bracket, index: cU)
        guard let cluster = crf[clusterKey] else { return }
        
        if cluster.pops.insert(cI).inserted {
            for rtn in cluster.returns {
                // BSR for the bracket span
                addYield(L: rtn.slot, i: rtn.index, k: cU, j: cI)
                // Continue past the bracket
                addDescriptor(L: rtn.slot.seq!, k: rtn.index, i: cI)
            }
            
            // KLN/POS: re-enter the bracket for another iteration.
            // Each iteration gets its own cluster at (bracket, cI).
            // The new cluster inherits the SAME return edges as the current cluster,
            // so that when the next iteration pops, it goes directly back to the
            // original outer caller(s) — not through a chain of iterations.
            if bracket.kind == .KLN || bracket.kind == .POS {
                let nextKey = Position(slot: bracket, index: cI)
                
                if let existingCluster = crf[nextKey] {
                    for returnEdge in cluster.returns {
                        if existingCluster.returns.insert(returnEdge).inserted {
                            for pop in existingCluster.pops {
                                addYield(L: returnEdge.slot, i: returnEdge.index, k: cI, j: pop)
                                addDescriptor(L: returnEdge.slot.seq!, k: returnEdge.index, i: pop)
                            }
                        }
                    }
                } else {
                    let newCluster = Cluster(slot: bracket, index: cI)
                    crf[nextKey] = newCluster
                    newCluster.returns = cluster.returns
                    addDecscriptorsForAlternates(X: bracket, k: cI, i: cI)
                }
            }
        }
    }
}

