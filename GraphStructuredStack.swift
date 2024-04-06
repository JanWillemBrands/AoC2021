//
//  GraphStructuredStack.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

final class Vertex: Hashable, CustomStringConvertible, Comparable {
    var slot: GrammarNode
    var index: Int
//    var index: String.Index
//
//    init(slot: GrammarNode, index: String.Index) {
//        self.slot = slot
//        self.index = index
//    }
    
    init(slot: GrammarNode, index: Int) {
        self.slot = slot
        self.index = index
    }
    
    var popped: Set<String.Index> = []
    var unique: Set<SlotIndexPair> = []

    static func == (lhs: Vertex, rhs: Vertex) -> Bool {
        lhs.slot == rhs.slot && lhs.index == rhs.index
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(slot)
        hasher.combine(index)
    }
    var description: String {
        slot.description + index.inputPosition
    }
    static func < (lhs: Vertex, rhs: Vertex) -> Bool {
        lhs.description < rhs.description
    }
}

final class Edge: Hashable, CustomStringConvertible, Comparable {
    var towards: Vertex
    init(towards: Vertex) {
        self.towards = towards
    }
    var yield: Set<BiRange> = []

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
    var slot: GrammarNode
    var stack: Vertex
    var index: String.Index
    var yield: Set<BiRange> = []
}

struct SlotIndexPair: Hashable {
    var slot: GrammarNode
    var index: String.Index
}

// global popped
//struct Poppy: Hashable {
//    var stack: Vertex
//    var index: String.Index
//}

struct BiRange: Hashable, CustomStringConvertible {
    var lowerBound:  String.Index
    var pivot: String.Index
    var upperBound: String.Index
    init(_ lowerBound: String.Index, _ pivot: String.Index, _ upperBound: String.Index) {
        self.lowerBound = lowerBound
        self.pivot = pivot
        self.upperBound = upperBound
    }
    var description: String { lowerBound.inputPosition + ":" + pivot.inputPosition + ":" + upperBound.inputPosition }
}

var remainder: [Descriptor] = []

// TODO: OPTIMIZATION cf. Afroozeh change the set of edges to an array of edges
//var graph: [Vertex: [Edge]] = [:]
    var graph: [Vertex: Set<Edge>] = [:]

// global popped
//var unique: Set<Descriptor> = []
//var popped: Set<Poppy> = []

var currentYield_Cn_ϒ_𝛶  : Set<BiRange> = []

// creates a GSS vertex v, if it doesn't exist already
// add an edge from v to the current stack top
// add descriptors for previous pop actions from v
// set the current stack_Cu to v
func create(slot: GrammarNode) {
    let v = Vertex(slot: slot, index: currentIndex)
    let e = Edge(towards: currentStack)
    trace("create: edge from \(v) to", currentStack)
    
    var edges = graph[v] ?? []
            edges.insert(e)
//    edges.append(e)
    graph[v] = edges
    
    //        assert(edges.sorted() == Set(edges).sorted(), "should have used a Set<Edge> for\n\(edges)")
    
    // global popped
    // for p in popped where p.stack == v {
    //     trace("createadd")
    //     addDescriptor(slot: slot, stack: currentStack, index: p.index)
    // }

    // distributed popped
    for p in v.popped {
        trace("create add")
        addDescriptor(slot: slot, stack: currentStack, index: p)
    }
    currentStack = v
}

// pop the current stack
// OPTIMIZATION dot not create a descriptor for the fist edge that is popped
//    mutating func pop2() {
//        trace("pop:", stack_Cu ?? "nil")
//        if stack_Cu != nil {
//            stack.popped.insert(currentIndex)
////            let p = Poppy(vertex: stack, index: currentIndex)
////            popped.insert(p)
//
//            // one of the edges can be popped without addDescriptor
//            let edges = Array(graph[stack] ?? [])
//            if !edges.isEmpty {
//                stack_Cu = edges.last?.towards
//                slot_L = stack_Cu!.slot
//                next()
//                print("slot",slot_L)
//                for edge in edges.dropLast() {
//                    trace("popadd")
//                    addDescriptor(slot: stack.slot, stack: edge.towards, at: p.index)
//                }
//            }
//        }
//    }

// TODO: the first edge can be popped without addDescriptor
func pop() {
    trace("pop:", currentStack)
    // distributed popped
    currentStack.popped.insert(currentIndex)
    // global popped
    // popped.insert(Poppy(stack: currentStack, index: currentIndex))
    for edge in graph[currentStack] ?? [] {
        trace("contingent pop add")
        addDescriptor(slot: currentStack.slot, stack: edge.towards, index: currentIndex)
    }
}

func addDescriptor(slot: GrammarNode, stack: Vertex, index: String.Index) {
    // distributed unique
    if stack.unique.insert(SlotIndexPair(slot: slot, index: index)).inserted {
    // global unique
    // if unique.insert(Descriptor(slot: slot, stack: stack, index: index)).inserted {
        remainder.append(Descriptor(slot: slot, stack: stack, index: index))
        trace("add Descriptor(slot: \(slot.description), stack: \(stack.description), index: \(index.inputPosition))")
        addedDescriptors += 1
    } else {
        trace("not add Descriptor(slot: \(slot.description), stack: \(stack.description), index: \(index.inputPosition))")
    }
}

//func getDescriptor() -> GrammarNode {
//    let d = remainder.removeLast()
//    trace("get Descriptor(slot: \(d.slot.description), stack: \(d.stack.description), index: \(d.index.inputPosition))")
//    currentStack = d.stack
//    currentIndex(to: d.index)
//    next()
//    return d.slot
//}
//

//extension Descriptor: Hashable {
//    static func == (lhs: Descriptor, rhs: Descriptor) -> Bool {
//        lhs.slot == rhs.slot && lhs.stack == rhs.stack && lhs.index == rhs.index
//    }
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(slot)
//        hasher.combine(stack)
//        hasher.combine(index)
//    }
//}


//apusNoAction before GSS:
//all paths
//tries 22 matches 1
//tries 703 matches 1
//maxPathDepth 14
//maxWalksDepth 97
//pure LL1
//tries 1 matches 1
//tries 1 matches 1
//maxPathDepth 12
//maxWalksDepth 1
//general LL
//tries 1 matches 1
//tries 1 matches 1
//maxPathDepth 12
//maxWalksDepth 1
//Program ended with exit code: 0

// after changes to SSS and AAA
//All paths
//tries 29 matches 1
//tries 939 matches 1
//maxPathDepth 14
//maxWalksDepth 120
//Pure LL1
//tries 1 matches 1
//tries 1 matches 1
//maxPathDepth 12
//maxWalksDepth 1
//General LL
//tries 6 matches 1
//tries 132 matches 1
//maxPathDepth 12
//maxWalksDepth 1
//Program ended with exit code: 0
