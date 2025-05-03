//
//  ClusteredNonterminalParser.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

import Foundation

var remainder: [Descriptor] = []

var currentCluster = Position(slot: grammarRoot, index: 0)    // the current CRF cluster node

// clear all previous parsing results
func resetMessageParser() {
    remainder = []
    currentCluster = Position(slot: grammarRoot, index: 0)
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

var furthestMismatch: (Token, Set<String>) = (tokens[0], [])        // there is always at least the '$' a.k.a. EOS token

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
                addYield(node: currentSlot, i: currentIndex, k: currentIndex, j: currentIndex)
                currentSlot = currentSlot.seq!
            case .T, .TI, .C, .B:
                if tokenMatch() {
                    addYield(node: currentSlot, i: currentIndex, k: currentIndex, j: currentIndex + 1)
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
                if testSelect() {
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
                    if testSelect(slot: currentSlot.seq!) {
                        // bsrAdd()
                        // schedule the next slot
                        addDescriptor(slot: currentSlot.seq!, cluster: currentCluster, index: currentIndex)
                        _ = testRepeat()
                    }
                    // move to the first branch
                    currentSlot = currentSlot.alt!
                } else {
                    if testSelect(slot: currentSlot.seq!) {
                        // bsrAdd()
                        // schedule the next slot
                        addDescriptor(slot: currentSlot.seq!, cluster: currentCluster, index: currentIndex)
                    }
                    if !testSelect() {
                        continue nextDescriptor
                    } else {
                        // move to the first branch
                        currentSlot = currentSlot.alt!
                    }
                }
            case .KLN:
                if currentSlot.first.contains("") {
                    // TODO: something with bsrAdd() to record slots
                    if testSelect(slot: currentSlot.seq!) {
                        // schedule the next slot
                        addDescriptor(slot: currentSlot.seq!, cluster: currentCluster, index: currentIndex)
                    }
                    if testRepeat() {
                        continue nextDescriptor
                    }
                    if !testSelect() {
                        continue nextDescriptor
                    }
                    if testSelect() {
                        // move to the first branch
                        currentSlot = currentSlot.alt!
                    }
                } else {
                    if testSelect(slot: currentSlot.seq!) {
                        // schedule the next slot
                        addDescriptor(slot: currentSlot.seq!, cluster: currentCluster, index: currentIndex)
                    }
                    if !testSelect() {
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
                        leave()
                        continue nextDescriptor
                    }
                case .DO:
                    if testRepeat() { continue nextDescriptor }
                    currentSlot = bracket.seq!
                case .OPT:
                    if testRepeat() {
                        continue nextDescriptor
                    } else {
                        // move to the slot after the bracket
                        currentSlot = bracket.seq!
                    }
                case .KLN, .POS:
                    // schedule the branch again
                    if testSelect() {
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
    
    print(grammarRoot.ebnfDot())
//    successfullParses = yields.filter { y in y.node == grammarRoot && y.i == 0 && y.j == input.count-1 }.count
    print(yields)
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

func testSelect(slot: GrammarNode = currentSlot) -> Bool {    // handles Schrödinger tokens
    var current = token
    repeat {
        // slot.follow is equal to the production.follow IFF slot.first contains eps
        if slot.first.contains(current.kind) || slot.first.contains("") && slot.follow.contains(current.kind) { return true }
        guard let next = current.dual else { return false }
        current = next
    } while true
}

func tokenMatch() -> Bool {    // handles Schrödinger tokens
    var current = token
    repeat {
        if currentSlot.str == current.kind { return true }
        guard let next = current.dual else { return false }
        current = next
    } while true
}


