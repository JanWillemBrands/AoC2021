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
}

func parseMessage() throws {
    
    nextDescriptor: while getDescriptor() {
        
        while true {
            
#if DEBUG
            trace("parse slot", currentSlot, currentSlot.kindName)
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
                    failedParses += 1
#if DEBUG
                   trace("NOGOOD Parse ended due to unexpected token", terminator: "\n")
#endif
                    continue nextDescriptor
                }
            case .EPS:
                // do nothing, move to the next slot
                currentSlot = currentSlot.seq!
            case .N:
                call(slot: currentSlot)
                continue nextDescriptor
            case .ALT:
                if let alt = currentSlot.alt {
                    // schedule the current branch
                    addDescriptor(slot: currentSlot.seq!, stack: currentStack, index: currentIndex)
                    // move to the next branch
                    currentSlot = alt
                } else {
                    // handle the last branch
                    currentSlot = currentSlot.seq!
                }
            case .DO, .POS:
                // move to the first branch
                currentSlot = currentSlot.alt!
            case .OPT, .KLN:
                // schedule the optional branch
                addDescriptor(slot: currentSlot.alt!, stack: currentStack, index: currentIndex)
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
                    addDescriptor(slot: bracket.alt!, stack: currentStack, index: currentIndex)
                    // move to the next slot
                    currentSlot = bracket.seq!
                default:
                    fatalError("unexpected bracket kind at END seq link \(bracket.kind)")
                }
            }
        }
    }
    
#if DEBUG
    trace(
        "\nmatched:", successfullParses,
        "  failed:", failedParses,
        "  gss size:", gss.count,
        "  descriptors:", descriptorCount
    )
#endif
}


func testSelect() -> Bool {
    if currentSlot.first.contains(token.kind) ||
        currentSlot.first.contains("") && currentSlot.follow.contains(token.kind) {
        return true
    }
    return false
}

