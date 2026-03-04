//
//  ClusteredNonterminalParser.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

// Paper: cL = current grammar slot
// Paper: cI — current input position (the current active token)
// Paper: cU — current cluster index (the input position where the last nonTerminal was called)
// Paper: R = pending descriptors, U = processed descriptors
// Paper: dscAdd/dscGet = descriptor operations, ntAdd = nonterminal alternates
// Paper: call = enter nonterminal, rtn = return from nonterminal
// Paper: bsrAdd = add BSR element

import Foundation

var currentParseRoot: GrammarNode!
var cL: GrammarNode!
var cI: Int = 0
var cU: Int = 0

// clear all previous parsing results
func resetMessageParser(root: GrammarNode) {
    R = []
    U = []
    currentParseRoot = root
    let rootCluster = Cluster(slot: root, index: 0)
    crf[CRFPosition(slot: root, index: 0)] = rootCluster
    cU = 0
    
    root.clearNodes()
    
    failedParses = 0
    successfullParses = 0
    descriptorCount = 0
    duplicateDescriptorCount = 0
}

var furthestMismatch: (Token, Set<String>) = (tokens[0], [])        // tokens contains at least the '$' a.k.a. EOS token

func parseMessage() {
    nextDescriptor: while dscGet() {
        
        while true {
            
            trace = true
            #if DEBUG
            trace("slot: \(String(format: "%2d", cL.number)) \(cL.ebnfDot()) first \(cL.first) follow \(cL.follow) token: \(token.kind) \(token.image)")
            #endif
            trace = false
            
            switch cL.kind {
            case .EPS:
                bsrAdd(L: cL, i: cU, k: cI, j: cI)
                cL = cL.seq!
            case .T, .TI, .C, .B:
                if tokenMatch() {
                    bsrAdd(L: cL, i: cU, k: cI, j: cI + 1)
                    cI += 1
                    #if DEBUG
                    trace = true
                    trace("next", token.image, token.kind)
                    trace = false
                    #endif
                    cL = cL.seq!
                } else {
                    failedParses += 1
                    if token.image.startIndex > furthestMismatch.0.image.endIndex {
                        furthestMismatch = (token, [cL.str])
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
                    dscAdd(L: cL.seq!, k: cU, i: cI)
                    bsrAdd(L: cL, i: cU, k: cI, j: cI)  // empty bracket BSR
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
                        if bracket.follow.contains(token.kind) {
                            bsrAdd(L: bracket, i: cU, k: cU, j: cI)
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

func testRepeat() -> Bool {
    let d = Descriptor(slot: cL, k: cU, i: cI)
    return !U.insert(d).inserted
}

func testSelect(slot: GrammarNode, bracket: GrammarNode) -> Bool {
    var current = token
    repeat { // to handle Schrödinger tokens
        if slot.first.contains(current.kind) || slot.first.contains("") && bracket.follow.contains(current.kind) { return true }
        guard let next = current.dual else { return false }
        current = next
    } while true
}

func tokenMatch() -> Bool {
    var current = token
    repeat {  // to handle Schrödinger tokens
        if cL.str == current.kind { return true }
        guard let next = current.dual else { return false }
        current = next
    } while true
}

