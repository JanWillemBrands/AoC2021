//
//  MessageParser.swift
//  Advent
//
//  Created by Johannes Brands on 23/12/2024.
//

import Foundation

//enum ParserError: Error { case unexpectedToken, didNotReachEndOfInput }

// the list of Decriptors that still need to be processed
var remainder: [Descriptor] = []

// the graph-structured-stack that keeps track of execution
var gss: Set<StackNode> = [gssRoot]
var gssRoot = StackNode(slot: GrammarNode(kind: .EOS, str: "$"), index: 0)

// clear all previous parsing results
func resetMessageParser() {
    remainder = []
    gssRoot = StackNode(slot: GrammarNode(kind: .EOS, str: "$"), index: 0)
    gss = [gssRoot]
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
            
            #if DEBUG
            trace("slot: \(currentSlot.kindName) \(currentSlot.str) first \(currentSlot.first) follow \(currentSlot.follow) token: \(token.kind) \(token.image)")
            #endif
            // TODO: add first check before each instance of addDescriptor
            // TODO: verify testSelect()
            // TODO: switch to .LL1 mode if only one single path is possible
            // TODO: let _isAmbiguous = _currentSlot.ambiguous.contains(token.kind)
            switch currentSlot.kind {
            case .EOS:
                break
            case .T, .TI, .C, .B:
                if currentSlot.str == token.kind {
                    next()
                    currentSlot = currentSlot.seq!
                } else {
                    if schrödingerTokenMatch() {
                        next()
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
                }
            case .EPS:
                // do nothing, move to the next slot
                currentSlot = currentSlot.seq!
            case .N:
                call(slot: currentSlot)
                continue nextDescriptor
            case .ALT:
                    if let alt = currentSlot.alt {
                        // schedule the current branch with a descriptor
                        if testSelect() {
                            addDescriptor(slot: currentSlot.seq!, stack: currentStack, index: currentIndex)
                        }
                        // move to the next branch
                        currentSlot = alt
                    } else {
//                        addDescriptor(slot: currentSlot.seq!, stack: currentStack, index: currentIndex)
//                        continue nextDescriptor
                        // the last branch does not need a descriptor (with last-in-first-out descriptor scheduling)
                        if testSelect() {
                            currentSlot = currentSlot.seq!
                        } else {
                            continue nextDescriptor
                        }
                    }
            case .DO, .POS:
                // move to the first branch
                currentSlot = currentSlot.alt!
            case .OPT, .KLN:
                // schedule the optional branch
                if testSelect() {
                    addDescriptor(slot: currentSlot.alt!, stack: currentStack, index: currentIndex)
                }
                // move to the next slot
                currentSlot = currentSlot.seq!
            case .END:
                // the seq link of an END node points back to a starting bracket node (N, DO, OPT, POS, KLN)
                let bracket = currentSlot.seq!
                switch bracket.kind {
                case .N:
                    if let seq = bracket.seq {
                        // the bracket is a RHS nonterminal
                        currentSlot = seq
                    } else {
                        // the bracket is a LHS nonterminal
                        ret()
                        continue nextDescriptor
                    }
                case .DO, .OPT:
                    // move to the next slot
                    currentSlot = bracket.seq!
                case .KLN, .POS:
                    // schedule the branch again
                    if testSelect() {
                        addDescriptor(slot: bracket.alt!, stack: currentStack, index: currentIndex)
                    }
                    // move to the next slot
                    currentSlot = bracket.seq!
                default:
                    fatalError("unexpected bracket kind at END seq link \(bracket.kind)")
                }
            }
        }
    }
    
    print(
        "\nmatched:", successfullParses,
        "  failed:", failedParses,
        "  gss size:", gss.count,
        "  descriptors:", descriptorCount,
        "  duplicateDescriptors:", duplicateDescriptorCount
    )
    
    if successfullParses == 0 {
        print("the furthest token mismatch was with '\(furthestMismatch.0.image)' \(furthestMismatch.0)")
        print("the expected tokens were \(furthestMismatch.1) at position \(input.linePosition(of: furthestMismatch.0.image.startIndex))")
    }
}

func _testSelect() -> Bool {    // does NOT handle Schrödinger tokens
    if currentSlot.first.contains(token.kind) ||
        currentSlot.first.contains("") && currentSlot.follow.contains(token.kind) {
        return true
    }
    return false
}

var immediateMatch = 0
var subsequentMatch = 0
var ultimateFail = 0

func testSelect() -> Bool {
//    return true
    if currentSlot.first.contains(token.kind) ||
        currentSlot.first.contains("") && currentSlot.follow.contains(token.kind) {
        immediateMatch += 1
        return true
    }
    var current = token
    while let node = current.dual {
        if currentSlot.first.contains(node.kind) ||
            currentSlot.first.contains("") && currentSlot.follow.contains(node.kind) {
            subsequentMatch += 1
            return true
        }
        current = node
    }
    ultimateFail += 1
    return false
}


func __testSelect() -> Bool {    // handles Schrödinger tokens
    var current = token
    repeat {
        if currentSlot.first.contains(current.kind) ||
            currentSlot.first.contains("") && currentSlot.follow.contains(current.kind) {
            return true
        }
        if let node = current.dual {
            current = node
        } else {
            return false
        }
    } while true
}

func ___testSelect() -> Bool {    // handles Schrödinger tokens
    var current = token
    repeat {
        if currentSlot.first.contains(current.kind) ||
            currentSlot.first.contains("") && currentSlot.follow.contains(current.kind) {
            return true
        }
        guard let next = current.dual else { return false }
        current = next
    } while true
}



func schrödingerTokenMatch() -> Bool {    // handles only Schrödinger tokens
    var current = token
    while let node = current.dual {
        if currentSlot.str == node.kind { return true }
        current = node
    }
    return false
}

func tokenMatch() -> Bool {    // handles all tokens including Schrödinger tokens
    var current = token
    repeat {
        if currentSlot.str == current.kind { return true }
        guard let next = current.dual else { return false }
        current = next
    } while true
}

