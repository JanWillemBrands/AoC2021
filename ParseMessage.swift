//
//  ParseMessage.swift
//  Advent
//
//  Created by Johannes Brands on 23/12/2024.
//

import Foundation

//enum ParserError: Error { case unexpectedToken, didNotReachEndOfInput }

func parseMessage() throws {
    
    func testSelect() -> Bool {
        if currentSlot.first.contains(token.kind) ||
            currentSlot.first.contains("") && currentSlot.follow.contains(token.kind) {
            return true
        }
        return false
    }
    
    nextDescriptor: while getDescriptor() {
        
        while true {
            
            trace("parse slot", currentSlot.kindName)
            
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
                    trace("NOGOOD Parse ended due to unexpected token", terminator: "\n")
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
                    addDescriptor(slot: currentSlot.seq!, stack: currentStack, index: index)
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
                addDescriptor(slot: currentSlot.alt!, stack: currentStack, index: index)
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
                    addDescriptor(slot: bracket.alt!, stack: currentStack, index: index)
                    // move to the next slot
                    currentSlot = bracket.seq!
                default:
                    fatalError("unexpected bracket kind at END seq link \(bracket.kind)")
                }
            }
        }
    }
    
    trace(
        "\nmatched:", successfullParses,
        "  failed:", failedParses,
        "  gss size:", gss.count,
        "  descriptors:", descriptorCount
    )
}


