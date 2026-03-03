//
//  CallReturnForest.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

// "Derivation representation using binary subtree sets"
// https://pure.royalholloway.ac.uk/ws/portalfiles/portal/33174042/Accepted_Manuscript.pdf

import Foundation

// MARK: - CRF Data Structures

/// Lightweight value type for CRF dictionary keys.
public struct CRFPosition: Hashable, Comparable, CustomStringConvertible {
    public let slot: GrammarNode
    public let index: Int
    
    public var description: String {
        slot.description + "." + index.description
    }
    
    var ebnfDot: String {
        slot.ebnfDot() + "," + index.description
    }
    
    public static func < (lhs: CRFPosition, rhs: CRFPosition) -> Bool {
        lhs.description < rhs.description
    }
}

/// A return edge in the CRF. Matches the paper's crfNode (L, i).
public struct ReturnEdge: Hashable, CustomStringConvertible {
    public let slot: GrammarNode       // L: the RHS nonterminal call site
    public let index: Int              // i: the caller's cluster index
    
    public var description: String {
        slot.description + "." + index.description
    }
}

/// Cluster node in the CRF. Mutable, identity-based.
/// Represents clusterNode (X, k) from the paper.
public final class Cluster: CustomStringConvertible {
    public let slot: GrammarNode   // the LHS nonterminal (X)
    public let index: Int          // input position (k)
    var returns: Set<ReturnEdge> = []
    var pops: Set<Int> = []
    
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

// MARK: - CRF Storage

/// The Call Return Forest: maps cluster key (X, k) to Cluster object.
public var crf: [CRFPosition: Cluster] = [:]

/// Return nodes tracked separately for diagram generation.
public var crfReturnNodes: Set<CRFPosition> = []

// MARK: - CRF Operations

func addDescriptorsForAlternates(bracket: GrammarNode, k: Int, index: Int) {
    assert([.N, .DO, .OPT, .ALT, .KLN, .POS].contains(bracket.kind), "Called \(#function) on a GrammarNode \(bracket) which is not a bracket")
    var current = bracket.alt
    while let alt = current {
        if testSelect(slot: alt, bracket: bracket) {
            addDescriptor(slot: alt.seq!, k: k, index: index)
        }
        current = alt.alt
    }
}

func enter() {
    // currentSlot points to the RHS nonterminal node
    // currentSlot.alt points to the LHS nonterminal node
    
    // Create the return edge: (L=currentSlot, i=currentK)
    let returnEdge = ReturnEdge(slot: currentSlot, index: currentK)
    crfReturnNodes.insert(CRFPosition(slot: currentSlot, index: currentK))
    
    // Find or create the cluster node for (X=currentSlot.alt!, k=currentIndex)
    let clusterKey = CRFPosition(slot: currentSlot.alt!, index: currentIndex)
    
    if let existingCluster = crf[clusterKey] {
        // Cluster already exists — add the return edge if new
        if existingCluster.returns.insert(returnEdge).inserted {
            // Add descriptors for previous pop actions from that cluster
            for pop in existingCluster.pops {
                addDescriptor(slot: currentSlot.seq!, k: currentK, index: pop)
                addYield(slot: currentSlot, i: currentK, k: currentIndex, j: pop)
            }
        }
    } else {
        // Create new cluster
        let newCluster = Cluster(slot: currentSlot.alt!, index: currentIndex)
        crf[clusterKey] = newCluster
        newCluster.returns.insert(returnEdge)
        addDescriptorsForAlternates(bracket: currentSlot.alt!, k: currentIndex, index: currentIndex)
    }
}

/// Called when an END node is reached for a LHS nonterminal.
/// The nonterminal (bracket) is passed so we can look up the cluster.
func leave(nonterminal: GrammarNode) {
    let clusterKey = CRFPosition(slot: nonterminal, index: currentK)
    guard let cluster = crf[clusterKey] else { return }
    
    if cluster.pops.insert(currentIndex).inserted {
        for rtn in cluster.returns {
            addDescriptor(slot: rtn.slot.seq!, k: rtn.index, index: currentIndex)
            addYield(slot: rtn.slot, i: rtn.index, k: currentK, j: currentIndex)
        }
    }
}
