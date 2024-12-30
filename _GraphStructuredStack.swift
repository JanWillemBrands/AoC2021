//
//  _GraphStructuredStack.swift
//  Advent
//
//  Created by Johannes Brands on 26/12/2024.
//

final class _Vertex {
    let slot: _GrammarNode
    let index: Int
    var popped: Set<Int> = []
    var unique: Set<_SlotIndex> = []

    init(slot: _GrammarNode, index: Int) {
        self.slot = slot
        self.index = index
    }
}

final class _Edge {
    let towards: _Vertex
//    var yield: Set<Split> = []
    
    init(towards: _Vertex) {
        self.towards = towards
    }
}

struct _Descriptor: Hashable {
    let slot: _GrammarNode
    let stack: _Vertex
    let index: Int
}

struct _SlotIndex: Hashable {
    let slot: _GrammarNode
    let index: Int
}

struct _Split: Hashable, CustomStringConvertible {
    let i: String.Index
    let k: String.Index
    let j: String.Index
    init(_ lowerBound: String.Index, _ pivot: String.Index, _ upperBound: String.Index) {
        self.i = lowerBound
        self.k = pivot
        self.j = upperBound
    }
    var description: String { i.inputPosition + ":" + k.inputPosition + ":" + j.inputPosition }
}

var _remainder: [_Descriptor] = []

// TODO: OPTIMIZATION cf. Afroozeh change the set of edges to an array of edges
//var graph: [Vertex: [Edge]] = [:]
var _graph: [_Vertex: Set<_Edge>] = [:]

// global popped
//var unique: Set<Descriptor> = []
//var popped: Set<Poppy> = []

struct _Quad: Hashable, CustomStringConvertible {
    let node: _GrammarNode
    let split: _Split
    var description: String { node.description + "\t" + split.description }
}
var _currentYield_Cn_ϒ_𝛶_BSR  : Set<_Quad> = []

// creates a GSS vertex v, if it doesn't exist already
// add an edge from v to the current stack top
// add descriptors for previous pop actions from v
// set the current stack_Cu to v
func _create(slot: _GrammarNode) {
    let v = _Vertex(slot: slot, index: currentIndex)
    let e = _Edge(towards: _currentStack)
    trace("create: edge from \(v) to", _currentStack)
    
    var edges = _graph[v] ?? []
    edges.insert(e)
    _graph[v] = edges
    
    for p in v.popped {
        trace("create add")
        _addDescriptor(slot: slot, stack: _currentStack, index: p)
    }
    _currentStack = v
}

// TODO: the first edge can be popped without addDescriptor
func _pop() {
    trace("pop:", _currentStack)
    _currentStack.popped.insert(currentIndex)
    for edge in _graph[_currentStack] ?? [] {
        trace("contingent pop add")
        _addDescriptor(slot: _currentStack.slot, stack: edge.towards, index: currentIndex)
    }
}

func _addDescriptor(slot: _GrammarNode, stack: _Vertex, index: Int) {
    if index < tokens.count && stack.unique.insert(_SlotIndex(slot: slot, index: index)).inserted {
        _remainder.append(_Descriptor(slot: slot, stack: stack, index: index))
        trace("add Descriptor(slot: \(slot.description), stack: \(stack.description), index: \(index))")
        _addedDescriptors += 1
    } else {
        trace("not add Descriptor(slot: \(slot.description), stack: \(stack.description), index: \(index))")
    }
}


extension _Vertex: Hashable, CustomStringConvertible, Comparable {
    static func == (lhs: _Vertex, rhs: _Vertex) -> Bool {
        lhs.slot == rhs.slot && lhs.index == rhs.index
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(slot)
        hasher.combine(index)
    }
    var description: String {
        slot.description + index.description
    }
    static func < (lhs: _Vertex, rhs: _Vertex) -> Bool {
        lhs.description < rhs.description
    }
}

extension _Edge: Hashable, CustomStringConvertible, Comparable {
    static func == (lhs: _Edge, rhs: _Edge) -> Bool {
        lhs.towards == rhs.towards
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(towards)
    }
    var description: String {
        towards.description
    }
    static func < (lhs: _Edge, rhs: _Edge) -> Bool {
        lhs.towards < rhs.towards
    }
}

