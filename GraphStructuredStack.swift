//
//  GraphStructuredStack.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

struct Vertex: Hashable, CustomStringConvertible, Comparable {
    var slot: GrammarNode
    var index: String.Index
    
    // TODO: optimization cf. Afroozeh
    // var seen_U: Set<Descriptor> = []
    // var done_P: Set<String.Index> = []
    var description: String { slot.description + index.description }
    static func < (lhs: Vertex, rhs: Vertex) -> Bool { lhs.description < rhs.description }
}

struct Edge: Hashable,CustomStringConvertible {
    var to: Vertex?
    var weight: Int = 0
    var description: String { to?.description ?? "·" }
}

struct Descriptor: Hashable {
    var slot: GrammarNode
    var stack: Vertex?
    var index: String.Index
    var weight = Extents()
    
    static func == (lhs: Descriptor, rhs: Descriptor) -> Bool {
        lhs.slot == rhs.slot && lhs.stack == rhs.stack && lhs.index == rhs.index
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(slot)
        hasher.combine(stack)
        hasher.combine(index)
    }
}

struct Poppy: Hashable {
    var popped: Vertex
    var at: String.Index
}

struct GraphStructuredStack {
    var graph: [Vertex: Set<Edge>] = [:]
    var stack_Cu: Vertex?

    var todo_R: [Descriptor] = []
    var seen_U: Set<Descriptor> = []
    
    var pops_P: Set<Poppy> = []
    
    var extents_Cn = Extents()
    
    // creates a GSS vertex v, if it doesn't exist already
    // add an edge from v to the current stack top
    // add descriptors for previous pop actions from v
    // set the current stack_Cu to v
    mutating func create(slot: GrammarNode) {
        let v = Vertex(slot: slot, index: index_Ci)
        let e = Edge(to: stack_Cu)
        trace("create: edge from \(v) to", stack_Cu ?? "nil")

        var edges = graph[v] ?? []
        edges.insert(e)
        graph[v] = edges
        
        // TODO: optimization store seen_P in GSS Vertex
        // for p in v.done_P {
        //     add(slot: slot, stack: stack_Cu, at: p)
        // }
        for p in pops_P where p.popped == v {
            trace("createadd")
            addDescriptor(slot: slot, stack: stack_Cu, at: p.at)
        }
        stack_Cu = v
    }

    // pop the current stack
    mutating func pop() {
        trace("pop:", stack_Cu ?? "nil")
        if let stack_Cu {
            let p = Poppy(popped: stack_Cu, at: index_Ci)
            pops_P.insert(p)
            
            for edge in graph[stack_Cu] ?? [] {
                trace("popadd")
                addDescriptor(slot: stack_Cu.slot, stack: edge.to)
            }
        }
    }

    mutating func addDescriptor(slot: GrammarNode, stack: Vertex?, at position: String.Index = index_Ci) {
        let d = Descriptor(slot: slot, stack: stack, index: position)

        if seen_U.insert(d).inserted {
            todo_R.append(d)
            trace("add Descriptor(slot: \(d.slot.description), stack: \(d.stack?.description ?? "nil"), index: \(d.index))")
        } else {
            trace("not add Descriptor(slot: \(d.slot.description), stack: \(d.stack?.description ?? "nil"), index: \(d.index))")
        }
        // TODO: optimization store seen_U in GSS Vertex
    }

    mutating func getDescriptor() -> GrammarNode? {
        if todo_R.isEmpty {
            return nil
        } else {
            let d = todo_R.removeLast()
            trace("get Descriptor(slot: \(d.slot.description), stack: \(d.stack?.description ?? "nil"), index: \(d.index))")
            stack_Cu = d.stack
            setScanPosition(to: d.index)
            next()
            return d.slot
        }
    }

}

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
