////
////  ParseMessage.swift
////  Advent
////
////  Created by Johannes Brands on 23/12/2024.
////
//
//import Foundation
//
//func parseMessage() {
//    
//    while !remainder.isEmpty {
//        let d = remainder.removeLast()
//        trace("get Descriptor(slot: \(d.slot.description), stack: \(d.stack.description), index: \(d.index))")
//        currentStack = d.stack
////        currentIndex(to: d.index)
//        currentIndex = d.index
////        token = tokens[currentIndex]
////        next()
//        currentSlot = d.slot
//        
//        do {
//            
//            trace("parse node", currentSlot.kindName)
//            
//            if currentSlot.isExpecting(token) == false {
//                throw ParseFailure.unexpectedToken
//            }
//            
//            // switch to .LL1 mode if only one single path is possible
//            isAmbiguous = currentSlot.ambiguous.contains(token.kind)
//            
//            switch currentSlot.kind {
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
//                        let saved = currentStack
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
//                    if isAmbiguous {
//                        let saved = currentStack
//                        create(slot: child)
//                        addDescriptor(slot: child, stack: saved, index: currentIndex)
//                        currentStack = saved
//                    } else {
//                        create(slot: child)
//                    }
//                }
//
//           case .REP(let child):
//                if child.first.contains(token.kind) {
//                    if isAmbiguous {
//                        let saved = currentStack
//                        create(slot: currentSlot)
//                        let intermediate = currentStack
//                        create(slot: child)
//                        addDescriptor(slot: child, stack: intermediate, index: currentIndex)
//                        currentStack = saved
//                    } else {
//                        create(slot: currentSlot)
//                        create(slot: child)
//                    }
//                }
//                
//            case .NTR(_, let link):
//                create(slot: link!)     // all nonterminal links have been resolved in func populateLookAheadSets
//                
//            case .TRM(_):
//                currentSlot.yield.insert(Split(token.range.lowerBound, token.range.lowerBound, token.range.upperBound))
//                next()
//            }
//            
//            // TODO: update success criteria
//            if token.range.upperBound == input.endIndex {
//                successfullParses += 1
//                trace("HURRAH", terminator: "\n")
//            }
//             
//            pop()
//            
//        } catch let error {
//            failedParses += 1
//            trace("NOGOOD Parse ended due to \(error)", terminator: "\n")
//        }
//    }
//    
//    trace(
//        "\nmatched:", successfullParses,
//        "  failed:", failedParses,
//        "  gss size:", graph.count,
//        "  descriptors:", addedDescriptors
//    )
//}
//
//
