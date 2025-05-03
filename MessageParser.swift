////
////  MessageParser.swift
////  Advent
////
////  Created by Johannes Brands on 23/12/2024.
////
//
//import Foundation
//
////enum ParserError: Error { case unexpectedToken, didNotReachEndOfInput }
//
//// the list of Decriptors that still need to be processed
//var remainder: [Descriptor] = []
//
//// the graph-structured-stack that keeps track of execution
//var gss: Set<StackNode> = [gssRoot]
//var gssRoot = StackNode(slot: GrammarNode(kind: .EOS, str: "$"), index: 0)
//
//// clear all previous parsing results
//func resetMessageParser() {
//    remainder = []
//    gssRoot = StackNode(slot: GrammarNode(kind: .EOS, str: "$"), index: 0)
//    gss = [gssRoot]
//    grammarRoot.clearNodes()
//    
//    failedParses = 0
//    successfullParses = 0
//    descriptorCount = 0
//    duplicateDescriptorCount = 0
//}
//
//var furthestMismatch: (Token, Set<String>) = (tokens[0], [])        // there is always at least the '$' a.k.a. EOS token
//
//func parseMessage() {
//    nextDescriptor: while getDescriptor() {
//        
//        while true {
//            
//            trace = true
//            #if DEBUG
//            trace("slot: \(String(format: "%2d", currentSlot.number)) \(currentSlot.ebnfDot()) first \(currentSlot.first) follow \(currentSlot.follow) token: \(token.kind) \(token.image)")
////            trace("slot: \(String(format: "%2d", currentSlot.number))")
////            trace("\(currentSlot.ebnfDot()) first \(currentSlot.first) follow \(currentSlot.follow) token: \(token.kind) \(token.image)")
//            #endif
//            trace = false
//            // TODO: switch to .LL1 mode if only one single path is possible
//            // TODO: let _isAmbiguous = _currentSlot.ambiguous.contains(token.kind)
//            
//            switch currentSlot.kind {
//            case .EPS:
//                addYield(currentSlot, currentIndex, currentIndex, currentIndex)
//                currentSlot = currentSlot.seq!
//            case .T, .TI, .C, .B:
//                if tokenMatch() {
//                    addYield(currentSlot, currentIndex, currentIndex, currentIndex + 1)
//                    currentIndex += 1
//                    #if DEBUG
//                    trace("next", token.image, token.kind)
//                    #endif
//                    currentSlot = currentSlot.seq!
//                } else {
//                    failedParses += 1
//                    if token.image.startIndex > furthestMismatch.0.image.endIndex {
//                        furthestMismatch = (token, [currentSlot.str])
//                    }
//                    #if DEBUG
//                    trace("NOGOOD Parse ended due to unexpected token", terminator: "\n")
//                    #endif
//                    continue nextDescriptor
//                }
//            case .N:
//                call(slot: currentSlot)
//                continue nextDescriptor
//            case .ALT:
//                if testSelect() {
//                    addDescriptor(slot: currentSlot.seq!, stack: currentCluster, index: currentIndex)
//                }
//                if let alt = currentSlot.alt {
//                    currentSlot = alt
//                } else {
//                    continue nextDescriptor
//                }
//            case .DO, .POS:
//                // move to the first branch
//                currentSlot = currentSlot.alt!
//            case .OPT:
//                if currentSlot.first.contains("") {
//                    if testSelect(slot: currentSlot.seq!) {
//                        // bsrAdd()
//                        // schedule the next slot
//                        addDescriptor(slot: currentSlot.seq!, stack: currentCluster, index: currentIndex)
//                        _ = testRepeat()
//                    }
//                    // move to the first branch
//                    currentSlot = currentSlot.alt!
//                } else {
//                    if testSelect(slot: currentSlot.seq!) {
//                        // bsrAdd()
//                        // schedule the next slot
//                        addDescriptor(slot: currentSlot.seq!, stack: currentCluster, index: currentIndex)
//                    }
//                    if !testSelect() {
//                        continue nextDescriptor
//                    } else {
//                        // move to the first branch
//                        currentSlot = currentSlot.alt!
//                    }
//                }
//            case .KLN:
//                if currentSlot.first.contains("") {
//                    // TODO: something with bsrAdd() to record slots
//                    if testSelect(slot: currentSlot.seq!) {
//                        // schedule the next slot
//                        addDescriptor(slot: currentSlot.seq!, stack: currentCluster, index: currentIndex)
//                    }
//                    if testRepeat() {
//                        continue nextDescriptor
//                    }
//                    if !testSelect() {
//                        continue nextDescriptor
//                    }
//                    if testSelect() {
//                        // move to the first branch
//                        currentSlot = currentSlot.alt!
//                    }
//                } else {
//                    if testSelect(slot: currentSlot.seq!) {
//                        // schedule the next slot
//                        addDescriptor(slot: currentSlot.seq!, stack: currentCluster, index: currentIndex)
//                    }
//                    if !testSelect() {
//                        continue nextDescriptor
//                    } else {
//                        // move to the first branch
//                        currentSlot = currentSlot.alt!
//                    }
//                }
//            case .END:
//                // the seq link of an END node points back to a starting bracket node (N, DO, OPT, POS, KLN)
//                let bracket = currentSlot.seq!
//                switch bracket.kind {
//                case .N:
//                    if let seq = bracket.seq {
//                        // the bracket is a RHS nonterminal
//                        currentSlot = seq
//                    } else {
//                        // the bracket is a LHS nonterminal
//                        ret()
//                        continue nextDescriptor
//                    }
//                case .DO:
//                    if testRepeat() {
//                        continue nextDescriptor
//                    } else {
//                        // move to the slot after the bracket
//                        currentSlot = bracket.seq!
//                    }
//                case .OPT:
//                    if testRepeat() {
//                        continue nextDescriptor
//                    } else {
//                        // move to the slot after the bracket
//                        currentSlot = bracket.seq!
//                    }
//                case .KLN, .POS:
//                    // schedule the branch again
//                    if testSelect() {
//                        addDescriptor(slot: bracket.alt!, stack: currentCluster, index: currentIndex)
//                    }
//                    // move to the slot after the bracket
////                    if testRepeat() {
//                        currentSlot = bracket.seq!
////                    } else {
////                        continue nextDescriptor
////                    }
//                default:
//                    fatalError("unexpected bracket kind at END seq link \(bracket.kind)")
//                }
//            case .EOS:
//                break
//            }
//        }
//    }
//    
//    print(
//        "\nmatched:", successfullParses,
//        "  failed:", failedParses,
//        "  gss size:", gss.count,
//        "  descriptors:", descriptorCount,
//        "  duplicateDescriptors:", duplicateDescriptorCount
//    )
//    
//    if successfullParses == 0 {
//        print("the furthest token mismatch was with '\(furthestMismatch.0.image)' \(furthestMismatch.0)")
//        print("the expected tokens were \(furthestMismatch.1) at message position \(input.linePosition(of: furthestMismatch.0.image.startIndex))")
//    }
//}
//
//func testRepeat() -> Bool {
//    let si = Position(slot: currentSlot, index: currentIndex)
//    return !currentCluster.unique.insert(si).inserted
//}
//
//func testSelect(slot: GrammarNode = currentSlot) -> Bool {    // handles Schrödinger tokens
//    var current = token
//    repeat {
//        // slot.follow is equal to the production.follow IFF slot.first contains eps
//        if slot.first.contains(current.kind) || slot.first.contains("") && slot.follow.contains(current.kind) { return true }
//        guard let next = current.dual else { return false }
//        current = next
//    } while true
//}
//
//func tokenMatch() -> Bool {    // handles Schrödinger tokens
//    var current = token
//    repeat {
//        if currentSlot.str == current.kind { return true }
//        guard let next = current.dual else { return false }
//        current = next
//    } while true
//}
//
