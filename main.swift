//
//  main.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import Foundation

var trace = true
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
//        .appendingPathComponent("apus")
//        .appendingPathComponent("apusNoAction")
    //        .appendingPathComponent("apusAmbiguous")
        .appendingPathExtension("apus")
    
    initScanner(fromFile: inputFileURL, patterns: apusTerminals)
    
    initParser()
    
    parseApusGrammar()
    
    // NEW ART
    currentIndex = 0
    print(token)
    _initParser()
    _parseApusGrammar()
    
    trace("_terminals:")
    for (name, tokenPattern) in _terminals {
        trace("\t", name, "\t", tokenPattern.source)
    }
    trace("_nonTerminals:")
    for (name, node) in _nonTerminals {
        trace("\t", name, "\t", node.kind)
    }
    guard let root = _nonTerminals[startSymbol] else { return nil }
    
    root.follow.insert("")
    trace("_start symbol '\(startSymbol)' first:", root.first, "follow:", root.follow)
    
    var _oldSize = 0
    var _newSize = 0
    repeat {
        _oldSize = _newSize
        _newSize = 0
        for nt in _nonTerminals {
            GNode.sizeofSets = 0
            nt.value.__populateFirstFollowSets()
            _newSize = GNode.sizeofSets
//            _newSize += nt.value._populateFirstFollowSets()
        }
        trace("first & follow", _newSize)
    } while _newSize != _oldSize
    

    for (_, node) in _nonTerminals {
        node.detectAmbiguity()
    }
    _generateDiagrams()
    // NEW ART

    currentIndex = 0
    trace("terminals:")
    for (name, tokenPattern) in terminals {
        trace("\t", name, "\t", tokenPattern.source)
    }
    
    trace("nonTerminals:")
    for (name, grammarNode) in nonTerminals {
        trace("\t", name, "\t", grammarNode.kind)
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

//testNewScanner()

enum ParseFailure: Error { case unexpectedToken, didNotReachEndOfInput }

// transform the APUS ('EBNF') grammar from the input file into a grammar tree ('Abstract Syntax Tree')
// this uses a handbuilt recursive descent parser
let startSymbol = "S"
guard let grammarRoot = parseGrammar(startSymbol: startSymbol) else {
    print("error: Start Symbol '\(startSymbol)' not found")
    exit(1)
}

// the GrammarNode being processed
var currentSlot = grammarRoot

// the top of one of the stacks in the Graph Structured Stack
var currentStack = Vertex(slot: currentSlot, index: currentIndex)

//addDescriptor(slot: currentSlot, stack: currentStack, index: currentIndex)

var isAmbiguous = true
var failedParses = 0
var successfullParses = 0
var addedDescriptors = 0

for m in messages {
    trace = true
    initScanner(fromString: m, patterns: terminals)
    // TODO: reset parser after every message     grammarRoot.resetParseResults()
    // TODO: set startSymbol depending on the message
    
    currentSlot = grammarRoot
    currentStack = Vertex(slot: currentSlot, index: currentIndex)
    addDescriptor(slot: currentSlot, stack: currentStack, index: currentIndex)

    trace = true
    failedParses = 0
    successfullParses = 0
    addedDescriptors = 0
    
    // use the AST to parse the message
    parseMessage()
}

trace = false
generateParser()

trace = false
generateDiagrams()

func parseMessage() {
    
    while !remainder.isEmpty {
        let d = remainder.removeLast()
        trace("get Descriptor(slot: \(d.slot.description), stack: \(d.stack.description), index: \(d.index))")
        currentStack = d.stack
//        currentIndex(to: d.index)
        currentIndex = d.index
//        token = tokens[currentIndex]
//        next()
        currentSlot = d.slot
        
        do {
            
            trace("parse node", currentSlot.kindName)
            
            if currentSlot.isExpecting(token) == false {
                throw ParseFailure.unexpectedToken
            }
            
            // switch to .LL1 mode if only one single path is possible
            isAmbiguous = currentSlot.ambiguous.contains(token.kind)
            
            switch currentSlot.kind {
                
            case .SEQ(let children):
                for child in children.reversed() {
                    create(slot: child)
                }
                // TODO: something to gather all the extents of its children
                
            case .ALT(let children):
                for child in children where child.first.contains(token.kind) {
                    if isAmbiguous {
                        let saved = currentStack
                        create(slot: child)
                        addDescriptor(slot: child, stack: saved, index: currentIndex)
                        currentStack = saved
                    } else {
                        create(slot: child)
                        break
                    }
                }
                
            case .OPT(let child):
                if child.first.contains(token.kind) {
                    if isAmbiguous {
                        let saved = currentStack
                        create(slot: child)
                        addDescriptor(slot: child, stack: saved, index: currentIndex)
                        currentStack = saved
                    } else {
                        create(slot: child)
                    }
                }

           case .REP(let child):
                if child.first.contains(token.kind) {
                    if isAmbiguous {
                        let saved = currentStack
                        create(slot: currentSlot)
                        let intermediate = currentStack
                        create(slot: child)
                        addDescriptor(slot: child, stack: intermediate, index: currentIndex)
                        currentStack = saved
                    } else {
                        create(slot: currentSlot)
                        create(slot: child)
                    }
                }
                
            case .NTR(_, let link):
                create(slot: link!)     // all nonterminal links have been resolved in func populateLookAheadSets
                
            case .TRM(_):
                currentSlot.yield.insert(Split(token.range.lowerBound, token.range.lowerBound, token.range.upperBound))
                next() 
            }
            
            // TODO: update success criteria
            if token.range.upperBound == input.endIndex {
                successfullParses += 1
                trace("HURRAH", terminator: "\n")
            }
             
            pop()
            
        } catch let error {
            failedParses += 1
            trace("NOGOOD Parse ended due to \(error)", terminator: "\n")
        }
    }
    
    trace(
        "\nmatched:", successfullParses,
        "  failed:", failedParses,
        "  gss size:", graph.count,
        "  descriptors:", addedDescriptors
    )
}

