//
//  MessageParser.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.15.
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
import AdventMacros

class MessageParser {

    // MARK: - Per-construction (immutable after init)
    let grammar: Grammar

    // MARK: - Per-parse input
    var tokens: [Token] = []

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

    // MARK: - Call Return Forest (Paper: CRF)
    var crf: [ParsePosition: ParseCluster] = [:]

    // MARK: - Binary Subtree Representation (Paper: Υ)
    var yield: Set<BSR> = []

    // MARK: - Error reporting, captures the furthest the parse has progressed before a mismatch occurred
    var furthestMismatchIndex: TokenPosition = .zero
    var furthestMismatchSlot: GrammarNode!
    var furthestMismatchExpected: Set<String> = []

    // MARK: - Initialization

    init(grammar: Grammar) {
        self.grammar = grammar
    }

    // MARK: - Parse API

    func parse(tokens: [Token]) {
        // Reset all per-parse state
        self.tokens = tokens
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
        descriptorCount = 0; duplicateDescriptorCount = 0
        crf = [:]; yield = []
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
                #Trace("slot: \(String(format: "%2d", cL.number)) \(cL.ebnfDot()) first \(cL.first) follow \(cL.follow) token: \(tokens[cI.tokenIndex].kind) \(tokens[cI.tokenIndex].image)")
                trace = true

                switch cL.kind {
                case .EPS:
                    addYield(L: cL, i: cU, k: cI, j: cI)
                    cL = cL.seq!
                case .T, .TI, .C, .B:
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
                    #Trace("ERROR: Unexpected .ALT node in cL")
                    #Trace("  cL.number: \(cL.number)")
                    #Trace("  cL.name: '\(cL.name)'")
                    #Trace("  cL.seq: \(String(describing: cL.seq))")
                    #Trace("  cL.alt: \(String(describing: cL.alt))")
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
                        fatalError("unexpected bracket kind at END seq link \(bracket.kind)")
                    }
                case .EOS:
                    break
                }
            }
        }

        let eosPosition = TokenPosition(token: tokens.count - 1)
        successfullParses = currentParseRoot.yield.filter { y in y.i == .zero && y.j == eosPosition }.count
        trace = true
        print(
            "\nmatched:", successfullParses,
            "  failed:", failedParses,
            "  crf size:", crf.count,
            "  descriptors:", descriptorCount,
            "  duplicateDescriptors:", duplicateDescriptorCount
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
        
        
//        return true     //  TODO:  REMOVE THIS HACK !!!
        

        if slot.frankensteinMatchAllowed { return true }
        print("testSelect \(slot.ebnfDot()) not frankenstein allowed")
        var current = tokens[cI.tokenIndex]
        repeat { // to handle Schrödinger tokens
            let cID = current.kindID!
            if slot.firstBS.contains(cID)
                || slot.firstBS.contains(grammar.epsilonID) && bracket.followBS.contains(cID) {
                return true
            }
            guard let next = current.dual else { return false }
            current = next
        } while true
    }

    /// Match the current terminal against the token at cI. Returns the next position on success.
    /// Fast path: integer kindID comparison + Schrödinger duals.
    /// Frankenstein path: prefix-match against the token image when cI has a charOffset,
    /// or when the grammar slot allows Frankenstein splitting.
    func tokenMatch() -> TokenPosition? {
        let tokenIdx = cI.tokenIndex
        let charOff  = cI.charOffset
//        Logger.parse.debug("tokenMatch cI \(self.cI) \(self.cL.name)")

        if charOff != 0 {
            // RARE: Frankenstein sub-position — match against remainder of token image
            let image = tokens[tokenIdx].stripped
            let remainder = image.dropFirst(charOff)
            Logger.parse.debug("frankenstein remainder \(remainder) index \(self.cI) image \(image)")
            if remainder.hasPrefix(cL.name) {
                let newOff = charOff + cL.name.count
                if newOff >= image.count {
                    return cI.nextToken()           // token fully consumed
                }
                return cI.at(charOffset: newOff)    // more remainder
            }
            return nil
        }

        // FAST PATH: exact match + Schrödinger duals
        var current = tokens[tokenIdx]
        while true {
            if cL.nameID == current.kindID {
                return cI.nextToken()
            }
            guard let next = current.dual else { break }
            current = next
        }

        
        // RARE: Frankenstein prefix split
        if cL.frankensteinMatchAllowed {
            let image = tokens[tokenIdx].stripped
            Logger.parse.debug("frankenstein allowed \(self.cL.name) at \(self.cL.ebnfDot()) prefix matching image \(image)")
            if image.hasPrefix(cL.name) && image.count > cL.name.count {
                return cI.at(charOffset: cL.name.count)
            }
        }
        return nil
    }

    /// Test whether the current token is in the follow set of a bracket (LHS nonterminal).
    /// Handles Schrödinger tokens by checking all duals.
    /// At Frankenstein sub-positions, conservatively returns true (rare path).
    func followCheck(bracket: GrammarNode) -> Bool {
        
//        return true         // TODO:  REMOVE THIS HACK ?!@!!
        
        if bracket.frankensteinMatchAllowed { return true }
        print("followCheck \(bracket.ebnfDot()) not frankenstein allowed")
        var current = tokens[cI.tokenIndex]
        repeat {  // to handle Schrödinger tokens
            if bracket.followBS.contains(current.kindID) { return true }
            guard let next = current.dual else { return false }
            current = next
        } while true
    }

}
