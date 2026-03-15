//
//  BinarySubtreeRepresentation.swift
//  Advent
//
//  Created by Johannes Brands on 27/04/2025.
//

//import Foundation

public struct BSR: Hashable, CustomStringConvertible {
    let slot: GrammarNode
    let i: Int  // left extent
    let k: Int  // pivot
    let j: Int  // right extent
    public var description: String { "\(slot.ebnfDot()) \(i):\(k):\(j)" }
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

// MARK: - MessageParser BSR Operations

extension MessageParser {
    
    // Paper: bsrAdd(X ::= α·β, i, k, j) — add BSR element to the yield
    func addYield(L: GrammarNode, i: Int, k: Int, j: Int) {
        trace("bsrAdd: \(L.ebnfDot()) \(i):\(k):\(j)")
        // TODO: remove distributed bsrSet ?
        let triple = BinarySpan(i: i, k: k, j: j)
        L.yield.insert(triple)
        
        let bsr = BSR(slot: L, i: i, k: k, j: j)
        yield.insert(bsr)
    }
}
