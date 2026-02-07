//
//  BinarySubtreeRepresentation.swift
//  Advent
//
//  Created by Johannes Brands on 27/04/2025.
//

import Foundation

struct Yield: Hashable, CustomStringConvertible {
    let node: GrammarNode
    let i: Int  // left
    let k: Int  // pivot
    let j: Int  // right
    var description: String { "\(node.ebnfDot()) \(i):\(k):\(j)" }
}

struct BinarySpan: Hashable, Comparable, CustomStringConvertible {
    let i: Int  // left
    let k: Int  // pivot
    let j: Int  // right
    var description: String { "\(i):\(k):\(j)" }

    static func < (lhs: BinarySpan, rhs: BinarySpan) -> Bool {
//        if lhs.i < rhs.i { return true }
//        if lhs.i > rhs.i { return false }
//        if lhs.k < rhs.k { return true }
//        if lhs.k > rhs.k { return false }
//        return lhs.j < rhs.j
        lhs.i < rhs.i
        || (lhs.i == rhs.i && lhs.k < rhs.k)
        || (lhs.i == rhs.i && lhs.k == rhs.k && lhs.j < rhs.j)
    }
}



var yields : Set<Yield> = []   // currentYield_Cn_ϒ_𝛶_BSR

@discardableResult
func addYield(slot: GrammarNode, i: Int, k: Int, j: Int) -> Bool {
    print("addYield: \(slot.ebnfDot()) \(i):\(k):\(j)")
    // bsrAdd(X:== α·β,i,k,j)
    let triple = BinarySpan(i: i, k: k, j: j)
    slot.yield.insert(triple)
    
    // TODO: remove global yields
    let bsr = Yield(node: slot, i: i, k: k, j: j)
    return yields.insert(bsr).inserted
    
//    if slot.seq?.kind == .END && slot.seq?.seq?.kind == .N {
//        // if (β=ε) { insert (X:== α,i,j,k) into ϒ }
//        let bsr = Yield(node: slot.seq!.alt!, i: i, k: k, j: j)
//        return yields.insert(bsr).inserted
//    } else {
//        // TODO: else if (|α|>1) { insert (X:== α,i,j,k) into ϒ }
//        let bsr = Yield(node: slot, i: i, k: k, j: j)
//        return yields.insert(bsr).inserted
//    }
    
}
