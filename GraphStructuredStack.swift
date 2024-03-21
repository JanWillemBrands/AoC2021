//
//  GraphStructuredStack.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

struct Vertex {
    var slot: GrammarNode
    var index: String.Index
    
    var popped: Set<String.Index> = []
    // TODO: optimization cf. Afroozeh
    var unique: Set<miniDescriptor> = []
}

struct Edge {
    var towards: Vertex?
    var weight: Int = 0
}

struct Descriptor {
    var slot: GrammarNode
    var stack: Vertex?
    var index: String.Index
    var weight = Extents()
}

struct miniDescriptor: Hashable {
    var slot: GrammarNode
    var index: String.Index
}

var remainder: [Descriptor] = []

struct GraphStructuredStack {
    // TODO: OPTIMIZATION cf. Afroozeh change the set of edged to an array of edges
    var graph: [Vertex: [Edge]] = [:]
//    var graph: [Vertex: Set<Edge>] = [:]
    
    var currentStack: Vertex?
    
//    var unique: Set<Descriptor> = []
        
    var extents_Cn = Extents()
    
    // creates a GSS vertex v, if it doesn't exist already
    // add an edge from v to the current stack top
    // add descriptors for previous pop actions from v
    // set the current stack_Cu to v
    mutating func create(slot: GrammarNode) {
        let v = Vertex(slot: slot, index: currentIndex)
        let e = Edge(towards: currentStack)
        trace("create: edge from \(v) to", currentStack ?? "nil")
        
        var edges = graph[v] ?? []
//        edges.insert(e)
        edges.append(e)
        graph[v] = edges
        
//        assert(edges.sorted() == Set(edges).sorted(), "should have used a Set<Edge> for\n\(edges)")
        
        for p in v.popped {
            trace("createadd")
            addDescriptor(slot: slot, stack: &currentStack, at: p)
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
    
    mutating func pop() {
        trace("pop:", currentStack ?? "nil")
        if currentStack != nil {
            currentStack!.popped.insert(currentIndex)
            // TODO: the first edge can be popped without addDescriptor
            for var edge in graph[currentStack!] ?? [] {
                trace("contingent pop add")
                addDescriptor(slot: currentStack!.slot, stack: &edge.towards)
            }
        }
    }
    
//    mutating func addDescriptorOld(slot: GrammarNode, stack: Vertex?, at index: String.Index = currentIndex) {
//        let d = Descriptor(slot: slot, stack: stack, index: index)
//        if unique.insert(d).inserted {
//            remainder.append(d)
//            trace("add Descriptor(slot: \(d.slot.description), stack: \(d.stack?.description ?? "nil"), index: \(d.index))")
//            addedDescriptors += 1
//        } else {
//            trace("not add Descriptor(slot: \(d.slot.description), stack: \(d.stack?.description ?? "nil"), index: \(d.index))")
//        }
//    }
    
    mutating func addDescriptor(slot: GrammarNode, stack: inout Vertex?, at index: String.Index = currentIndex) {
        let md = miniDescriptor(slot: slot, index: index)
        
        if let b = stack?.unique.insert(md).inserted {
            let d = Descriptor(slot: md.slot, stack: stack, index: md.index)
            remainder.append(d)
            trace("add Descriptor(slot: \(slot.description), stack: \(stack?.description ?? "nil"), index: \(index))")
            addedDescriptors += 1
        } else {
            trace("not add Descriptor(slot: \(slot.description), stack: \(stack?.description ?? "nil"), index: \(index))")
        }
    }
    
    mutating func getDescriptor() -> GrammarNode? {
        if remainder.isEmpty {
            return nil
        } else {
            let d = remainder.removeLast()
            trace("get Descriptor(slot: \(d.slot.description), stack: \(d.stack?.description ?? "nil"), index: \(d.index))")
            currentStack = d.stack
            currentIndex(to: d.index)
            next()
            return d.slot
        }
    }
    
}

extension Vertex: Hashable, CustomStringConvertible, Comparable {
    static func == (lhs: Vertex, rhs: Vertex) -> Bool {
        lhs.slot == rhs.slot && lhs.index == rhs.index
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(slot)
        hasher.combine(index)
    }
    var description: String { slot.description + index.description }
    static func < (lhs: Vertex, rhs: Vertex) -> Bool { lhs.description < rhs.description }
}

extension Edge: Hashable, CustomStringConvertible, Comparable {
    var description: String { towards?.description ?? "·" }
    static func < (lhs: Edge, rhs: Edge) -> Bool {
        if lhs.towards == nil && rhs.towards == nil {
            return false
        } else if lhs.towards == nil && rhs.towards != nil {
            return true
        } else if lhs.towards != nil && rhs.towards == nil {
            return false
        } else {
            return lhs.towards! < rhs.towards!
        }
    }
}

extension Descriptor: Hashable {
    static func == (lhs: Descriptor, rhs: Descriptor) -> Bool {
        lhs.slot == rhs.slot && lhs.stack == rhs.stack && lhs.index == rhs.index
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(slot)
        hasher.combine(stack)
        hasher.combine(index)
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
