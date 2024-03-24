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
    //        .appendingPathComponent("apusAmbiguous")
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
    
    guard let root = nonTerminals[startSymbol] else { return nil }
    
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

enum ParseFailure: Error { case unexpectedToken, didNotReachEndOfInput }

enum ParseMode { case ALL, LL1, GLL }
var parseMode = ParseMode.GLL
switch parseMode {
case .ALL:
    print("All paths")
case .LL1:
    print("Pure LL1")
case .GLL:
    print("General LL")
}

// transform the APUS ('EBNF') grammar from the input file into a grammar tree ('Abstract Syntax Tree')
// this uses a handbuilt recursive descent parser
let startSymbol = "S"
guard let grammarRoot = parseGrammar(startSymbol: startSymbol) else {
    trace("ERROR: Start Symbol '\(startSymbol)' not found")
    exit(5)
}

// the first character of the current token
var currentIndex = input.startIndex

// the GrammarNode being processed
var currentSlot = grammarRoot

// the top of one of the stacks in the Graph Structured Stack
var currentStack = Vertex(slot: currentSlot, index: currentIndex)

trace = false
addDescriptor(slot: currentSlot, stack: &currentStack, at: currentIndex)

trace = false
for m in messages {
    trace = false
    initScanner(fromString: m, patterns: terminals)
    
    //        grammarRoot.resetParseResults()
    // TODO: set startSymbol depending on the message
    
    trace = true
    // use the AST to parse the message in LL1, GLL or ALL mode
    parseMessage()
}

trace = false
generateParser()

trace = false
generateDiagrams()      // second time including actual GSS

var failedParses = 0
var successfullParses = 0
var addedDescriptors = 0

func parseMessage() {
    trace = true
    
    failedParses = 0
    successfullParses = 0
    
    let savedParseMode = parseMode
    
    //    while let slot = slot_L {
    //    while let slot_L = getDescriptor() {
    while !remainder.isEmpty {
        currentSlot = getDescriptor()
        
        do {
            
            //            repeat {
            
            trace("parse node",currentSlot.kindName)
            
            if currentSlot.testSelect(token) == false {
                throw ParseFailure.unexpectedToken
            }
            
            // OPTIMIZATION do not create descriptors if only one path is possible
            if currentSlot.ambiguous.contains(token.type) {
                print("node \(currentSlot.description) is not LL1 for \"\(token.type)\"")
                parseMode = savedParseMode
            } else {
                print("node \(currentSlot.description) is LL1 for \"\(token.type)\"")
                parseMode = .LL1
            }
            
            switch currentSlot.kind {
                
            case .SEQ(let children):
                for child in children.reversed() {
                    create(slot: child)
                }
                
            case .ALT(let children):
                switch parseMode {
                case .ALL:
                    for child in children {
                        var saved = currentStack
                        create(slot: child)
                        addDescriptor(slot: child, stack: &saved)
                        currentStack = saved
                    }
                    
                case .LL1:
                    for child in children {
                        if child.first.contains(token.type) {
                            create(slot: child)
                            break
                        }
                    }
                case .GLL:
                    for child in children where child.first.contains(token.type) {
                        var saved = currentStack
                        create(slot: child)
                        addDescriptor(slot: child, stack: &saved)
                        currentStack = saved
                    }
                }
                
                if !currentSlot.first.contains("") && parseMode != .LL1 {
                    print("ALT is not nullable")
                    throw ParseFailure.didNotReachEndOfInput
                }
                
            case .OPT(let child):
                switch parseMode {
                case .ALL:
                    var saved = currentStack
                    create(slot: child)
                    addDescriptor(slot: child, stack: &saved)
                    currentStack = saved
                case .LL1:
                    if child.first.contains(token.type) {
                        create(slot: child)
                    }
                case .GLL:
                    if child.first.contains(token.type) {
                        var saved = currentStack
                        create(slot: child)
                        addDescriptor(slot: child, stack: &saved)
                        currentStack = saved
                    }
                }
                
            case .REP(let child):
                switch parseMode {
                case .ALL:
                    let saved = currentStack
                    create(slot: currentSlot)
                    var intermediate = currentStack
                    create(slot: child)
                    addDescriptor(slot: child, stack: &intermediate)
                    currentStack = saved
                case .LL1:
                    if child.first.contains(token.type) {
                        create(slot: currentSlot)
                        create(slot: child)
                    }
                case .GLL:
                    if child.first.contains(token.type) {
                        let saved = currentStack
                        create(slot: currentSlot)
                        var intermediate = currentStack
                        create(slot: child)
                        addDescriptor(slot: child, stack: &intermediate)
                        currentStack = saved
                    }
                }
                
            case .NTR(_, let link):
                create(slot: link!)     // all nonterminal links have been resolved in func populateLookAheadSets
                
            case .TRM(_):
                currentSlot.extents.insert(token.range)
                print("add \(token.type) extent \(token.range.shortDescription)")
                next()
            }
            
            if currentStack == nil {
                if token.range.upperBound == input.endIndex {
                    successfullParses += 1
                    trace("HURRAH", terminator: "\n")
                } else {
                    throw ParseFailure.didNotReachEndOfInput
                }
            } else {
                pop()
            }
            
            //            } while stack_Cu != nil
            
        } catch let error {
            failedParses += 1
            trace("NOGOOD Parse ended due to \(error)", terminator: "\n")
        }
        
        //        slot_L = getDescriptor()
        
    }
    
    trace(
        "\nmatched:", successfullParses,
        "  failed:", failedParses,
        "  gss size:", graph.count,
        "  descriptors:", addedDescriptors
    )
}

