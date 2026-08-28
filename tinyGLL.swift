//
//  tinyGLL.swift
//  Advent
//
//  Created by Johannes Brands on 2026.08.28.
//

let grammar = "S = a."

let input = "a"

func parseGrammar() -> GrammarNode {
    return false
}

func parseInput() -> Set<BinarySpan> {
    return false
}

enum GrammarNodeKind { case EOS, T, EPS, N, ALT, END }

final class GrammarNode {
    static var count = 0
    
    let number = 0
    let kind: GrammarNodeKind
    let name: Character

    var alt, seq: GrammarNode?
    
    init(_ kind: GrammarNodeKind, _ name: Character) {
        self.kind = kind
        self.name = name
        self.number = Self.count
        Self.count += 1
    }
}

struct Descriptor: Hashable {
    let L: GrammarNode          // grammar slot
    let k: String.Index         // cluster index
    let i: String.Index         // input index
}

let unique: Set<Descriptor> = []
var remaining: [Descriptor] = []

var cL: GrammarNode
var cU: String.Index
var cI: String.Index

func addDescriptor(L: GrammarNode, k: String.Index, i: String.Index) {
    let d = Descriptor(L: L, k: k, i: i)
    if unique.insert(d).inserted {
        remaining.append(d)
    }
}

func getDescriptor() -> Bool {
    if remaining.isEmpty {
        return false
    } else {
        let d = remaining.removeLast()
        cL = d.L
        cU = d.k
        cI = d.i
        return true
    }
}

var yields: [Set<BinarySpan>] = []

struct BinarySpan: Hashable, Comparable, CustomStringConvertible {
    let i: String.Index  // left extent
    let k: String.Index  // pivot
    let j: String.Index  // right extent
    var description: String { "\(i):\(k):\(j)" }
    
    static func < (lhs: BinarySpan, rhs: BinarySpan) -> Bool {
        if lhs.i != rhs.i { return lhs.i < rhs.i }
        if lhs.k != rhs.k { return lhs.k < rhs.k }
        return lhs.j < rhs.j
    }
}

func addYield(L: GrammarNode, i: String.Index, k: String.Index, j: CharPosition) {
    let triple = BinarySpan(i: i, k: k, j: j)
    yields[L.number].insert(triple)
}

let AST = parseGrammar()
let yield = parseInput()
print(yield)
