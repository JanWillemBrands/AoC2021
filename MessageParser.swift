//
//  MessageParser.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.15.
//

// GLL message parser encapsulating all parsing state.
// Paper: cL = current grammar slot
// Paper: cI — current input position (the current active token)
// Paper: cU — current cluster index (the input position where the last nonTerminal was called)
// Paper: R = pending descriptors, U = processed descriptors
// Paper: dscAdd/dscGet = descriptor operations, ntAdd = nonterminal alternates
// Paper: call = enter nonterminal, rtn = return from nonterminal
// Paper: bsrAdd = add BSR element

import Foundation

class MessageParser {

    // MARK: - Per-construction (immutable after init)
    let grammar: Grammar

    // MARK: - Per-parse input
    private(set) var tokens: [Token] = []

    // MARK: - GLL algorithm state (paper variables)
    private(set) var currentParseRoot: GrammarNode!
    var cL: GrammarNode!          // current grammar slot
    var cI: Int = 0               // current input position
    var cU: Int = 0               // current cluster index

    // MARK: - Descriptor management (Paper: R, U)
    var unique: Set<Descriptor> = []
    var remaining: [Descriptor] = []

    // MARK: - Parse statistics
    var failedParses = 0
    var successfullParses = 0
    var descriptorCount = 0
    var duplicateDescriptorCount = 0

    // MARK: - Call Return Forest (Paper: CRF)
    var crf: [Position: Cluster] = [:]

    // MARK: - Binary Subtree Representation (Paper: Υ)
    var yield: Set<BSR> = []

    // MARK: - Error reporting
    var furthestMismatch: (Token, Set<String>)!

    // MARK: - SPPF extraction state
    var slotIndex: [GrammarNode: Int] = [:]
    var sppfNodes: [SPPFNodeKey: SPPFNode] = [:]
    var sppfAllNodes: [SPPFNode] = []
    var _sppfNonTerminals: [String: GrammarNode] = [:]
    var syntheticEpsilonNode: GrammarNode?

    // MARK: - Initialization

    init(grammar: Grammar) {
        self.grammar = grammar
    }

    // MARK: - Parse API

    func parse(tokens: [Token]) {
        // Reset all per-parse state
        self.tokens = tokens
        currentParseRoot = grammar.root
        cL = nil; cI = 0; cU = 0
        unique = []; remaining = []
        failedParses = 0; successfullParses = 0
        descriptorCount = 0; duplicateDescriptorCount = 0
        crf = [:]; yield = []
        furthestMismatch = (tokens[0], [])
        slotIndex = [:]; sppfNodes = [:]; sppfAllNodes = []
        _sppfNonTerminals = [:]; syntheticEpsilonNode = nil

        // Set up root cluster
        let rootCluster = Cluster(slot: grammar.root, index: 0)
        crf[Position(slot: grammar.root, index: 0)] = rootCluster
        grammar.root.clearNodes()

        // Seed initial descriptors (Paper: ntAdd for start symbol)
        addDecscriptorsForAlternates(X: grammar.root, k: 0, i: 0)

        // Run GLL algorithm
        nextDescriptor: while getDescriptor() {

            while true {

                trace = true
                #if DEBUG
                trace("slot: \(String(format: "%2d", cL.number)) \(cL.ebnfDot()) first \(cL.first) follow \(cL.follow) token: \(tokens[cI].kind) \(tokens[cI].image)")
                #endif
                trace = false

                switch cL.kind {
                case .EPS:
                    addYield(L: cL, i: cU, k: cI, j: cI)
                    cL = cL.seq!
                case .T, .TI, .C, .B:
                    if tokenMatch() {
                        addYield(L: cL, i: cU, k: cI, j: cI + 1)
                        cI += 1
                        #if DEBUG
                        trace = true
                        trace("next", tokens[cI].image, tokens[cI].kind)
                        trace = false
                        #endif
                        cL = cL.seq!
                    } else {
                        failedParses += 1
                        if tokens[cI].image.startIndex > furthestMismatch.0.image.endIndex {
                            furthestMismatch = (tokens[cI], [cL.str])
                        }
                        #if DEBUG
                        trace("NOGOOD Parse ended due to unexpected token", terminator: "\n")
                        #endif
                        continue nextDescriptor
                    }
                case .N:
                    call()
                    continue nextDescriptor
                case .ALT:
                    print("ERROR: Unexpected .ALT node in cL")
                    print("  cL.number: \(cL.number)")
                    print("  cL.str: '\(cL.str)'")
                    print("  cL.seq: \(String(describing: cL.seq))")
                    print("  cL.alt: \(String(describing: cL.alt))")
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
                            if bracket.follow.contains(tokens[cI].kind) {
                                addYield(L: bracket, i: cU, k: cU, j: cI)
                                rtn(X: bracket)
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
        print(
            "\nmatched:", successfullParses,
            "  failed:", failedParses,
            "  crf size:", crf.count,
            "  descriptors:", descriptorCount,
            "  duplicateDescriptors:", duplicateDescriptorCount
        )

        if successfullParses == 0 {
            print("the furthest token mismatch was with '\(furthestMismatch.0.image)' \(furthestMismatch.0)")
            let expectedTokens: Set<String> = furthestMismatch.1
            let tokenStartIndex = furthestMismatch.0.image.startIndex
            let position = furthestMismatch.0.image.base.linePosition(of: tokenStartIndex)
            print("the expected tokens were \(expectedTokens) at message position \(position)")
        }
    }

    // MARK: - Internal helpers

    // TODO:  why is this no longer used?
    func testRepeat() -> Bool {
        let d = Descriptor(L: cL, k: cU, i: cI)
        return !unique.insert(d).inserted
    }

    func testSelect(slot: GrammarNode, bracket: GrammarNode) -> Bool {
        var current = tokens[cI]
        repeat { // to handle Schrödinger tokens
            if slot.first.contains(current.kind)
                || slot.first.contains("") && bracket.follow.contains(current.kind) {
                return true
            }
            guard let next = current.dual else { return false }
            current = next
        } while true
    }

    func tokenMatch() -> Bool {
        var current = tokens[cI]
        repeat {  // to handle Schrödinger tokens
            if cL.str == current.kind { return true }
            guard let next = current.dual else { return false }
            current = next
        } while true
    }
}
