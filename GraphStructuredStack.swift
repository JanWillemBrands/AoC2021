//
//  GraphStructuredStack.swift
//  Advent
//
//  Created by Johannes Brands on 26/12/2024.
//

final class StackNode: Hashable, CustomStringConvertible, Comparable {
    let slot: GrammarNode
    let index: Int
    var edges: [Edge] = []
    var pops: Set<Int> = []
    var unique: Set<SlotIndex> = []

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
        if slot.kind == .EOS { return "●○" }
        return slot.description + index.description
    }
    static func < (lhs: StackNode, rhs: StackNode) -> Bool {
        lhs.description < rhs.description
    }
}

// TODO: simplify!  does Edge need all this?
struct Edge: Hashable, CustomStringConvertible, Comparable {
    let towards: StackNode
//    var dummy: [GrammarNode] = []
    init(towards: StackNode) {
        self.towards = towards
    }
    static func == (lhs: Edge, rhs: Edge) -> Bool {
        lhs.towards == rhs.towards
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(towards)
    }
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
    var description: String {
        slot.description + index.description
    }
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
// add descriptors for previous pop actions from v
func call(slot: GrammarNode) {
#if DEBUG
    trace("call", slot)
#endif
    let node = StackNode(slot: slot.seq!, index: currentIndex)
    let actualNode = gss.insert(node).memberAfterInsert
    let edge = Edge(towards: currentStack)
#if DEBUG
    trace("create edge from \(actualNode) to \(currentStack)")
#endif

    // TODO: change edges from array to set
//    assert(!actualNode.edges.contains(where: { $0.towards === currentStack }), "Afroozeh was wrong, edge \(edge) was already in node \(actualNode) \(actualNode.edges)")
    
    actualNode.edges.append(edge)
    for pop in actualNode.pops {
#if DEBUG
        trace("contingent Descriptor")
#endif
        addDescriptor(slot: slot.seq!, stack: currentStack, index: pop)
    }

    // TODO: iterate over all ALT nodes in parseMessage
    var current = slot
    while let next = current.alt, let seq = next.seq {
        addDescriptor(slot: seq, stack: actualNode, index: currentIndex)
        current = next
    }
}

// TODO: the first edge can be popped without addDescriptor
func ret() {
#if DEBUG
    trace("ret", currentStack)
#endif
    if currentIndex == tokens.count - 1 && currentStack == gssRoot {
        successfullParses += 1
#if DEBUG
        trace("HURRAH token = \(token)", terminator: "\n")
#endif
    } else {
        currentStack.pops.insert(currentIndex)
        for edge in currentStack.edges {
#if DEBUG
            trace("pop \(edge)")
#endif
            addDescriptor(slot: currentStack.slot, stack: edge.towards, index: currentIndex)
        }
    }
}

func addDescriptor(slot: GrammarNode, stack: StackNode, index: Int) {
    if stack.unique.insert(SlotIndex(slot: slot, index: index)).inserted {
        remainder.append(Descriptor(slot: slot, stack: stack, index: index))
        descriptorCount += 1
#if DEBUG
        trace("add Descriptor(slot \(slot), stack \(stack), index \(index))")
#endif
    } else {
#if DEBUG
        trace("duplicate Descriptor(slot \(slot), stack \(stack), index \(index))")
#endif
    }
}

func getDescriptor() -> Bool {
    if remainder.isEmpty {
        return false
    } else {
        let d = remainder.removeLast()
        currentSlot = d.slot
        currentStack = d.stack
        currentIndex = d.index
#if DEBUG
        trace("get Descriptor(slot \(currentSlot), stack \(currentStack), index \(currentIndex))")
#endif
        return true
    }
}
