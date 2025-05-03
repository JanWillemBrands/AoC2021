//
//  CallReturnForest.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

// "Derivation representation using binary subtree sets"
// https://pure.royalholloway.ac.uk/ws/portalfiles/portal/33174042/Accepted_Manuscript.pdf

import Foundation
//import OrderedCollections

var crf: Set<Position> = []
var crfRoot = Position(slot: grammarRoot, index: 0)

final class Position: Hashable, Comparable, CustomStringConvertible {
    let slot: GrammarNode
    let index: Int

    // lazy avoids initialization overhead for positions that don't need them, using optionals instead would complicate code
    lazy var unique: Set<Position> = []         // distributing the 'unique' set (U) of Descriptors is ~20% faster
    lazy var returns: Set<Position> = []        // an Array instead of a Set is ~10% faster (Afroozeh), but CNP needs it
    lazy var pops: Set<Int> = []
    
    init(slot: GrammarNode, index: Int) {
        self.slot = slot
        self.index = index
    }
    
    static func == (lhs: Position, rhs: Position) -> Bool {
        lhs.slot == rhs.slot && lhs.index == rhs.index
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(slot)
        hasher.combine(index)
    }
    
    var description: String {
        slot.description + "." + index.description
    }
    
    var ebnfDot: String {
        slot.ebnfDot() + "," + index.description
    }
    
    static func < (lhs: Position, rhs: Position) -> Bool {
        lhs.description < rhs.description
    }
}

func ntAdd(_ pos: Position, _ index: Int) {
    assert(pos.slot.kind == .N, "Called \(#function) on a position \(pos) which is not a nonterminal")
    var alt = pos.slot.alt
    repeat {
        if let alt {
            if testSelect(slot: alt) {
                addDescriptor(slot: alt.seq!, cluster: pos, index: index)
            }
        }
    } while alt != nil
}

// add descriptors for previous pop actions from that node
func enter() {
    // create a return node (u) if it doesn't already exist
    var returnNode = Position(slot: currentSlot.seq!, index: currentIndex)
    returnNode = crf.insert(returnNode).memberAfterInsert
    
    // create a cluster node (v) if it doesn't already exits
    var clusterNode = Position(slot: currentSlot, index: currentCluster.index)
    var inserted: Bool
    (inserted, clusterNode) = crf.insert(clusterNode)

    if inserted {
        clusterNode.returns.insert(returnNode)
        // only add a descriptor for the first alternative of the nonterminal, the other alternatives will follow in parseMessage()
        // addState(slot: currentSlot.alt!, index: currentIndex, cluster: clusterNode)
        // TODO: ntAdd(clusterNode, currentIndex)

        // simply go to the first .alt node
        currentSlot = currentSlot.alt!
        currentCluster = clusterNode
        
    } else {
        assert(!clusterNode.returns.contains(returnNode), "Afroozeh was wrong, edge \(returnNode) was already in node \(clusterNode) \(clusterNode.returns)")

        if clusterNode.returns.insert(returnNode).inserted {
            for pop in currentCluster.pops {
                addDescriptor(slot: currentSlot.seq!, cluster: clusterNode, index: pop)
                addYield(node: currentSlot.seq!, i: currentIndex, k: currentCluster.index, j: pop)
            }
        }
    }
    
}

// TODO: the first edge can be popped without addDescriptor???
// TODO: only add decriptors when the token is part of the follow???
func leave() {
    if currentCluster.pops.insert(currentIndex).inserted {
        for rtn in currentCluster.returns {
            addDescriptor(slot: rtn.slot, cluster: currentCluster, index: currentIndex)
            addYield(node: rtn.slot, i: rtn.index, k: currentCluster.index, j: currentIndex)
        }
    }
}
