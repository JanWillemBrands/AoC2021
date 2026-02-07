//
//  ClusteredNonterminalParser.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

import Foundation

var remainder: [Descriptor] = []

var currentCluster = Position(slot: grammarRoot, index: 0)    // the current CRF cluster node
var crfRoot = currentCluster

// clear all previous parsing results
func resetMessageParser() {
    remainder = []
    currentCluster = crfRoot
    crf.insert(currentCluster)
    crfRoot = currentCluster
    
//    gssRoot = StackNode(slot: GrammarNode(kind: .EOS, str: "$"), index: 0)
//    gss = [gssRoot]

    grammarRoot.clearNodes()
    
    failedParses = 0
    successfullParses = 0
    descriptorCount = 0
    duplicateDescriptorCount = 0
}

var furthestMismatch: (Token, Set<String>) = (tokens[0], [])        // tokens contains at least the '$' a.k.a. EOS token

func parseMessage() {
    nextDescriptor: while getDescriptor() {
        
        while true {
            
            trace = true
            #if DEBUG
            trace("slot: \(String(format: "%2d", currentSlot.number)) \(currentSlot.ebnfDot()) first \(currentSlot.first) follow \(currentSlot.follow) token: \(token.kind) \(token.image)")
//            trace("slot: \(String(format: "%2d", currentSlot.number))")
//            trace("\(currentSlot.ebnfDot()) first \(currentSlot.first) follow \(currentSlot.follow) token: \(token.kind) \(token.image)")
            #endif
            trace = false
            // TODO: switch to .LL1 mode if only one single path is possible
            // TODO: let _isAmbiguous = _currentSlot.ambiguous.contains(token.kind)
            
            switch currentSlot.kind {
            case .EPS:
                addYield(slot: currentSlot, i: currentCluster.index, k: currentIndex, j: currentIndex)
                currentSlot = currentSlot.seq!
            case .T, .TI, .C, .B:
                if tokenMatch() {
                    addYield(slot: currentSlot, i: currentCluster.index, k: currentIndex, j: currentIndex + 1)
                    currentIndex += 1
                    #if DEBUG
                    trace = true
                    trace("next", token.image, token.kind)
                    trace = false
                    #endif
                    currentSlot = currentSlot.seq!
                } else {
                    failedParses += 1
                    if token.image.startIndex > furthestMismatch.0.image.endIndex {
                        furthestMismatch = (token, [currentSlot.str])
                    }
                    #if DEBUG
                    trace("NOGOOD Parse ended due to unexpected token", terminator: "\n")
                    #endif
                    continue nextDescriptor
                }
            case .N:
                enter()
                continue nextDescriptor
            case .ALT:
                fatalError(#function + ": ALT should not happen here")
                if testSelect(slot: currentSlot, bracket: currentSlot) {
                    addDescriptor(slot: currentSlot.seq!, cluster: currentCluster, index: currentIndex)
                }
                if let alt = currentSlot.alt {
                    currentSlot = alt
                } else {
                    continue nextDescriptor
                }
            case .DO, .POS:
                // move to the first branch
                currentSlot = currentSlot.alt!
            case .OPT:
                if currentSlot.first.contains("") {
                    if testSelect(slot: currentSlot.seq!, bracket: currentSlot) {
                        // bsrAdd()
                        // schedule the next slot
                        addDescriptor(slot: currentSlot.seq!, cluster: currentCluster, index: currentIndex)
                        _ = testRepeat()
                    }
                    // move to the first branch
                    currentSlot = currentSlot.alt!
                } else {
                    if testSelect(slot: currentSlot.seq!, bracket: currentSlot) {
                        // bsrAdd()
                        // schedule the next slot
                        addDescriptor(slot: currentSlot.seq!, cluster: currentCluster, index: currentIndex)
                    }
                    if !testSelect(slot: currentSlot, bracket: currentSlot) {
                        continue nextDescriptor
                    } else {
                        // move to the first branch
                        currentSlot = currentSlot.alt!
                    }
                }
            case .KLN:
                if currentSlot.first.contains("") {
                    // TODO: something with bsrAdd() to record slots
                    if testSelect(slot: currentSlot.seq!, bracket: currentSlot) {
                        // schedule the next slot
                        addDescriptor(slot: currentSlot.seq!, cluster: currentCluster, index: currentIndex)
                    }
                    if testRepeat() {
                        continue nextDescriptor
                    }
                    if !testSelect(slot: currentSlot, bracket: currentSlot) {
                        continue nextDescriptor
                    }
                    if testSelect(slot: currentSlot, bracket: currentSlot) {
                        // move to the first branch
                        currentSlot = currentSlot.alt!
                    }
                } else {
                    if testSelect(slot: currentSlot.seq!, bracket: currentSlot) {
                        // schedule the next slot
                        addDescriptor(slot: currentSlot.seq!, cluster: currentCluster, index: currentIndex)
                    }
                    if !testSelect(slot: currentSlot, bracket: currentSlot) {
                        continue nextDescriptor
                    } else {
                        // move to the first branch
                        currentSlot = currentSlot.alt!
                    }
                }
            case .END:
                // the seq link of an END node always points back to a starting bracket node (N, DO, OPT, POS, KLN)
                let bracket = currentSlot.seq!
                
                switch bracket.kind {
                case .N:
                    if let seq = bracket.seq {
                        // the bracket is a RHS nonterminal
                        currentSlot = seq
                    } else {
                        // the bracket is a LHS nonterminal
                        if bracket.follow.contains(token.kind) {
                            leave()
                        }
                        continue nextDescriptor
                    }
                case .DO:
                    if testRepeat() {
                        continue nextDescriptor
                    } else {
                        currentSlot = bracket.seq!
                    }
                case .OPT:
                    if testRepeat() {
                        continue nextDescriptor
                    } else {
                        currentSlot = bracket.seq!
                    }
                case .KLN, .POS:
                    // schedule the branch again
                    if testSelect(slot: currentSlot, bracket: bracket) {
                        addDescriptor(slot: bracket.alt!, cluster: currentCluster, index: currentIndex)
                    }
                    // move to the slot after the bracket
//                    if testRepeat() {
                        currentSlot = bracket.seq!
//                    } else {
//                        continue nextDescriptor
//                    }
                default:
                    fatalError("unexpected bracket kind at END seq link \(bracket.kind)")
                }
            case .EOS:
                break
            }
        }
    }
    
    successfullParses = grammarRoot.yield.filter { y in y.i == 0 && y.j == tokens.count-1 }.count
    print(
        "\nmatched:", successfullParses,
        "  failed:", failedParses,
        "  gss size:", crf.count,
        "  descriptors:", descriptorCount,
        "  duplicateDescriptors:", duplicateDescriptorCount
    )
    
    if successfullParses == 0 {
        print("the furthest token mismatch was with '\(furthestMismatch.0.image)' \(furthestMismatch.0)")
        print("the expected tokens were \(furthestMismatch.1) at message position \(input.linePosition(of: furthestMismatch.0.image.startIndex))")
    }
}

func testRepeat() -> Bool {
    let si = Position(slot: currentSlot, index: currentIndex)
    return !currentCluster.unique.insert(si).inserted
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
        if currentSlot.str == current.kind { return true }
        guard let next = current.dual else { return false }
        current = next
    } while true
}


