//
//  _ParseMessage.swift
//  Advent
//
//  Created by Johannes Brands on 23/12/2024.
//

import Foundation

enum ParserError: Error { case unexpectedToken, didNotReachEndOfInput, missingSequence }

func _parseMessage() throws {
    
    nextDescriptor: while getDescriptor() {
        
        while true {
            
            trace("parse slot", _currentSlot.kindName, _currentSlot, "token: \(token.image)")
            
            // skip to next descriptor if token is not expected
            if _currentSlot.isExpecting(token) == false {
                _failedParses += 1
                trace("NOGOOD Parse ended due to unexpected token", terminator: "\n")
                continue nextDescriptor
            }
            
            // switch to .LL1 mode if only one single path is possible
            let _isAmbiguous = _currentSlot.ambiguous.contains(token.kind)
            
            switch _currentSlot.kind {
            case .EOS:
                break
            case .T:
                next()
                guard let seq = _currentSlot.seq else { throw ParserError.missingSequence }
                _currentSlot = seq
            case .TI:
                break
            case .C:
                break
            case .B:
                break
            case .EPS:
                guard let seq = _currentSlot.seq else { throw ParserError.missingSequence }
                _currentSlot = seq
            case .N:
                call(slot: _currentSlot)
                continue nextDescriptor
            case .ALT:
                break
            case .END:
                ret()
                continue nextDescriptor
            case .DO:
                break
            case .OPT:
                break
            case .POS:
                break
            case .KLN:
                if _currentSlot.first.contains(token.kind) {
                    _currentSlot = _currentSlot.alt ?? _currentSlot
                }
                if _currentSlot.follow.contains(token.kind) {
                    if let seq = _currentSlot.seq { _create(slot: seq) }
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

            if _currentIndex == tokens.count {
                _successfullParses += 1
                trace("HURRAH token = \(token)", terminator: "\n")
            }
        }
    }
    
    trace(
        "\nmatched:", _successfullParses,
        "  failed:", _failedParses,
        "  gss size:", _graph.count,
        "  descriptors:", _addedDescriptors
    )
}


