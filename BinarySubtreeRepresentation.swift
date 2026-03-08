//
//  BinarySubtreeRepresentation.swift
//  Advent
//
//  Created by Johannes Brands on 27/04/2025.
//

//import Foundation

struct BSR: Hashable, CustomStringConvertible {
    let slot: GrammarNode
    let i: Int  // left extent
    let k: Int  // pivot
    let j: Int  // right extent
    var description: String { "\(slot.ebnfDot()) \(i):\(k):\(j)" }
}

struct BinarySpan: Hashable, Comparable, CustomStringConvertible {
    let i: Int  // left extent
    let k: Int  // pivot
    let j: Int  // right extent
    var description: String { "\(i):\(k):\(j)" }

    static func < (lhs: BinarySpan, rhs: BinarySpan) -> Bool {
        lhs.i < rhs.i
        || (lhs.i == rhs.i && lhs.k < rhs.k)
        || (lhs.i == rhs.i && lhs.k == rhs.k && lhs.j < rhs.j)
    }
}

// Paper: Υ (Upsilon) — the BSR set
var yield: Set<BSR> = []

// Paper: bsrAdd(X ::= α·β, i, k, j) — add BSR element to the yield
@discardableResult
func bsrAdd(L: GrammarNode, i: Int, k: Int, j: Int) -> Bool {
    print("bsrAdd: \(L.ebnfDot()) \(i):\(k):\(j)")
    let triple = BinarySpan(i: i, k: k, j: j)
    L.yield.insert(triple)
    
    // TODO: remove global bsrSet
    let bsr = BSR(slot: L, i: i, k: k, j: j)
    // TODO: check why this was returning a bool
    return yield.insert(bsr).inserted
}
