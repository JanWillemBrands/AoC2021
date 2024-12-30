////
////  GraphStructuredStack.swift
////  Advent
////
////  Created by Johannes Brands on 01/03/2024.
////
//
//final class Vertex {
//    let slot: GrammarNode
//    let index: Int
//    var popped: Set<Int> = []
//    var unique: Set<SlotIndex> = []
//
//    init(slot: GrammarNode, index: Int) {
//        self.slot = slot
//        self.index = index
//    }
//}
//
//final class Edge {
//    let towards: Vertex
////    var yield: Set<Split> = []
//    
//    init(towards: Vertex) {
//        self.towards = towards
//    }
//}
//
//struct Descriptor: Hashable {
//    let slot: GrammarNode
//    let stack: Vertex
//    let index: Int
//}
//
//struct SlotIndex: Hashable {
//    let slot: GrammarNode
//    let index: Int
//}
//
//struct Split: Hashable, CustomStringConvertible {
//    let i: String.Index
//    let k: String.Index
//    let j: String.Index
//    init(_ lowerBound: String.Index, _ pivot: String.Index, _ upperBound: String.Index) {
//        self.i = lowerBound
//        self.k = pivot
//        self.j = upperBound
//    }
//    var description: String { i.inputPosition + ":" + k.inputPosition + ":" + j.inputPosition }
//}
//
//var remainder: [Descriptor] = []
//
//// TODO: OPTIMIZATION cf. Afroozeh change the set of edges to an array of edges
////var graph: [Vertex: [Edge]] = [:]
//var graph: [Vertex: Set<Edge>] = [:]
//
//// global popped
////var unique: Set<Descriptor> = []
////var popped: Set<Poppy> = []
//
//struct Quad: Hashable, CustomStringConvertible {
//    let node: GrammarNode
//    let split: Split
//    var description: String { node.description + "\t" + split.description }
//}
//var currentYield_Cn_ϒ_𝛶_BSR  : Set<Quad> = []
//
//// creates a GSS vertex v, if it doesn't exist already
//// add an edge from v to the current stack top
//// add descriptors for previous pop actions from v
//// set the current stack_Cu to v
//func create(slot: GrammarNode) {
//    let v = Vertex(slot: slot, index: currentIndex)
//    let e = Edge(towards: currentStack)
//    trace("create: edge from \(v) to", currentStack)
//    
//    var edges = graph[v] ?? []
//    edges.insert(e)
//    graph[v] = edges
//    
//    for p in v.popped {
//        trace("create add")
//        addDescriptor(slot: slot, stack: currentStack, index: p)
//    }
//    currentStack = v
//}
//
//// TODO: the first edge can be popped without addDescriptor
//func pop() {
//    trace("pop:", currentStack)
//    currentStack.popped.insert(currentIndex)
//    for edge in graph[currentStack] ?? [] {
//        trace("contingent pop add")
//        addDescriptor(slot: currentStack.slot, stack: edge.towards, index: currentIndex)
//    }
//}
//
//func addDescriptor(slot: GrammarNode, stack: Vertex, index: Int) {
//    if index < tokens.count && stack.unique.insert(SlotIndex(slot: slot, index: index)).inserted {
//        remainder.append(Descriptor(slot: slot, stack: stack, index: index))
//        trace("add Descriptor(slot: \(slot.description), stack: \(stack.description), index: \(index))")
//        addedDescriptors += 1
//    } else {
//        trace("not add Descriptor(slot: \(slot.description), stack: \(stack.description), index: \(index))")
//    }
//}
//
//
//extension Vertex: Hashable, CustomStringConvertible, Comparable {
//    static func == (lhs: Vertex, rhs: Vertex) -> Bool {
//        lhs.slot == rhs.slot && lhs.index == rhs.index
//    }
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(slot)
//        hasher.combine(index)
//    }
//    var description: String {
//        slot.description + index.description
//    }
//    static func < (lhs: Vertex, rhs: Vertex) -> Bool {
//        lhs.description < rhs.description
//    }
//}
//
//extension Edge: Hashable, CustomStringConvertible, Comparable {
//    static func == (lhs: Edge, rhs: Edge) -> Bool {
//        lhs.towards == rhs.towards
//    }
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(towards)
//    }
//    var description: String {
//        towards.description
//    }
//    static func < (lhs: Edge, rhs: Edge) -> Bool {
//        lhs.towards < rhs.towards
//    }
//}
//
