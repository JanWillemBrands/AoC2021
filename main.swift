//
//  main.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import Foundation

var trace = false
var traceIndent = 0
func trace(_ items: Any..., terminator term: String = "") {
    if trace {
        for _ in 0..<traceIndent { print(" ", terminator: "")}
        items.forEach { print("\($0)", terminator: " ") }
        print(term)
    }
}

func parseGrammar(startSymbol: String) -> GrammarNode? {
    let inputFileURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
    //        .appendingPathComponent("TortureSyntax")
        .appendingPathComponent("test")
    //        .appendingPathComponent("apusNoAction")
        .appendingPathExtension("apus")
    
    initScanner(fromFile: inputFileURL, patterns: handwrittenTokenPatterns)
    
    initParser()
    
    _parseGrammar()
    
    trace("terminals:")
    for terminal in terminals {
        trace("\t", terminal.key, "\t", terminal.value)
    }
    
    trace("nonTerminals:")
    for nonTerminal in nonTerminals {
        trace("\t", nonTerminal.key, "\t", nonTerminal.value)
    }
    
    guard let root = nonTerminals[startSymbol] else {
        print("error: start symbol '\(startSymbol)' not found")
        return nil
    }
    
    root.follow.insert("")
    trace("start symbol '\(startSymbol)' first:", root.first, "follow:", root.follow)
    
    var oldSize = 0
    var newSize = 0
    repeat {
        oldSize = newSize
        newSize = 0
        for nt in nonTerminals {
            newSize += nt.value.populateFirstFollowSets()
        }
        trace("first & follow", newSize)
    } while newSize != oldSize
    
    trace = true
    for nonTerminal in nonTerminals.sorted(by: { $0.key < $1.key } ) {
        traceIndent = 0
        trace("RULE: '\(nonTerminal.key)'")
        nonTerminal.value.detectAmbiguity()
    }
    
    return root
    
}

var failedParses = 0
var successfullParses = 0
var addedDescriptors = 0

func parseMessage() {
    trace = true
    
    failedParses = 0
    successfullParses = 0
    
    let savedParseMode = parseMode

    enum ParseFailure: Error { case unexpectedToken, didNotReachEndOfInput }
    
//    while let slot = GSS.slot_L {
        while let slot = GSS.getDescriptor() {
//    while !GSS.todo_R.isEmpty {
//        GSS.slot_L = GSS.getDescriptor()!
        
        do {
            
//            repeat {
                
                trace("parse node",slot.kindName)
                
                if slot.testSelect(token) == false {
                    throw ParseFailure.unexpectedToken
                }
                
                // optimization do not create descriptors if only one path is possible
            if slot.ambiguous.contains(token.type) {
                print("\(#function) first and follow of node \(slot.description) contain \(token.type)")
                 parseMode = savedParseMode
            } else {
                print("\(#function) first and follow of node \(slot.description) do not contain \(token.type)")
                 parseMode = .LL1
            }
            
                switch slot.kind {
                    
                case .SEQ(let children):
                    for child in children.reversed() {
                        GSS.create(slot: child)
                    }
                    
                case .ALT(let children):
                    switch parseMode {
                    case .ALL:
                        for child in children {
                            let saved = GSS.stack_Cu
                            GSS.create(slot: child)
                            GSS.addDescriptor(slot: child, stack: saved)
                            GSS.stack_Cu = saved
                        }
                        
                    case .LL1:
                        for child in children {
                            if child.first.contains(token.type) {
                                GSS.create(slot: child)
                                break
                            }
                        }
                    case .GLL:
                        for child in children where child.first.contains(token.type) {
                            let saved = GSS.stack_Cu
                            GSS.create(slot: child)
                            GSS.addDescriptor(slot: child, stack: saved)
                            GSS.stack_Cu = saved
                        }
                    }
                    
                    if !slot.first.contains("") && parseMode != .LL1 {
                        print("ALT is not nullable")
                        throw ParseFailure.didNotReachEndOfInput
                    }
                    
                case .OPT(let child):
                    switch parseMode {
                    case .ALL:
                        let saved = GSS.stack_Cu
                        GSS.create(slot: child)
                        GSS.addDescriptor(slot: child, stack: saved)
                        GSS.stack_Cu = saved
                    case .LL1:
                        if child.first.contains(token.type) {
                            GSS.create(slot: child)
                        }
                    case .GLL:
                        if child.first.contains(token.type) {
                            let saved = GSS.stack_Cu
                            GSS.create(slot: child)
                            GSS.addDescriptor(slot: child, stack: saved)
                            GSS.stack_Cu = saved
                        }
                    }
                    
                case .REP(let child):
                    switch parseMode {
                    case .ALL:
                        let saved = GSS.stack_Cu
                        GSS.create(slot: slot)
                        let intermediate = GSS.stack_Cu
                        GSS.create(slot: child)
                        GSS.addDescriptor(slot: child, stack: intermediate)
                        GSS.stack_Cu = saved
                    case .LL1:
                        if child.first.contains(token.type) {
                            GSS.create(slot: slot)
                            GSS.create(slot: child)
                        }
                    case .GLL:
                        if child.first.contains(token.type) {
                            let saved = GSS.stack_Cu
                            GSS.create(slot: slot)
                            let intermediate = GSS.stack_Cu
                            GSS.create(slot: child)
                            GSS.addDescriptor(slot: child, stack: intermediate)
                            GSS.stack_Cu = saved
                        }
                    }
                    
                case .NTR(_, let link):
                    GSS.create(slot: link!)     // all nonterminal links have been resolved in func populateLookAheadSets
                    
                case .TRM(_):
                    slot.extents.insert(token.range)
                    print("add \(token.type) extent \(token.range)")
                    next()
                }
                
                if GSS.stack_Cu == nil {
                    if token.range.upperBound == input.endIndex {
                        successfullParses += 1
                        trace("HURRAH", terminator: "\n")
                    } else {
                        throw ParseFailure.didNotReachEndOfInput
                    }
                } else {
                    GSS.pop()
                }
                
//            } while GSS.stack_Cu != nil
            
        } catch let error {
            failedParses += 1
            trace("NOGOOD Parse ended due to \(error)", terminator: "\n")
        }
        
//        GSS.slot_L = GSS.getDescriptor()

    }
    
    trace(
        "\nmatched:", successfullParses,
        "  failed:", failedParses,
        "  gss size:", GSS.graph.count,
        "  descriptors:", addedDescriptors
    )
}

enum ParseMode { case ALL, LL1, GLL }
var parseMode = ParseMode.LL1
switch parseMode {
case .ALL:
    print("All paths")
case .LL1:
    print("Pure LL1")
case .GLL:
    print("General LL")
}

trace = false
let grammarRoot = parseGrammar(startSymbol: "S")

trace = false
var GSS = GraphStructuredStack()
//generateDiagrams()      // first time with empty GSS

if let grammarRoot {
    for m in messages {
        trace = false
        initScanner(fromString: m, patterns: terminals)
        
        //        grammarRoot.resetParseResults()
        
        GSS = GraphStructuredStack()
        
        trace = true
        GSS.create(slot: grammarRoot)
        GSS.addDescriptor(slot: grammarRoot, stack: nil)
        
        parseMessage()
    }
}

trace = false
generateParser()

trace = false
generateDiagrams()      // second time including actual GSS
