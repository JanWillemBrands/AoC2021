//
//  BinarySubtreeRepresentation.swift
//  Advent
//
//  Created by Johannes Brands on 27/04/2025.
//

// Paper: Υ (Upsilon) = BSR set — the set of all BSR elements
// Paper: bsrAdd(X ::= α·β, i, k, j) — add BSR element

import Foundation

struct BSR: Hashable, CustomStringConvertible {
    let node: GrammarNode
    let i: Int  // left extent
    let k: Int  // pivot
    let j: Int  // right extent
    var description: String { "\(node.ebnfDot()) \(i):\(k):\(j)" }
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
var bsrSet: Set<BSR> = []

// Paper: bsrAdd(X ::= α·β, i, k, j)
@discardableResult
func bsrAdd(L: GrammarNode, i: Int, k: Int, j: Int) -> Bool {
    print("bsrAdd: \(L.ebnfDot()) \(i):\(k):\(j)")
    let triple = BinarySpan(i: i, k: k, j: j)
    L.yield.insert(triple)
    
    // TODO: remove global bsrSet
    let bsr = BSR(node: L, i: i, k: k, j: j)
    return bsrSet.insert(bsr).inserted
}
