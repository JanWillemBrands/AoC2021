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

var yields : Set<Yield> = []   // currentYield_Cn_ϒ_𝛶_BSR

@discardableResult
func addYield(node: GrammarNode, i: Int, k: Int, j: Int) -> Bool {
    // bsrAdd(X:== α·β,i,k,j)
    let bsr = Yield(node: node, i: i, k: k, j: j)
    return yields.insert(bsr).inserted
    
    if node.seq?.kind == .END && node.seq?.seq?.kind == .N {
        // if (β=ε) { insert (X:== α,i,j,k) into ϒ }
        let bsr = Yield(node: node.seq!.alt!, i: i, k: k, j: j)
        return yields.insert(bsr).inserted
    } else {
        // TODO: else if (|α|>1) { insert (X:== α,i,j,k) into ϒ }
        let bsr = Yield(node: node, i: i, k: k, j: j)
        return yields.insert(bsr).inserted
    }
    
}
