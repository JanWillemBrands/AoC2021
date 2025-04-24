//
//  GraphStructuredStack.swift
//  Advent
//
//  Created by Johannes Brands on 26/12/2024.
//

import Foundation

final class StackNode: Hashable, CustomStringConvertible, Comparable {
    let slot: GrammarNode
    let index: Int
    //    var edges: [Edge] = []
    //    var edges: Set<Edge> = []
//    var edges: Set<StackNode> = []
    var edges: [StackNode] = []             // using an Array instead of a Set of edges is ~10% faster
    var pops: Set<Int> = []
    var unique: Set<SlotIndex> = []         // distributing 'unique' sets (U) in the StackNodes is ~20% faster than one global 'unique' set
    
    init(slot: GrammarNode, index: Int) {
        self.slot = slot
        self.index = index
    }
    static func == (lhs: StackNode, rhs: StackNode) -> Bool {
        lhs.slot == rhs.slot && lhs.index == rhs.index
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(slot)
        hasher.combine(index)
    }
    var description: String {
//        if slot.kind == .EOS { return "00" }
        return slot.description + "." + index.description
//        return slot.description + index.description
    }
    var ebnfDot: String {
        return slot.ebnfDot() + "," + index.description
    }
    static func < (lhs: StackNode, rhs: StackNode) -> Bool {
        lhs.description < rhs.description
    }
}

// TODO: simplify!  does Edge need all this?
//struct Edge: CustomStringConvertible, Comparable {
struct Edge: Hashable, CustomStringConvertible, Comparable {
    let towards: StackNode
    //    var dummy: [GrammarNode] = []
    init(towards: StackNode) {
        self.towards = towards
    }
    //    static func == (lhs: Edge, rhs: Edge) -> Bool {
    //        lhs.towards == rhs.towards
    //    }
    //    func hash(into hasher: inout Hasher) {
    //        hasher.combine(towards)
    //    }
    var description: String {
        towards.description
    }
    static func < (lhs: Edge, rhs: Edge) -> Bool {
        lhs.towards < rhs.towards
    }
}

struct Descriptor: Hashable {
    let slot: GrammarNode
    let stack: StackNode
    let index: Int
}

// TODO: replace with tuple?
struct SlotIndex: Hashable, CustomStringConvertible {
    let slot: GrammarNode
    let index: Int
    var description: String { slot.description + index.description }
}

//struct BSR: Hashable, CustomStringConvertible {
//    let node: GrammarNode
//    let i: Int  // left
//    let k: Int  // pivot
//    let j: Int  // right
//    var description: String { "\(node) \(i):\(k):\(j)" }
//}
//
//var yield : Set<BSR> = []   // currentYield_Cn_ϒ_𝛶_BSR

// create a GSS node if it doesn't already exist
// add an edge from that node to the current stack top
// add descriptors for previous pop actions from that node
func call(slot: GrammarNode) {
    trace = false
    #if DEBUG
    trace("call", slot)
    #endif
    let sn = StackNode(slot: slot.seq!, index: currentIndex)
    let topStack = gss.insert(sn).memberAfterInsert
    //    let edge = Edge(towards: currentStack)
    #if DEBUG
    trace("create edge from \(topStack) to \(currentStack)")
    #endif

    assert(!topStack.edges.contains(currentStack), "Afroozeh was wrong, edge \(currentStack) was already in node \(topStack) \(topStack.edges)")
//    if topStack.edges.contains(currentStack) {
//        print("duplicate edge to \(currentStack.ebnfDot) from \(topStack.ebnfDot)")
//    }
//    topStack.edges.insert(currentStack)
    topStack.edges.append(currentStack)
    
    for pop in topStack.pops {
        #if DEBUG
        trace("contingent pop")
        #endif
        addDescriptor(slot: slot.seq!, stack: currentStack, index: pop)
    }
    
    // only add a descriptor for the first alternative of the nonterminal, the other alternatives will follow in parseMessage()
    addDescriptor(slot: slot.alt!, stack: topStack, index: currentIndex)
}

func enter() {
    let sn = StackNode(slot: currentSlot.seq!, index: currentIndex)
    let newStack = gss.insert(sn).memberAfterInsert
    newStack.edges.append(currentStack)
//    newStack.edges.insert(currentStack)
    for pop in newStack.pops {
        addDescriptor(slot: currentSlot.seq!, stack: currentStack, index: pop)
    }
    addDescriptor(slot: currentSlot.alt!, stack: newStack, index: currentIndex)
}

// TODO: the first edge can be popped without addDescriptor
func ret() {
    #if DEBUG
    trace("ret", currentStack)
    if currentIndex == tokens.count - 1 && currentStack == gssRoot {
        successfullParses += 1
        trace("HURRAH token = \(token)", terminator: "\n")
    } else {
        currentStack.pops.insert(currentIndex)
        for edge in currentStack.edges {
            trace("pop \(edge)")
            //            addDescriptor(slot: currentStack.slot, stack: edge.towards, index: currentIndex)
            addDescriptor(slot: currentStack.slot, stack: edge, index: currentIndex)
        }
    }
    #else
    if currentIndex == tokens.count - 1 && currentStack == gssRoot {
        successfullParses += 1
    } else {
        currentStack.pops.insert(currentIndex)
        for edge in currentStack.edges {
            //            addDescriptor(slot: currentStack.slot, stack: edge.towards, index: currentIndex)
            addDescriptor(slot: currentStack.slot, stack: edge, index: currentIndex)
        }
    }
    #endif
}

// TODO: the first edge can be popped without addDescriptor???
// TODO: only add decriptors when the token is part of the follow???
func leave() {
    if currentIndex == tokens.count - 1 && currentStack == gssRoot {
        successfullParses += 1
    } else {
        currentStack.pops.insert(currentIndex)
        for edge in currentStack.edges {
            addDescriptor(slot: currentStack.slot, stack: edge, index: currentIndex)
        }
    }
}

func addDescriptor(slot: GrammarNode, stack: StackNode, index: Int) {
    let si = SlotIndex(slot: slot, index: index)
    let d = Descriptor(slot: slot, stack: stack, index: index)
//    print("addDescriptor: \(d)")
    if stack.unique.insert(si).inserted {
        remainder.append(d)
        descriptorCount += 1
    } else {
        duplicateDescriptorCount += 1
    }
}

func getDescriptor() -> Bool {
    if remainder.isEmpty { return false }
    let d = remainder.removeLast()
    currentSlot = d.slot
    currentStack = d.stack
    currentIndex = d.index
    return true
}
