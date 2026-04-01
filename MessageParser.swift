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
    var cL: GrammarNode!          // current grammar slot
    var cI: Int = 0               // current input position
    var cU: Int = 0               // current cluster index

    // MARK: - Descriptor management (Paper: R, U)
    var remaining: [Descriptor] = []
    var unique: Set<Descriptor> = []

    // MARK: - Parse statistics
    var failedParses = 0
    var successfullParses = 0
    var descriptorCount = 0
    var duplicateDescriptorCount = 0

    // MARK: - Call Return Forest (Paper: CRF)
    var crf: [Position: Cluster] = [:]

    // MARK: - Binary Subtree Representation (Paper: Υ)
    var yield: Set<BSR> = []

    // MARK: - Error reporting, captures the furthest the parse has progressed before a mismatch occurred
    var furthestMismatchIndex: Int = 0
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
        cL = nil; cI = 0; cU = 0
        unique = []; remaining = []
        failedParses = 0; successfullParses = 0
        descriptorCount = 0; duplicateDescriptorCount = 0
        crf = [:]; yield = []
        furthestMismatchIndex = 0
        furthestMismatchSlot = currentParseRoot
        furthestMismatchExpected = []

        // Set up root cluster
        let rootCluster = Cluster(slot: grammar.root, index: 0)
        crf[Position(slot: grammar.root, index: 0)] = rootCluster
        grammar.root.clearNodes()

        // Seed initial descriptors (Paper: ntAdd for start symbol)
        addDecscriptorsForAlternates(X: grammar.root, k: 0, i: 0)

        // Run GLL algorithm
        nextDescriptor: while getDescriptor() {

            while true {

                trace = false
                #Trace("slot: \(String(format: "%2d", cL.number)) \(cL.ebnfDot()) first \(cL.first) follow \(cL.follow) token: \(tokens[cI].kind) \(tokens[cI].image)")
                trace = true

                switch cL.kind {
                case .EPS:
                    addYield(L: cL, i: cU, k: cI, j: cI)
                    cL = cL.seq!
                case .T, .TI, .C, .B:
                    if tokenMatch() {
                        addYield(L: cL, i: cU, k: cI, j: cI + 1)
                        cI += 1
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

        successfullParses = currentParseRoot.yield.filter { y in y.i == 0 && y.j == tokens.count-1 }.count
        trace = true
        print(
            "\nmatched:", successfullParses,
            "  failed:", failedParses,
            "  crf size:", crf.count,
            "  descriptors:", descriptorCount,
            "  duplicateDescriptors:", duplicateDescriptorCount
        )
        if successfullParses == 0 {
            let mismatchToken = tokens[furthestMismatchIndex]
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
        let d = Descriptor(L: cL, k: Int32(cU), i: Int32(cI))
        return !unique.insert(d).inserted
    }

    /// Test whether the current token is in the selection set for a grammar slot.
    /// Returns true if any Schrödinger dual of `tokens[cI]` satisfies:
    ///   token ∈ FIRST(slot)  ∨  (ε ∈ FIRST(slot) ∧ token ∈ FOLLOW(bracket))
    /// Uses BitSet membership (O(1) bit test) instead of Set<String>.contains().
    func testSelect(slot: GrammarNode, bracket: GrammarNode) -> Bool {
        var current = tokens[cI]
        repeat { // to handle Schrödinger tokens
            let kid: Int = current.kindID
            if slot.firstBS.contains(kid)
                || slot.firstBS.contains(grammar.epsilonID) && bracket.followBS.contains(kid) {
                return true
            }
            guard let next = current.dual else { return false }
            current = next
        } while true
    }

    /// Test whether the current token matches the terminal at the current grammar slot.
    /// Uses integer comparison (O(1)) instead of string equality.
    func tokenMatch() -> Bool {
        var current = tokens[cI]
        repeat {  // to handle Schrödinger tokens
            if cL.nameID == current.kindID { return true }
            guard let next = current.dual else { return false }
            current = next
        } while true
    }

    /// Test whether the current token is in the follow set of a bracket (LHS nonterminal).
    /// Handles Schrödinger tokens by checking all duals.
    func followCheck(bracket: GrammarNode) -> Bool {
        var current = tokens[cI]
        repeat {  // to handle Schrödinger tokens
            if bracket.followBS.contains(current.kindID) { return true }
            guard let next = current.dual else { return false }
            current = next
        } while true
    }
}
