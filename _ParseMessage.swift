//
//  _ParseMessage.swift
//  Advent
//
//  Created by Johannes Brands on 23/12/2024.
//

import Foundation

func _parseMessage() {
    
    while !_remainder.isEmpty {
        let d = _remainder.removeLast()
        trace("get Descriptor(slot: \(d.slot.description), stack: \(d.stack.description), index: \(d.index))")
        _currentStack = d.stack
//        currentIndex(to: d.index)
        currentIndex = d.index
//        token = tokens[currentIndex]
//        next()
        _currentSlot = d.slot
        
        do {
            
            trace("parse node", _currentSlot.kindName)
            
            if _currentSlot.isExpecting(token) == false {
                throw ParseFailure.unexpectedToken
            }
            
            // switch to .LL1 mode if only one single path is possible
            _isAmbiguous = _currentSlot.ambiguous.contains(token.kind)
            
            switch _currentSlot.kind {
                
            case .EOS:
                break
            case .T:
                break
            case .TI:
                break
            case .C:
                break
            case .B:
                break
            case .EPS:
                break
            case .N:
                break
            case .ALT:
                break
            case .END:
                break
            case .DO:
                break
            case .OPT:
                break
            case .POS:
                break
            case .KLN:
                break
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
            
            // TODO: update success criteria
            if token.range.upperBound == input.endIndex {
                _successfullParses += 1
                trace("HURRAH", terminator: "\n")
            }
             
            _pop()
            
        } catch let error {
            _failedParses += 1
            trace("NOGOOD Parse ended due to \(error)", terminator: "\n")
        }
    }
    
    trace(
        "\nmatched:", _successfullParses,
        "  failed:", _failedParses,
        "  gss size:", _graph.count,
        "  descriptors:", _addedDescriptors
    )
}


