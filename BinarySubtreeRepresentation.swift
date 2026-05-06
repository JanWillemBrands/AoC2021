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
    let i: TokenPosition  // left extent
    let k: TokenPosition  // pivot
    let j: TokenPosition  // right extent
    var description: String { "\(slot.ebnfDot()) \(i):\(k):\(j)" }
}

struct BinarySpan: Hashable, Comparable, CustomStringConvertible {
    let i: TokenPosition  // left extent
    let k: TokenPosition  // pivot
    let j: TokenPosition  // right extent
    var description: String { "\(i):\(k):\(j)" }

    static func < (lhs: BinarySpan, rhs: BinarySpan) -> Bool {
        (lhs.i, lhs.k, lhs.j) < (rhs.i, rhs.k, rhs.j)
    }
}

// MARK: - MessageParser BSR Operations

extension MessageParser {

    // Paper: bsrAdd(X ::= α·β, i, k, j) — add BSR element to the yield
    func addYield(L: GrammarNode, i: TokenPosition, k: TokenPosition, j: TokenPosition) {
        let triple = BinarySpan(i: i, k: k, j: j)
        if L.yield.insert(triple).inserted {
            yieldCount += 1
        }
    }
}
