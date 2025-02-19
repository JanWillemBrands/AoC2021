//
//  _ParseMessage.swift
//  Advent
//
//  Created by Johannes Brands on 23/12/2024.
//

import Foundation

enum ParserError: Error { case unexpectedToken, didNotReachEndOfInput }

func _parseMessage() throws {
    
    nextDescriptor: while getDescriptor() {
        
        while true {
            
            trace("parse slot", currentSlot.kindName)
            
            // TODO: re-implement LL1 optimizations
            // skip to next descriptor if token is not expected
            //            if _currentSlot.kind == .END || _currentSlot.isExpecting(token) == false {
            //                _failedParses += 1
            //                trace("NOGOOD Parse ended due to unexpected token", terminator: "\n")
            //                continue nextDescriptor
            //            }
            // switch to .LL1 mode if only one single path is possible
            //            let _isAmbiguous = _currentSlot.ambiguous.contains(token.kind)
            
            switch currentSlot.kind {
            case .EOS:
                break
            case .T:
                if currentSlot.str == token.kind {
                    next()
                    currentSlot = currentSlot.seq!
                } else {
                    failedParses += 1
                    trace("NOGOOD Parse ended due to unexpected token", terminator: "\n")
                    continue nextDescriptor
                }
            case .TI:
                break
            case .C:
                break
            case .B:
                break
            case .EPS:
                currentSlot = currentSlot.seq!
            case .N:
                call(slot: currentSlot)
                continue nextDescriptor
            case .END:
//                ret()
//                continue nextDescriptor
                // The seq link of an END node always points back to the starting bracket node (N, DO, OPT, POS, KLN)
                let bracket = currentSlot.seq!
                if bracket.kind == .N && bracket.seq == nil {
                    // if the bracket is a LHS nonTerminal
                    ret()
                    continue nextDescriptor
                } else {
                    // otherwise the bracket is a DO, OPT, POS or KLN
                    currentSlot = bracket.seq!
                }
            case .ALT:
                break
            case .DO:
                var current = currentSlot
                while let next = current.alt, let seq = next.seq {
                    addDescriptor(slot: seq, stack: currentStack, index: index)
                    current = next
                }
                continue nextDescriptor
            case .OPT:
                break
            case .POS:
                break
            case .KLN:
                if currentSlot.first.contains(token.kind) {
                    currentSlot = currentSlot.alt!
                }
                if currentSlot.follow.contains(token.kind) {
                    create(slot: currentSlot.seq!)
                }
            }
            
            
            //            switch _currentSlot.kind {
            //
            //            case .SEQ(let children):
            //                for child in children.reversed() {
            //                    create(slot: child)
            //                }
            //                // TODO: something to gather all the extents of its children
            //
            //            case .ALT(let children):
            //                for child in children where child.first.contains(token.kind) {
            //                    if isAmbiguous {
            //                        let saved = _currentStack
            //                        create(slot: child)
            //                        addDescriptor(slot: child, stack: saved, index: currentIndex)
            //                        currentStack = saved
            //                    } else {
            //                        create(slot: child)
            //                        break
            //                    }
            //                }
            //
            //            case .OPT(let child):
            //                if child.first.contains(token.kind) {
            //                    if _isAmbiguous {
            //                        let saved = _currentStack
            //                        _create(slot: child)
            //                        _addDescriptor(slot: child, stack: saved, index: currentIndex)
            //                        _currentStack = saved
            //                    } else {
            //                        _create(slot: child)
            //                    }
            //                }
            //
            //           case .REP(let child):
            //                if child.first.contains(token.kind) {
            //                    if _isAmbiguous {
            //                        let saved = _currentStack
            //                        _create(slot: _currentSlot)
            //                        let intermediate = _currentStack
            //                        _create(slot: child)
            //                        _addDescriptor(slot: child, stack: intermediate, index: currentIndex)
            //                        _currentStack = saved
            //                    } else {
            //                        _create(slot: _currentSlot)
            //                        _create(slot: child)
            //                    }
            //                }
            //
            //            case .NTR(_, let link):
            //                _create(slot: link!)     // all nonterminal links have been resolved in func populateLookAheadSets
            //
            //            case .TRM(_):
            //                _currentSlot.yield.insert(_Split(token.range.lowerBound, token.range.lowerBound, token.range.upperBound))
            //                next()
            //            }
            
            //            if _currentIndex == tokens.count - 1 {
            //                _successfullParses += 1
            //                trace("HURRAH token = \(token)", terminator: "\n")
            //            }
        }
    }
    
    trace(
        "\nmatched:", successfullParses,
        "  failed:", failedParses,
        "  gss size:", gss.count,
        "  descriptors:", descriptorCount
    )
}


