//
//  SimpleMessageParser.swift
//  Advent
//
//  Created by Johannes Brands on 2026.04.23.
//

// GLL message parser encapsulating all parsing state.
// Paper: cL = current grammar slot
// Paper: cI — current input position (the current active token)
// Paper: cU — current cluster index (identifies a CRF cluster node together with the nonterminal; its value is the input position where the nonterminal was called)
// Paper: R = pending descriptors, U = processed descriptors
// Paper: dscAdd/dscGet = descriptor operations, ntAdd = nonterminal alternates
// Paper: call = enter nonterminal, rtn = return from nonterminal
// Paper: bsrAdd = add BSR element

import OSLog
import Foundation
//import AdventMacros

class SimpleMessageParser {

    // MARK: - Per-construction (immutable after init)
    let grammar: Grammar

    // MARK: - Per-parse input
    var tokens: [Token] = []
    var trivia: [[Token]] = []
    var input: String = ""

    // MARK: - GLL algorithm state (paper variables)
    var currentParseRoot: GrammarNode!
    var cL: GrammarNode!                    // current grammar slot
    var cI: TokenPosition = .zero           // current input position
    var cU: TokenPosition = .zero           // current cluster index

    // MARK: - Descriptor management (Paper: R, U)
    var remaining: [Descriptor] = []
    var unique: Set<Descriptor> = []

    // MARK: - Parse statistics
    var failedParses = 0
    var successfullParses = 0
    var descriptorCount = 0
    var duplicateDescriptorCount = 0
//    var suppressedDescriptorCount = 0

    // MARK: - Call Return Forest (Paper: CRF)
    var crf: [ParsePosition: ParseCluster] = [:]

    // MARK: - Binary Subtree Representation (Paper: Υ)
    var yieldCount = 0

    // MARK: - Error reporting, captures the furthest the parse has progressed before a mismatch occurred
    var furthestMismatchIndex: TokenPosition = .zero
    var furthestMismatchSlot: GrammarNode!
    var furthestMismatchExpected: Set<String> = []

    // MARK: - Initialization

    init(grammar: Grammar) {
        self.grammar = grammar
    }

    // MARK: - Parse API

    func parse(tokens: [Token], trivia: [[Token]] = [], input: String = "") {
        // Reset all per-parse state
        self.tokens = tokens
        self.trivia = trivia
        self.input = input
        // Map each token's string kind to its integer kindID from the symbol table.
        // This includes Schrödinger duals (linked via token.dual) which represent
        // ambiguous scanner matches of equal length.
        for token in tokens {
            var t: Token? = token
            while let current = t {
                current.kindID = grammar.symbolToID[current.kind]!
                t = current.dual
            }
        }
        currentParseRoot = grammar.root
        cL = nil; cI = .zero; cU = .zero
        unique = []; remaining = []
        failedParses = 0; successfullParses = 0
        descriptorCount = 0; duplicateDescriptorCount = 0//; suppressedDescriptorCount = 0
        crf = [:]; yieldCount = 0
        furthestMismatchIndex = .zero
        furthestMismatchSlot = currentParseRoot
        furthestMismatchExpected = []

        // Set up root cluster
        let rootCluster = ParseCluster(slot: grammar.root, index: .zero)
        crf[ParsePosition(slot: grammar.root, index: .zero)] = rootCluster
        grammar.root.clearNodes()

        // Seed initial descriptors (Paper: ntAdd for start symbol)
        addDecscriptorsForAlternates(X: grammar.root, k: .zero, i: .zero)

        // Run GLL algorithm
        nextDescriptor: while getDescriptor() {

            while true {

                trace = false
                trace("slot: \(String(format: "%2d", cL.number)) \(cL.ebnfDot()) first \(cL.first) follow \(cL.follow) token: \(tokens[cI.tokenIndex].kind) \(tokens[cI.tokenIndex].image)")

                switch cL.kind {
                case .EPS:
                    addYield(L: cL, i: cU, k: cI, j: cI)
                    cL = cL.seq!
                case .B:
                    // Boundary constraints apply between previous and current token.
                    guard cI.tokenIndex > 0 && cI.tokenIndex < tokens.count else {
                        failedParses += 1
                        if cI > furthestMismatchIndex {
                            furthestMismatchIndex = cI
                            furthestMismatchSlot = cL
                            furthestMismatchExpected = [cL.name]
                        } else if cI == furthestMismatchIndex {
                            furthestMismatchExpected.insert(cL.name)
                        }
                        continue nextDescriptor
                    }
                    let left = cI.tokenIndex - 1
                    let right = cI.tokenIndex
                    switch cL.name {
                    case "<s>":     // there must be spacing between previous and current token
                        if !hasInterTokenGap(at: left, and: right) {
                            failedParses += 1
                            if cI > furthestMismatchIndex {
                                furthestMismatchIndex = cI
                                furthestMismatchSlot = cL
                                furthestMismatchExpected = [cL.name]
                            } else if cI == furthestMismatchIndex {
                                furthestMismatchExpected.insert(cL.name)
                            }
                            continue nextDescriptor
                        }
                    case "<n>":     // previous and current token must be on different lines
                        if lineBreakCountBetweenTokens(at: left, and: right) == 0 {
                            failedParses += 1
                            if cI > furthestMismatchIndex {
                                furthestMismatchIndex = cI
                                furthestMismatchSlot = cL
                                furthestMismatchExpected = [cL.name]
                            } else if cI == furthestMismatchIndex {
                                furthestMismatchExpected.insert(cL.name)
                            }
                            continue nextDescriptor
                        }
                    case ">s<":     // previous and current token must be adjacent
                        if hasInterTokenGap(at: left, and: right) {
                            failedParses += 1
                            if cI > furthestMismatchIndex {
                                furthestMismatchIndex = cI
                                furthestMismatchSlot = cL
                                furthestMismatchExpected = [cL.name]
                            } else if cI == furthestMismatchIndex {
                                furthestMismatchExpected.insert(cL.name)
                            }
                            continue nextDescriptor
                        }
                    case ">n<":     // previous and current token must be on the same line
                        if lineBreakCountBetweenTokens(at: left, and: right) > 0 {
                            failedParses += 1
                            if cI > furthestMismatchIndex {
                                furthestMismatchIndex = cI
                                furthestMismatchSlot = cL
                                furthestMismatchExpected = [cL.name]
                            } else if cI == furthestMismatchIndex {
                                furthestMismatchExpected.insert(cL.name)
                            }
                            continue nextDescriptor
                        }
                    default:
                        fatalError("\(#function): unexpected B.name \(cL.name)")
                    }
                    addYield(L: cL, i: cU, k: cI, j: cI)
                    cL = cL.seq!
                case .T, .TI, .C:
                    if let next = tokenMatch() {
                        addYield(L: cL, i: cU, k: cI, j: next)
                        cI = next
                        cL = cL.seq!
                    } else {
                        failedParses += 1
                        if cI > furthestMismatchIndex {
                            furthestMismatchIndex = cI
                            furthestMismatchSlot = cL
                            furthestMismatchExpected = [cL.name]
                        } else if cI == furthestMismatchIndex {
                            furthestMismatchExpected.insert(cL.name)
                        }
                        continue nextDescriptor
                    }
                case .N:
                    call()
                    continue nextDescriptor
                case .ALT:
                    fatalError(#function + ": ALT should not happen here")
                case .DO, .POS:
                    bracketCall(bracket: cL)
                    continue nextDescriptor
                case .OPT, .KLN:
                    // OPT/KLN: also offer skip-past-bracket path (they're nullable)
                    if testSelect(slot: cL.seq!, bracket: cL) {
                        addDescriptor(L: cL.seq!, k: cU, i: cI)
                        addYield(L: cL, i: cU, k: cI, j: cI)  // empty bracket BSR
                    }
                    bracketCall(bracket: cL)
                    continue nextDescriptor
                case .END:
                    // the seq link of an END node always points back to a starting bracket node (N, DO, OPT, POS, KLN)
                    let bracket = cL.seq!

                    switch bracket.kind {
                    case .N:
                        if let seq = bracket.seq {
                            // the bracket is a RHS nonterminal
                            cL = seq
                        } else {
                            // the bracket is a LHS nonterminal
                            if followCheck(bracket: bracket) {
                                addYield(L: bracket, i: cU, k: cU, j: cI)
                                rtn(X: bracket)
                            } else {
                                failedParses += 1
                                if cI > furthestMismatchIndex {
                                    furthestMismatchIndex = cI
                                    furthestMismatchSlot = cL
                                    furthestMismatchExpected = bracket.follow
                                } else if cI == furthestMismatchIndex {
                                    furthestMismatchExpected.formUnion(bracket.follow)
                                }
                            }
                            continue nextDescriptor
                        }
                    case .DO, .OPT, .KLN, .POS:
                        bracketRtn(bracket: bracket)
                        continue nextDescriptor
                   default:
                        fatalError("\(#function) unexpected bracket kind at END seq link \(bracket.kind)")
                    }
                case .EOS:
                    break
                }
            }
        }

        let eosPosition = TokenPosition(token: tokens.count - 1)
        successfullParses = currentParseRoot.yield.filter { y in y.i == .zero && y.j == eosPosition }.count
        trace = false
        print(
            "\nmatched:", successfullParses,
            "  failed:", failedParses,
            "  crf size:", crf.count,
            "  descriptors:", descriptorCount,
            "  duplicateDescriptors:", duplicateDescriptorCount,
//            "  suppressedDescriptors:", suppressedDescriptorCount
        )
        if successfullParses == 0 {
            let mismatchToken = tokens[furthestMismatchIndex.tokenIndex]
            let position = mismatchToken.image.base.linePosition(of: mismatchToken.image.startIndex)
            let expected = furthestMismatchExpected.sorted().joined(separator: ", ")
            print("""
                no parse found at \(position)
                found token image: '\(mismatchToken.image)' kind: '\(mismatchToken.kind)'
                grammar context: \(furthestMismatchSlot.ebnfDot())
                expected: \(expected)
                """)
        }
    }

    // MARK: - Internal helpers

    // TODO:  why is this no longer used?
    func testRepeat() -> Bool {
        let d = Descriptor(L: cL, k: cU, i: cI)
        return !unique.insert(d).inserted
    }

    /// Test whether the current token is in the selection set for a grammar slot.
    /// Returns true if any Schrödinger dual of `tokens[cI]` satisfies:
    ///   token ∈ FIRST(slot)  ∨  (ε ∈ FIRST(slot) ∧ token ∈ FOLLOW(bracket))
    /// Uses BitSet membership (O(1) bit test) instead of Set<String>.contains().
    /// At Frankenstein sub-positions, conservatively returns true (rare path).
    func testSelect(slot: GrammarNode, bracket: GrammarNode) -> Bool {
        
        return true     // Simple

        let headToken = tokens[cI.tokenIndex]
        let headID = headToken.kindID!
        var current = headToken
        while true {
            let cID = current.kindID!
            // Skip this dual if it's excluded by the slot's ---(...) annotation.
            // The head token (primary match) is the keyword/literal; if it's in
            // the exclusion set, this dual path should not be taken.
            if current !== headToken && slot.excludeBS.contains(headID) {
                // This is a dual being tested, and the primary token is excluded
            } else if slot.firstBS.contains(cID)
                || slot.firstBS.contains(grammar.epsilonID) && bracket.followBS.contains(cID) {
                return true
            }
            if let next = current.dual {
                current = next
            } else {
                if slot.firstBS.contains(grammar.frankensteinID)
                    || slot.firstBS.contains(grammar.epsilonID) && bracket.followBS.contains(grammar.frankensteinID) {
                    return true
                }
                return false
            }
        }
    }

    /// Match the current terminal against the token at cI. Returns the next position on success.
    /// Fast path: integer kindID comparison + Schrödinger duals.
    /// Frankenstein path: prefix-match against the token image when cI has a charOffset,
    /// or when the grammar slot allows Frankenstein splitting.
    func tokenMatch() -> TokenPosition? {
        let tokenIdx = cI.tokenIndex
        let charOff  = cI.charOffset

        if charOff != 0 {
            // RARE: Frankenstein sub-position — match against remainder of token image.
            // `cL.content` is the unescaped literal value, stored once by `ApusParser.literal()`.
            // Only `.T` literal terminals can reach this path (since `~~~` is literal-only),
            // so `content` is guaranteed populated here.
            let image = tokens[tokenIdx].stripped
            let remainder = image.dropFirst(charOff)
            let needle = cL.content
            if remainder.hasPrefix(needle) {
                let newOff = charOff + needle.count
                if newOff >= image.count {
                    return cI.nextToken()           // token fully consumed
                }
                return cI.at(charOffset: newOff)    // more remainder
            }
            return nil
        }

        // FAST PATH: exact match + Schrödinger duals
        let headToken = tokens[tokenIdx]
        var current = headToken
        while true {
            // Skip duals excluded by ---(...) annotation on the grammar slot
            if current !== headToken && cL.excludeBS.contains(headToken.kindID) {
                // This dual is suppressed; the primary token is in the exclusion set
            } else if cL.nameID == current.kindID {
                // Positive forward-1-token lookahead — see MessageParser.tokenMatch.
                if !cL.followAheadBS.isEmpty {
                    let nextIdx = tokenIdx + 1
                    var ok = false
                    if nextIdx < tokens.count {
                        var probe: Token? = tokens[nextIdx]
                        while let p = probe {
                            if p.kindID == grammar.eosID || cL.followAheadBS.contains(p.kindID) {
                                ok = true
                                break
                            }
                            probe = p.dual
                        }
                    } else {
                        ok = true
                    }
                    if !ok { return nil }
                }
                return cI.nextToken()
            }
            guard let next = current.dual else { break }
            current = next
        }


        // RARE: Frankenstein prefix split — see comment above for needle derivation.
        if cL.firstBS.contains(grammar.frankensteinID) {
            let image = tokens[tokenIdx].stripped
            let needle = cL.content
            if image.hasPrefix(needle) && image.count > needle.count {
                return cI.at(charOffset: needle.count)
            }
        }
        return nil
    }

    /// Test whether the current token is in the follow set of a bracket (LHS nonterminal).
    /// Handles Schrödinger tokens by checking all duals.
    /// At Frankenstein sub-positions, conservatively returns true (rare path).
    func followCheck(bracket: GrammarNode) -> Bool {
        
        return true     // Simple
        
        var current = tokens[cI.tokenIndex]
        while true {
            if bracket.followBS.contains(current.kindID) { return true }
            guard let next = current.dual else {
                if bracket.followBS.contains(grammar.frankensteinID) { return true }
                return false
            }
            current = next
        }
    }

    /// Test whether a continuation grammar slot can proceed with the token at a given position.
    /// Used to suppress descriptors in rtn/bracketRtn/pop replay when the continuation
    /// cannot match the current token. Conservative: returns true for nullable, END, EPS,
    /// and Frankenstein sub-positions to avoid false rejections.
    func continuationViable(continuation: GrammarNode, at position: TokenPosition) -> Bool {
        
        return true         // Simple
        
        // Structural nodes that don't consume input are always viable
        if continuation.kind == .END || continuation.kind == .EPS { return true }
        // Nullable continuation: can't determine without enclosing FOLLOW context
        if continuation.firstBS.contains(grammar.epsilonID) { return true }
        // Frankenstein sub-position: conservatively viable (rare path)
        if position.charOffset != 0 { return true }
        // Check token (and Schrödinger duals) against FIRST(continuation)
        var current = tokens[position.tokenIndex]
        while true {
            if continuation.firstBS.contains(current.kindID) { return true }
            guard let next = current.dual else {
                return continuation.firstBS.contains(grammar.frankensteinID)
            }
            current = next
        }
    }

    /// Count line breaks from the first token's START index to the second token's START index.
    /// `\r\n` counts as one line break.
    func lineBreakCountBetweenTokens(at first: Int, and second: Int) -> Int {
        let span = input[tokens[first].image.startIndex..<tokens[second].image.startIndex]
        var breaks = 0
        var prevWasCR = false
        for ch in span {
            let isCR = ch == "\r"
            let isLF = ch == "\n"
            if isCR || (isLF && !prevWasCR) { breaks += 1 }
            prevWasCR = isCR
        }
        return breaks
    }

    /// True when there are source characters between the first token END and the second token START.
    /// This backs <s> and >s< so synthetic layout tokens can still observe source spacing.
    func hasInterTokenGap(at first: Int, and second: Int) -> Bool {
        tokens[first].image.endIndex < tokens[second].image.startIndex
    }

}


// MARK: - SimpleMessageParser CRF Operations

extension SimpleMessageParser {

    // Paper: ntAdd(X, j) — add descriptors for all alternates of a bracket/nonterminal
    func addDecscriptorsForAlternates(X: GrammarNode, k: TokenPosition, i: TokenPosition) {
        assert([.N, .DO, .OPT, .ALT, .KLN, .POS].contains(X.kind), "Called \(#function) on a GrammarNode \(X) which is not a bracket")
        // For LL(1) nonterminals without Schrödinger duals or Frankenstein tokens,
        // at most one alternate can match — stop after finding it.
        
        let canEarlyTerminate = false       // Simple
        
//        let canEarlyTerminate = X.isLocallyLL1
//            && tokens[i.tokenIndex].dual == nil
//            && i.charOffset == 0
//            && !X.firstBS.contains(grammar.frankensteinID)
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
//                    if continuationViable(continuation: cL.seq!, at: pop) {
                        addDescriptor(L: cL.seq!, k: cU, i: pop)
                        addYield(L: cL, i: cU, k: cI, j: pop)
//                    } else {
//                        suppressedDescriptorCount += 1
//                    }
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
//                if continuationViable(continuation: rtn.slot.seq!, at: cI) {
                    addDescriptor(L: rtn.slot.seq!, k: rtn.index, i: cI)
                    addYield(L: rtn.slot, i: rtn.index, k: cU, j: cI)
//                } else {
//                    suppressedDescriptorCount += 1
//                }
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
//                    if continuationViable(continuation: bracket.seq!, at: pop) {
                        addDescriptor(L: bracket.seq!, k: cU, i: pop)
                        addYield(L: bracket, i: cU, k: cI, j: pop)
//                    } else {
//                        suppressedDescriptorCount += 1
//                    }
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
//                if continuationViable(continuation: rtn.slot.seq!, at: cI) {
                    addYield(L: rtn.slot, i: rtn.index, k: cU, j: cI)
                    addDescriptor(L: rtn.slot.seq!, k: rtn.index, i: cI)
//                } else {
//                    suppressedDescriptorCount += 1
//                }
            }

            if bracket.kind.isClosure {
                let nextKey = ParsePosition(slot: bracket, index: cI)

                if let existingCluster = crf[nextKey] {
                    for returnEdge in cluster.returns {
                        if existingCluster.returns.insert(returnEdge).inserted {
                            for pop in existingCluster.pops {
//                                if continuationViable(continuation: returnEdge.slot.seq!, at: pop) {
                                    addYield(L: returnEdge.slot, i: returnEdge.index, k: cI, j: pop)
                                    addDescriptor(L: returnEdge.slot.seq!, k: returnEdge.index, i: pop)
//                                } else {
//                                    suppressedDescriptorCount += 1
//                                }
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


// MARK: - SimpleMessageParser Descriptor Operations

extension SimpleMessageParser {

    // Paper: dscAdd(L, k, i)
    func addDescriptor(L: GrammarNode, k: TokenPosition, i: TokenPosition) {
        let d = Descriptor(L: L, k: k, i: i)
        if unique.insert(d).inserted {
            remaining.append(d)
            descriptorCount += 1
        } else {
            duplicateDescriptorCount += 1
        }
    }

    // Paper: get next descriptor from R
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
}


// MARK: - MessageParser BSR Operations

extension SimpleMessageParser {

    // Paper: bsrAdd(X ::= α·β, i, k, j) — add BSR element to the yield
    func addYield(L: GrammarNode, i: TokenPosition, k: TokenPosition, j: TokenPosition) {
        let triple = BinarySpan(i: i, k: k, j: j)
        if L.yield.insert(triple).inserted {
            yieldCount += 1
        }
    }
}
