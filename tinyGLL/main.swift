//
//  main.swift
//  tinyGLL
//
//  Created by Johannes Brands on 2026.08.28.
//

import Foundation

// tinyGLL parses 'input' according to 'syntax' in a CNP - Clustered Nonterminal Parsing style.
//
// Naming, as in the papers. The same letter means different things in a descriptor
// and in a yield, so the two conventions are spelled out once here:
//   L        a grammar slot (a position in a production)
//   X        a nonterminal (its LHS definition node)
//   in a descriptor (L, k, i):     k = cluster index,  i = input index
//   in a BinarySpan (i, k, j):     i = left extent,    k = pivot,  j = right extent
// So a descriptor's 'k' becomes a span's 'i', which is why addYield is called
// as addYield(L: cL, i: cU, k: cI, ...) — the swap is deliberate, not a typo.
let input = Array("aa")

// Start symbol 'S'. Empty production 'ε'.
// Terminals/nonterminals are single lowercase/uppercase letters.
// Space and newline are skipped.
let syntax = Array(" S = aS | ε .")

// 'GrammarNode' builds a binary tree with its 'seq' and 'alt' links.
// terminal, nonTerminal and epsilon nodes are stored as T, N, EPS.
// The ALT and END nodes signal the start and end of a sequence.
enum GrammarNodeKind { case T, EPS, N, ALT, END }

class GrammarNode {
    let kind: GrammarNodeKind
    let name: Character
    
    var alt, seq: GrammarNode?
    
    let number: Int
    static var count = 0
    
    init(_ kind: GrammarNodeKind, _ name: Character) {
        self.kind = kind
        self.name = name
        self.number = Self.count
        Self.count += 1
    }
}

// stores LHS nonTerminal definition grammar trees by name.
var nonTerminalDefinitions: [Character: GrammarNode] = [:]

// Recursive descent parser to transform the 'syntax' string into a 'grammarNode' tree.
func parseGrammar() {
    var i = 0
    var c: Character = "$"
    
    // invariant: 'c' is the current unconsumed character, 'i' is the index after 'c'.
    func next(expect predicate: (Character) -> Bool = { _ in true } ) {
        if !predicate(c) {
            print("found an unexpected '\(c)' at position \(i - 1)")
            exit(1)
        }
        while i < syntax.count && ( syntax[i] == " " || syntax[i] == "\n" ) {
            i += 1
        }
        if i < syntax.count {
            c = syntax[i]
            i += 1
        } else {
            c = "$"
        }
        print("next '\(c)' at position \(i - 1)")
    }
    
    var nonTerminal: GrammarNode!                   // the current LHS production being parsed
    var nonTerminalReferences: [GrammarNode] = []   // RHS nonTerminal (forward/backward) references
    
    func production() {
        print(#function)
        let name = c
        next() { $0.isUppercase }
        nonTerminal = GrammarNode(.N, name)
        nonTerminalDefinitions[nonTerminal.name] = nonTerminal
        next() { $0 == "=" }
        nonTerminal.alt = alternates()
        next() { $0 == "." }
    }
    
    func alternates() -> GrammarNode {
        print(#function)
        let startOfAlternates = sequence()
        var tmp = startOfAlternates
        while c == "|" {
            next()
            let nextAlternate = sequence()
            tmp.alt = nextAlternate
            tmp = nextAlternate
        }
        return startOfAlternates
    }
    
    func sequence() -> GrammarNode {
        print(#function)
        let startOfSequence = GrammarNode(.ALT, "[")
        var tmp = startOfSequence
        repeat {
            let factor: GrammarNode
            if c == "ε" {
                factor = GrammarNode(.EPS, c)
            } else if c.isUppercase {
                factor = GrammarNode(.N, c)
                nonTerminalReferences.append(factor)
            } else if c.isLowercase {
                factor = GrammarNode(.T, c)
            } else {
                print("found an unexpected factor '\(c)' at position \(i - 1)")
                exit(1)
            }
            tmp.seq = factor
            tmp = factor
            next()
        } while c.isLetter

        let end = GrammarNode(.END, "]")
        tmp.seq = end
        end.seq = nonTerminal
        end.alt = startOfSequence
        return startOfSequence
    }
    
    next()
    while c != "$" {
        production()
    }
    
    // resolve RHS references
    for ref in nonTerminalReferences {
        ref.alt = nonTerminalDefinitions[ref.name]
    }
}

// Paper: descriptor = (L, k, i) — grammar slot, cluster index, input index
struct Descriptor: Hashable {
    let L: GrammarNode          // grammar slot
    let k: Int                  // cluster index: where the containing nonterminal was entered
    let i: Int                  // input index: how far this attempt has got
}

var unique: Set<Descriptor> = []
var remaining: [Descriptor] = []

// The three parse registers, all set by getDescriptor().
var cL: GrammarNode!            // current grammar slot (seeded by the first getDescriptor())
var cU = 0                      // current cluster index: input position where the nonterminal was entered
var cI = 0                      // current input index

func addDescriptor(L: GrammarNode, k: Int, i: Int) {
    let d = Descriptor(L: L, k: k, i: i)
    if unique.insert(d).inserted {
        remaining.append(d)
    }
}

// Paper: ntAdd(X, j) — add descriptors for all alternates of a nonterminal.
// The paper's single position 'j' is split here into 'k' and 'i'. Both call sites in
// tinyGLL pass them equal, since a nonterminal's cluster starts where it is entered,
// but the split is not redundant: EBNF closure re-entry (KLN/POS) needs to add
// descriptors at the position reached so far (i) while staying attached to the cluster
// the closure started in (k). See Advent's bracketRtn.
func addDescriptorsForAlternates(X: GrammarNode, k: Int, i: Int) {
    var alt = X.alt
    while let node = alt {
        addDescriptor(L: node.seq!, k: k, i: i)
        alt = node.alt
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

// The (ambiguous) parse tree is stored in a BSR - Binary Subtree Representation, not in an SPPF.
struct BinarySpan: Hashable {
    // Written (i:k:j) = (left:pivot:right), the paper's BSR triple:
    //   (i:k:k)   an epsilon yield          — nothing consumed at the pivot
    //   (i:k:k+1) a terminal yield          — one character consumed
    //   (i:k:j)   a prefix + postfix yield  — prefix [i,k), postfix [k,j)
    //   (i:i:j)   a nonterminal yield       — pivot at the left extent, no split
    let left:  Int
    let pivot: Int
    let right: Int
}

// Individual 'GrammarNode' yields are retrievable by GrammarNode.number index.
var yields: [Set<BinarySpan>] = []

// Paper: bsrAdd(X ::= α·β, i, k, j) — i/k/j are the left extent, pivot and right extent.
func addYield(L: GrammarNode, i: Int, k: Int, j: Int) {
    let bs = BinarySpan(left: i, pivot: k, right: j)
    yields[L.number].insert(bs)
}


// Paper: CRF - Call Return Forest
var crf: [ParsePosition: ParseCluster] = [:]

// Paper: crfNode (L, i) — a grammar slot paired with an input position.
// Used in two roles, and 'index' means something different in each:
//   as a cluster key   (slot: the LHS nonterminal, index: cI) — where the cluster starts
//   as a return edge   (slot: the RHS nonterminal, index: cU) — where the caller started
struct ParsePosition: Hashable {
    let slot: GrammarNode
    let index: Int
}

// Paper: clusterNode (X, k). The (X, k) label is the crf dictionary key, so it is not
// repeated here — what a cluster adds over its identity is these two sets.
final class ParseCluster {
    var returns: Set<ParsePosition> = []
    var pops: Set<Int> = []         // Paper: P — contingent returns
}


// Paper: call(L, i, j) — enter a nonterminal.
// The paper's L is the slot *after* the nonterminal (the slot to return to). Here the
// RHS nonterminal node itself is stored, and the return slot is derived as .seq! on
// the way back out (see rtn), so one link later than the paper's L.
func call() {
    // Create the return edge: (L=cL, i=cU), cL is the RHS nonterminal node
    let returnEdge = ParsePosition(slot: cL, index: cU)

    // Create the cluster key: (X=cL.alt!, k=cI), cL.alt! is the LHS nonterminal node
    let clusterKey = ParsePosition(slot: cL.alt!, index: cI)
    
    // Find or create the parseCluster in the crf
    if let existingCluster = crf[clusterKey] {
        if existingCluster.returns.insert(returnEdge).inserted {
            for pop in existingCluster.pops {
                addDescriptor(L: cL.seq!, k: cU, i: pop)
                addYield(L: cL, i: cU, k: cI, j: pop)
            }
        }
    } else {
        let newCluster = ParseCluster()
        crf[clusterKey] = newCluster
        newCluster.returns.insert(returnEdge)
        addDescriptorsForAlternates(X: cL.alt!, k: cI, i: cI)
    }
}

// Paper: rtn(X, k, j) — return from a nonterminal.
// Only X is passed; the paper's k and j are read from the registers cU and cI.
func rtn(X: GrammarNode) {
    let clusterKey = ParsePosition(slot: X, index: cU)
    guard let cluster = crf[clusterKey] else { return }
    
    if cluster.pops.insert(cI).inserted {
        for edge in cluster.returns {
            addDescriptor(L: edge.slot.seq!, k: edge.index, i: cI)
            addYield(L: edge.slot, i: edge.index, k: cU, j: cI)
        }
    }
}

func parseInput() {
    // Seed initial parse cluster and descriptors
    guard let grammarRoot = nonTerminalDefinitions["S"] else {
        fatalError("Missing start symbol 'S'")
    }
    crf[ParsePosition(slot: grammarRoot, index: 0)] = ParseCluster()
    addDescriptorsForAlternates(X: grammarRoot, k: 0, i: 0)
    
    // make the yields storage large enough
    yields = Array(repeating: [], count: GrammarNode.count)
    
    nextDescriptor: while getDescriptor() {
        while true {
            switch cL.kind {
            case .T:
                // Past the end of input there is nothing to match
                if cI < input.count && input[cI] == cL.name {
                    addYield(L: cL, i: cU, k: cI, j: cI+1)
                    cI += 1
                    cL = cL.seq!
                } else {
                    continue nextDescriptor
                }
            case .N:
                call()
                continue nextDescriptor
            case .EPS:
                addYield(L: cL, i: cU, k: cI, j: cI)
                cL = cL.seq!
            case .ALT:
                fatalError(#function + ": ALT should not happen here")
            case .END:
                let nt = cL.seq! // the seq link of an END node points back to the nonTerminal node
                // pivot == left extent: the nonterminal's own span, unsplit
                addYield(L: nt, i: cU, k: cU, j: cI)
                rtn(X: nt)
                continue nextDescriptor
            }
        }
    }
}

parseGrammar()

for definition in nonTerminalDefinitions.values {
    definition.dump()
}

parseInput()

// The parse is accepted when the start symbol yields a span covering the whole input
if let root = nonTerminalDefinitions["S"],
   yields[root.number].contains(where: { $0.left == 0 && $0.right == input.count }) {
    print("Parse pass")
    print(yields[root.number])
} else {
    print("Parse fail")
}
