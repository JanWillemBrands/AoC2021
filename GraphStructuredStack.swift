////
////  GraphStructuredStack.swift
////  Advent
////
////  Created by Johannes Brands on 26/12/2024.
////
//
//import Foundation
//
//final class StackNode: Hashable, CustomStringConvertible, Comparable {
//    let slot: GrammarNode
//    let index: Int
//    //    var edges: [Edge] = []
//    //    var edges: Set<Edge> = []
////    var edges: Set<StackNode> = []
//    var edges: [StackNode] = []             // using an Array instead of a Set of edges is ~10% faster
//    var pops: Set<Int> = []
//    var unique: Set<Position> = []         // distributing the 'unique' set (U) of Descriptors in the StackNodes is ~20% faster than one global 'unique' set
//    
//    init(slot: GrammarNode, index: Int) {
//        self.slot = slot
//        self.index = index
//    }
//    static func == (lhs: StackNode, rhs: StackNode) -> Bool {
//        lhs.slot == rhs.slot && lhs.index == rhs.index
//    }
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(slot)
//        hasher.combine(index)
//    }
//    var description: String {
//        if slot.kind == .EOS { return "00" }
//        return slot.description + "." + index.description
////        return slot.description + index.description
//    }
//    var ebnfDot: String {
//        return slot.ebnfDot() + "," + index.description
//    }
//    static func < (lhs: StackNode, rhs: StackNode) -> Bool {
//        lhs.description < rhs.description
//    }
//}
//
//// TODO: simplify!  does Edge need all this?
////struct Edge: CustomStringConvertible, Comparable {
//struct Edge: Hashable, CustomStringConvertible, Comparable {
//    let towards: StackNode
//    //    var dummy: [GrammarNode] = []
//    init(towards: StackNode) {
//        self.towards = towards
//    }
//    //    static func == (lhs: Edge, rhs: Edge) -> Bool {
//    //        lhs.towards == rhs.towards
//    //    }
//    //    func hash(into hasher: inout Hasher) {
//    //        hasher.combine(towards)
//    //    }
//    var description: String {
//        towards.description
//    }
//    static func < (lhs: Edge, rhs: Edge) -> Bool {
//        lhs.towards < rhs.towards
//    }
//}
//
//// create a GSS node if it doesn't already exist
//// add an edge from that node to the current stack top
//// add descriptors for previous pop actions from that node
//func call(slot: GrammarNode) {
//    trace = false
//    #if DEBUG
//    trace("call", slot)
//    #endif
//    let sn = StackNode(slot: slot.seq!, index: currentIndex)
//    let topStack = gss.insert(sn).memberAfterInsert
//    //    let edge = Edge(towards: currentCluster)
//    #if DEBUG
//    trace("create edge from \(topStack) to \(currentCluster)")
//    #endif
//
//    assert(!topStack.edges.contains(currentCluster), "Afroozeh was wrong, edge \(currentCluster) was already in node \(topStack) \(topStack.edges)")
////    if topStack.edges.contains(currentCluster) {
////        print("duplicate edge to \(currentCluster.ebnfDot) from \(topStack.ebnfDot)")
////    }
////    topStack.edges.insert(currentCluster)
//    topStack.edges.append(currentCluster)
//    
//    for pop in topStack.pops {
//        #if DEBUG
//        trace("contingent pop")
//        #endif
//        addDescriptor(slot: slot.seq!, stack: currentCluster, index: pop)
//        addYield(slot.seq!, currentIndex, currentCluster.index, pop)
//    }
//    
//    // only add a descriptor for the first alternative of the nonterminal, the other alternatives will follow in parseMessage()
//    addDescriptor(slot: slot.alt!, stack: topStack, index: currentIndex)
//}
//
//// TODO: the first edge can be popped without addDescriptor
//func ret() {
//    #if DEBUG
//    trace("ret", currentCluster)
//    if currentIndex == tokens.count - 1 && currentCluster == gssRoot {
//        successfullParses += 1
//        trace("HURRAH token = \(token)", terminator: "\n")
//    } else {
//        currentCluster.pops.insert(currentIndex)
//        for edge in currentCluster.edges {
//            trace("pop \(edge)")
//            //            addDescriptor(slot: currentCluster.slot, stack: edge.towards, index: currentIndex)
//            addDescriptor(slot: currentCluster.slot, stack: edge, index: currentIndex)
//            addYield(currentCluster.slot, edge.index, currentCluster.index, currentIndex)
//        }
//    }
//    #else
//    if currentIndex == tokens.count - 1 && currentCluster == gssRoot {
//        successfullParses += 1
//    } else {
//        currentCluster.pops.insert(currentIndex)
//        for edge in currentCluster.edges {
//            //            addDescriptor(slot: currentCluster.slot, stack: edge.towards, index: currentIndex)
//            addDescriptor(slot: currentCluster.slot, stack: edge, index: currentIndex)
//        }
//    }
//    #endif
//}
