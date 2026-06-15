//
//  BinarySubtreeRepresentation.swift
//  Advent
//
//  Created by Johannes Brands on 27/04/2025.
//

//import Foundation
import OSLog
//import AdventMacros

struct BSR: Hashable, CustomStringConvertible {
    let slot: GrammarNode
    let i: CharPosition  // left extent
    let k: CharPosition  // pivot
    let j: CharPosition  // right extent
    var description: String { "\(slot.ebnfDot()) \(i):\(k):\(j)" }
}

struct BinarySpan: Hashable, Comparable, CustomStringConvertible {
    let i: CharPosition  // left extent
    let k: CharPosition  // pivot
    let j: CharPosition  // right extent
    var description: String { "\(i):\(k):\(j)" }

    static func < (lhs: BinarySpan, rhs: BinarySpan) -> Bool {
        if lhs.i != rhs.i { return lhs.i < rhs.i }
        if lhs.k != rhs.k { return lhs.k < rhs.k }
        return lhs.j < rhs.j
    }
}

// MARK: - MessageParser BSR Operations

extension MessageParser {

    // Paper: bsrAdd(X ::= α·β, i, k, j) — add BSR element to the yield
    func addYield(L: GrammarNode, i: CharPosition, k: CharPosition, j: CharPosition) {
        let triple = BinarySpan(i: i, k: k, j: j)
        if yields[L.number].insert(triple).inserted {
            yieldCount += 1
        }
    }
}
