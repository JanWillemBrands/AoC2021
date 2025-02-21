//
//  _GraphStructuredStack.swift
//  Advent
//
//  Created by Johannes Brands on 26/12/2024.
//

final class StackNode {
    let slot: GrammarNode
    let index: Int
    var pops: Set<Int> = []
    var unique: Set<SlotIndex> = []

    init(slot: GrammarNode, index: Int) {
        self.slot = slot
        self.index = index
    }
}

struct _StackNode: Hashable {
    let slot: GrammarNode
    let index: Int
}

// the graph-structured-stack consists of nodes and edges.
// besides a list of edges, each node contains a list of descriptors and a list of pops.
var _gss: [_StackNode:(edges: Set<Edge>, unique: Set<_StackNode>, pops: Set<Int>)] = [:]

struct Edge {
    let towards: StackNode
//    var yield: Set<Split> = []
    
    init(towards: StackNode) {
        self.towards = towards
    }
}

struct Descriptor: Hashable {
    let slot: GrammarNode
    let stack: StackNode
    let index: Int
}

struct SlotIndex: Hashable {
    let slot: GrammarNode
    let index: Int
}

// the list of Decriptors that still need to be processed
var remainder: [Descriptor] = []

// TODO: OPTIMIZATION cf. Afroozeh change the set of edges to an array of edges
//var gss: [Vertex: [Edge]] = [:]
var gss: [StackNode: Set<Edge>] = [:]
var gssRoot = StackNode(slot: GrammarNode(kind: .EOS, str: "$"), index: 0)

struct BSR: Hashable, CustomStringConvertible {
    let node: GrammarNode
    let i: Int
    let k: Int
    let j: Int
    var description: String { "\(node) \(i):\(k):\(j)" }
}

var yield : Set<BSR> = []   // currentYield_Cn_ϒ_𝛶_BSR

// create a GSS vertex v, if it doesn't exist already
// add an edge from v to the current stack top
// add descriptors for previous pop actions from v
func __call(slot: GrammarNode) {
    trace("call", slot)
    var v = StackNode(slot: slot.seq!, index: index)
    if gss[v] != nil {
        // the vertex already exists, but pops and unique are not part of the hash, so we need to find the original
        v = gss.keys.first(where: { $0 == v }) ?? v
    }
    let e = Edge(towards: currentStack)
    trace("create edge from \(v) to \(e.towards)")
    
    // insert the new edge and add
    var edges = gss[v] ?? []
    if edges.insert(e).inserted {
        gss[v] = edges
        for p in v.pops {
            trace("contingent descriptor")
            addDescriptor(slot: slot.seq!, stack: currentStack, index: p)
        }
    }

    // iterate over all ALT nodes
    var current = slot
    while let next = current.alt, let seq = next.seq {
        addDescriptor(slot: seq, stack: v, index: index)
        current = next
    }
}


func call(slot: GrammarNode) {
    trace("call", slot)
    var v = StackNode(slot: slot.seq!, index: index)
    var edges = gss[v] ?? []
    if !edges.isEmpty {
        // the vertex already exists, but pops and unique are not part of the hash, so we need to find the original
        if let originalKey = gss.keys.first(where: { $0 == v }) {
            v = originalKey
        }
    }
    let e = Edge(towards: currentStack)
    trace("create edge from \(v) to \(e.towards)")
    
    // to test Afroozeh's assertion
    assert(edges.contains(e) == false, "edge \(e) was already in node \(v) \(gss[v] ?? [])")
    // insert the new edge and add
    if edges.insert(e).inserted {
        gss[v] = edges
        for p in v.pops {
            trace("contingent Descriptor(slot \(slot.seq!), stack \(currentStack), index \(p))")
            addDescriptor(slot: slot.seq!, stack: currentStack, index: p)
        }
    }

    // iterate over all ALT nodes
    var current = slot
    while let next = current.alt, let seq = next.seq {
        addDescriptor(slot: seq, stack: v, index: index)
        current = next
    }
}

// TODO: the first edge can be popped without addDescriptor
func ret() {
    trace("ret", currentStack)
    if index == tokens.count - 1 && currentStack == gssRoot {
        successfullParses += 1
        trace("HURRAH token = \(token)", terminator: "\n")
    } else {
        currentStack.pops.insert(index)
        for edge in gss[currentStack] ?? [] {
            trace("pop \(edge)")
            addDescriptor(slot: currentStack.slot, stack: edge.towards, index: index)
        }
    }
}

func addDescriptor(slot: GrammarNode, stack: StackNode, index: Int) {
    if stack.unique.insert(SlotIndex(slot: slot, index: index)).inserted {
        remainder.append(Descriptor(slot: slot, stack: stack, index: index))
        descriptorCount += 1
        trace("add Descriptor(slot \(slot), stack \(stack), index \(index))")
    } else {
        trace("duplicate Descriptor(slot \(slot), stack \(stack), index \(index))")
    }
}

func getDescriptor() -> Bool {
    if remainder.isEmpty {
        return false
    } else {
        let d = remainder.removeLast()
        currentSlot = d.slot
        currentStack = d.stack
        index = d.index
        trace("get Descriptor(slot \(currentSlot), stack \(currentStack), index \(index))")
        return true
    }
}


extension StackNode: Hashable, CustomStringConvertible, Comparable {
    static func == (lhs: StackNode, rhs: StackNode) -> Bool {
        lhs.slot == rhs.slot && lhs.index == rhs.index
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(slot)
        hasher.combine(index)
    }
    var description: String {
        slot.description + index.description
    }
    static func < (lhs: StackNode, rhs: StackNode) -> Bool {
        lhs.description < rhs.description
    }
}

extension Edge: Hashable, CustomStringConvertible, Comparable {
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

extension SlotIndex: CustomStringConvertible {
    var description: String {
        slot.description + index.description
    }
}
