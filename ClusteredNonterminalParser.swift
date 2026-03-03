//
//  ClusteredNonterminalParser.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

import Foundation

var remainder: [Descriptor] = []

var currentParseRoot: GrammarNode!  // The root node for the current parse
var currentK: Int = 0               // Current cluster index (paper's cU / k)

// clear all previous parsing results
func resetMessageParser(root: GrammarNode) {
    remainder = []
    U = []
    currentParseRoot = root
    let rootCluster = Cluster(slot: root, index: 0)
    crf[CRFPosition(slot: root, index: 0)] = rootCluster
    currentK = 0
    
    root.clearNodes()
    
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
            #endif
            trace = false
            
            switch currentSlot.kind {
            case .EPS:
                addYield(slot: currentSlot, i: currentK, k: currentIndex, j: currentIndex)
                currentSlot = currentSlot.seq!
            case .T, .TI, .C, .B:
                if tokenMatch() {
                    addYield(slot: currentSlot, i: currentK, k: currentIndex, j: currentIndex + 1)
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
                print("ERROR: Unexpected .ALT node in currentSlot")
                print("  currentSlot.number: \(currentSlot.number)")
                print("  currentSlot.str: '\(currentSlot.str)'")
                print("  currentSlot.seq: \(String(describing: currentSlot.seq))")
                print("  currentSlot.alt: \(String(describing: currentSlot.alt))")
                fatalError(#function + ": ALT should not happen here")
            case .DO, .POS:
                addDescriptorsForAlternates(bracket: currentSlot, k: currentK, index: currentIndex)
                continue nextDescriptor
            case .OPT, .KLN:
                // OPT and KLN are always nullable (epsilon is always in first)
                // so we always offer the skip-past-bracket path
                if testSelect(slot: currentSlot.seq!, bracket: currentSlot) {
                    addDescriptor(slot: currentSlot.seq!, k: currentK, index: currentIndex)
                }
                addDescriptorsForAlternates(bracket: currentSlot, k: currentK, index: currentIndex)
                continue nextDescriptor
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
                            addYield(slot: bracket, i: currentK, k: currentK, j: currentIndex)
                            leave(nonterminal: bracket)
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
                    addDescriptorsForAlternates(bracket: bracket, k: currentK, index: currentIndex)
                    // move to the slot after the bracket
                    currentSlot = bracket.seq!
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
    let d = Descriptor(slot: currentSlot, k: currentK, index: currentIndex)
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
        if currentSlot.str == current.kind { return true }
        guard let next = current.dual else { return false }
        current = next
    } while true
}
