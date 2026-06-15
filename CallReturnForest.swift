//
//  CallReturnForest.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

// "Derivation representation using binary subtree sets"
// https://pure.royalholloway.ac.uk/ws/portalfiles/portal/33174042/Accepted_Manuscript.pdf

// Paper: CRF = Call Return Forest
// Paper: P = contingent return set (pops)
// Paper: cL = current grammar slot, cI = current input index, cU = current cluster index

import OSLog
import Foundation


// Lightweight value type for CRF dictionary keys and return edges.
// Matches the paper's crfNode (L, i).
struct ParsePosition: Hashable, Comparable, CustomStringConvertible {
    let slot: GrammarNode
    let index: CharPosition

    var description: String { "\(slot).\(index)" }
    var ebnfDot: String { "\(slot.ebnfDot()),\(index)" }

    static func < (lhs: ParsePosition, rhs: ParsePosition) -> Bool {
        lhs.description < rhs.description
    }
}

// Cluster node in the CRF. Mutable, identity-based.
// Represents clusterNode (X, k) from the paper.
final class ParseCluster: CustomStringConvertible {
    let slot: GrammarNode           // the LHS nonterminal (X)
    let index: CharPosition         // input position (k)

    var returns: Set<ParsePosition> = []
    var pops: Set<CharPosition> = []   // Paper: P — contingent returns

    init(slot: GrammarNode, index: CharPosition) {
        self.slot = slot
        self.index = index
    }

    var description: String { "\(slot).\(index)" }
    var ebnfDot: String { "\(slot.ebnfDot()),\(index)" }
}


// MARK: - MessageParser CRF Operations

extension MessageParser {

    // Paper: ntAdd(X, j) — add descriptors for all alternates of a bracket/nonterminal
    func addDecscriptorsForAlternates(X: GrammarNode, k: CharPosition, i: CharPosition) {
        assert([.N, .DO, .OPT, .ALT, .KLN, .POS].contains(X.kind), "Called \(#function) on a GrammarNode \(X) which is not a bracket")
        // LL(1) early-termination: once a matching alternate is found, the
        // remaining alternates cannot also match. This is a property of the
        // grammar, derived statically by `verifyLL1` + the multi-lex
        // prefix-overlap check in `handleAlternatesAmbiguity`. The parser
        // doesn't consult the lexer's disambiguation strategy at all here —
        // multi-lex independence.
        // TODO: re-enable for multi-lex. Temporarily forced off while the
        // LCNP migration proceeds — `X.isLocallyLL1` (and its supporting
        // prefix-overlap diagnostic) is preserved so we can switch this back
        // on once the parser-driven lex path is in place.
        let canEarlyTerminate = false && X.isLocallyLL1
        var current = X.alt
        while let alt = current {
            if testSelect(slot: alt, bracket: X) {
                addDescriptor(L: alt.seq!, k: k, i: i)
                if canEarlyTerminate { return }
            }
            current = alt.alt
        }
    }

    // Paper: call(L, i, j) — enter a nonterminal
    func call() {
        // cL points to the RHS nonterminal node
        // cL.alt points to the LHS nonterminal node

        // Create the return edge: (L=cL, i=cU)
        let returnEdge = ParsePosition(slot: cL, index: cU)

        // Find or create the cluster node for (X=cL.alt!, k=cI)
        let clusterKey = ParsePosition(slot: cL.alt!, index: cI)

        if let existingCluster = crf[clusterKey] {
            if existingCluster.returns.insert(returnEdge).inserted {
                for pop in existingCluster.pops {
                    if continuationViable(continuation: cL.seq!, at: pop) {
                        addDescriptor(L: cL.seq!, k: cU, i: pop)
                        addYield(L: cL, i: cU, k: cI, j: pop)
                    } else {
                        suppressedDescriptorCount += 1
                    }
                }
            }
        } else {
            let newCluster = ParseCluster(slot: cL.alt!, index: cI)
            crf[clusterKey] = newCluster
            newCluster.returns.insert(returnEdge)
            addDecscriptorsForAlternates(X: cL.alt!, k: cI, i: cI)
        }
    }

    // Paper: rtn(X, k, j) — return from a nonterminal
    func rtn(X: GrammarNode) {
        let clusterKey = ParsePosition(slot: X, index: cU)
        guard let cluster = crf[clusterKey] else { return }

        if cluster.pops.insert(cI).inserted {
            for rtn in cluster.returns {
                if continuationViable(continuation: rtn.slot.seq!, at: cI) {
                    addDescriptor(L: rtn.slot.seq!, k: rtn.index, i: cI)
                    addYield(L: rtn.slot, i: rtn.index, k: cU, j: cI)
                } else {
                    suppressedDescriptorCount += 1
                }
            }
        }
    }

    // bracketCall — enter a bracket (DO, OPT, KLN, POS)
    // Similar to call() but the bracket node IS the "nonterminal" — no indirection through .alt
    func bracketCall(bracket: GrammarNode) {
        let returnEdge = ParsePosition(slot: bracket, index: cU)
        let clusterKey = ParsePosition(slot: bracket, index: cI)

        if let existingCluster = crf[clusterKey] {
            if existingCluster.returns.insert(returnEdge).inserted {
                for pop in existingCluster.pops {
                    if continuationViable(continuation: bracket.seq!, at: pop) {
                        addDescriptor(L: bracket.seq!, k: cU, i: pop)
                        addYield(L: bracket, i: cU, k: cI, j: pop)
                    } else {
                        suppressedDescriptorCount += 1
                    }
                }
            }
        } else {
            let newCluster = ParseCluster(slot: bracket, index: cI)
            crf[clusterKey] = newCluster
            newCluster.returns.insert(returnEdge)
            addDecscriptorsForAlternates(X: bracket, k: cI, i: cI)
        }
    }

    // bracketRtn — return from a bracket
    // Similar to rtn() but also handles KLN/POS re-entry
    func bracketRtn(bracket: GrammarNode) {
        let clusterKey = ParsePosition(slot: bracket, index: cU)
        guard let cluster = crf[clusterKey] else { return }

        if cluster.pops.insert(cI).inserted {
            for rtn in cluster.returns {
                if continuationViable(continuation: rtn.slot.seq!, at: cI) {
                    addYield(L: rtn.slot, i: rtn.index, k: cU, j: cI)
                    addDescriptor(L: rtn.slot.seq!, k: rtn.index, i: cI)
                } else {
                    suppressedDescriptorCount += 1
                }
            }

            if bracket.kind.isClosure {
                let nextKey = ParsePosition(slot: bracket, index: cI)

                if let existingCluster = crf[nextKey] {
                    for returnEdge in cluster.returns {
                        if existingCluster.returns.insert(returnEdge).inserted {
                            for pop in existingCluster.pops {
                                if continuationViable(continuation: returnEdge.slot.seq!, at: pop) {
                                    addYield(L: returnEdge.slot, i: returnEdge.index, k: cI, j: pop)
                                    addDescriptor(L: returnEdge.slot.seq!, k: returnEdge.index, i: pop)
                                } else {
                                    suppressedDescriptorCount += 1
                                }
                            }
                        }
                    }
                } else {
                    let newCluster = ParseCluster(slot: bracket, index: cI)
                    crf[nextKey] = newCluster
                    newCluster.returns = cluster.returns
                    addDecscriptorsForAlternates(X: bracket, k: cI, i: cI)
                }
            }
        }
    }
}
