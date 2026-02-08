//
//  CallReturnForest.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

// "Derivation representation using binary subtree sets"
// https://pure.royalholloway.ac.uk/ws/portalfiles/portal/33174042/Accepted_Manuscript.pdf

import Foundation

public var crf: Set<Position> = []
//var crfRoot = Position(slot: grammarRoot, index: 0)

public final class Position: Hashable, Comparable, CustomStringConvertible {
    public let slot: GrammarNode
    public let index: Int

    // lazy avoids initialization overhead for positions that don't need them, instead of using optionals that would complicate code
    lazy var unique: Set<Position> = []         // distributing the 'unique' set (U) of Descriptors is ~20% faster
    lazy var returns: Set<Position> = []        // TODO: an Array instead of a Set is ~10% faster (Afroozeh), but CNP needs it
    lazy var pops: Set<Int> = []
    
    public init(slot: GrammarNode, index: Int) {
        self.slot = slot
        self.index = index
    }
    
    public static func == (lhs: Position, rhs: Position) -> Bool {
        lhs.slot == rhs.slot && lhs.index == rhs.index
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(slot)
        hasher.combine(index)
    }
    
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

func addDescriptorsForAlternates(bracket: GrammarNode, cluster: Position, index: Int) {
    assert([.N, .DO, .ALT, .KLN, .POS].contains(bracket.kind), "Called \(#function) on a GrammarNode \(bracket) which is not a bracket")
    var current = bracket.alt
    while let alt = current {
        if testSelect(slot: alt, bracket: bracket) {
            addDescriptor(slot: alt.seq!, cluster: cluster, index: index)
        }
        current = alt.alt
    }
}

func enter() {
    // currentSlot points to the RHS nonterminal node
    // currentSlot.alt points to the LHS nonterminal node
    // currentslot.alt.alt points to its first alternative
    
    let L = currentSlot
    let i = currentCluster.index
    let j = currentIndex
    // create a return node (u) if it doesn't already exist
    var leavePos = Position(slot: currentSlot, index: currentCluster.index)
    leavePos = crf.insert(leavePos).memberAfterInsert
    
    // create a cluster node (v) if it doesn't already exits
    var clusterPos = Position(slot: currentSlot.alt!, index: currentIndex)
    var inserted: Bool
    (inserted, clusterPos) = crf.insert(clusterPos)

    if inserted {
        clusterPos.returns.insert(leavePos)
        addDescriptorsForAlternates(bracket: currentSlot.alt!, cluster: clusterPos, index: currentIndex)
    } else {
//        assert(!clusterNode.returns.contains(returnNode), "Afroozeh was wrong, edge \(returnNode) was already in node \(clusterNode) \(clusterNode.returns)")

        if clusterPos.returns.insert(leavePos).inserted {
            // add descriptors for previous pop actions from that node
            for pop in currentCluster.pops {
                addDescriptor(slot: currentSlot.seq!, cluster: clusterPos, index: pop)
//                addYield(slot: currentSlot.seq!, i: currentCluster.index, k: currentIndex, j: pop)  // TODO: point leavePos to currentSlot (not currentSlot.seq)
                addYield(slot: currentSlot, i: currentCluster.index, k: currentIndex, j: pop)
            }
        }
    }
    print("enter cluster \(clusterPos) inserted, returns \(clusterPos.returns)")
}

// TODO: the first edge can be popped without addDescriptor???
func leave() {
    let X = currentCluster.slot
    let k = currentCluster.index
    let j = currentIndex
    print("leave cluster \(currentCluster) inserted, returns: \(currentCluster.returns)")
    if currentCluster.pops.insert(currentIndex).inserted {
        for rtn in currentCluster.returns {
            let L = rtn.slot.seq!
            let i = rtn.index
            addDescriptor(slot: rtn.slot.seq!, cluster: currentCluster, index: currentIndex)
            addYield(slot: rtn.slot, i: rtn.index, k: currentCluster.index, j: currentIndex)
        }
    }
}
