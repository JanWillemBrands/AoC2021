//// StackNode: The core GSS node, now containing all metadata
//final class StackNode: Hashable, CustomStringConvertible, Comparable {
//    let slot: GrammarNode
//    let index: Int
//    var edges: Set<Edge> = []
//    var pops: Set<Int> = []
//    var unique: Set<SlotIndex> = []
//
//    init(slot: GrammarNode, index: Int) {
//        self.slot = slot
//        self.index = index
//    }
//
//    static func ==(lhs: StackNode, rhs: StackNode) -> Bool {
//        lhs.slot == rhs.slot && lhs.index == rhs.index
//    }
//
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(slot)
//        hasher.combine(index)
//    }
//
//    var description: String {
//        slot.description + index.description
//    }
//
//    static func <(lhs: StackNode, rhs: StackNode) -> Bool {
//        lhs.description < rhs.description
//    }
//}
//
//// Edge: Represents a connection between StackNodes
//struct Edge: Hashable, CustomStringConvertible, Comparable {
//    let towards: StackNode
//
//    init(towards: StackNode) {
//        self.towards = towards
//    }
//
//    static func ==(lhs: Edge, rhs: Edge) -> Bool {
//        lhs.towards == rhs.towards
//    }
//
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(towards)
//    }
//
//    var description: String {
//        towards.description
//    }
//
//    static func <(lhs: Edge, rhs: Edge) -> Bool {
//        lhs.towards < rhs.towards
//    }
//}
//
//// Descriptor: Represents a parsing task
//struct Descriptor: Hashable {
//    let slot: GrammarNode
//    let stack: StackNode
//    let index: Int
//}
//
//// SlotIndex: Used for tracking unique descriptors
//struct SlotIndex: Hashable, CustomStringConvertible {
//    let slot: GrammarNode
//    let index: Int
//
//    var description: String {
//        slot.description + index.description
//    }
//}
//
//// BSR: Binary Subtree Representation for parse results
//struct BSR: Hashable, CustomStringConvertible {
//    let node: GrammarNode
//    let i: Int
//    let k: Int
//    let j: Int
//    var description: String { "\(node) \(i):\(k):\(j)" }
//}
//
//// Assume GrammarNode is defined elsewhere with necessary properties
//// For completeness, a minimal version:
//struct GrammarNode: Hashable, CustomStringConvertible {
//    enum Kind { case EOS, other } // Simplified
//    let kind: Kind
//    let str: String
//    var seq: GrammarNode? // Optional next sequential node
//    var alt: GrammarNode? // Optional alternative node
//
//    var description: String { str }
//}
//
//// Global state (assuming these exist in your broader context)
//var gss: Set<StackNode> = []
//var gssRoot = StackNode(slot: GrammarNode(kind: .EOS, str: "$"), index: 0)
//var remainder: [Descriptor] = []
//var yield: Set<BSR> = []
//var currentStack: StackNode! // Must be set before use (e.g., gssRoot initially)
//var currentSlot: GrammarNode! // Updated by getDescriptor()
//var index: Int = 0 // Current token index
//var tokens: [String] = [] // Assume token array exists
//var token: String { tokens[index] } // Current token
//var descriptorCount = 0
//var successfullParses = 0 // Typo in original ("successfull"), should be "successful"
//
//// Placeholder for trace function (replace with your logging)
//func trace(_ items: Any..., terminator: String = "") {
//    print(items.map { "\($0)" }.joined(separator: " "), terminator: terminator)
//}
//
//// GLL Parsing Functions
//func call(slot: GrammarNode) {
//    trace("call", slot)
//    let v = StackNode(slot: slot.seq!, index: index)
//    let (_, actualV) = gss.insert(v) // Use the set’s instance (existing or new)
//    
//    let e = Edge(towards: currentStack)
//    if actualV.edges.insert(e).inserted {
//        trace("create edge from \(actualV) to \(e.towards)")
//    }
//    
//    // to test Afroozeh's assertion
//    assert(edges.contains(e) == false, "edge \(e) was already in node \(v) \(gss[v]?.edges ?? [])")
//
//    for p in actualV.pops {
//        trace("contingent Descriptor(slot \(slot.seq!), stack \(currentStack), index \(p))")
//        addDescriptor(slot: slot.seq!, stack: currentStack, index: p)
//    }
//
//    var current = slot
//    while let next = current.alt, let seq = next.seq {
//        addDescriptor(slot: seq, stack: actualV, index: index)
//        current = next
//    }
//}
//
//func ret() {
//    trace("ret", currentStack)
//    if index == tokens.count - 1 && currentStack === gssRoot {
//        successfullParses += 1
//        trace("HURRAH token = \(token)", terminator: "\n")
//    } else {
//        currentStack.pops.insert(index)
//        for edge in currentStack.edges {
//            trace("pop \(edge)")
//            addDescriptor(slot: currentStack.slot, stack: edge.towards, index: index)
//        }
//    }
//}
//
//func addDescriptor(slot: GrammarNode, stack: StackNode, index: Int) {
//    if stack.unique.insert(SlotIndex(slot: slot, index: index)).inserted {
//        remainder.append(Descriptor(slot: slot, stack: stack, index: index))
//        descriptorCount += 1
//        trace("add Descriptor(slot \(slot), stack \(stack), index \(index))")
//    } else {
//        trace("duplicate Descriptor(slot \(slot), stack \(stack), index \(index))")
//    }
//}
//
//func getDescriptor() -> Bool {
//    if remainder.isEmpty {
//        return false
//    } else {
//        let d = remainder.removeLast()
//        currentSlot = d.slot
//        currentStack = d.stack
//        index = d.index
//        trace("get Descriptor(slot \(currentSlot), stack \(currentStack), index \(index))")
//        return true
//    }
//}
