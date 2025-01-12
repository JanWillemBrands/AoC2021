//
//  main.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import Foundation

// NEW ART
// transform the APUS ('EBNF') grammar from the input file into a grammar tree ('Abstract Syntax Tree')
// by using parseGrammar, which is a hand-built recursive descent parser
trace = false
let _startSymbol = "S"
guard let _grammarRoot = _parseGrammar(startSymbol: _startSymbol) else {
    print("error: Start Symbol '\(_startSymbol)' not found")
    exit(1)
}

// the GrammarNode being processed
var _currentSlot = _grammarRoot

// the top of one of the stacks in the Graph Structured Stack
var _currentStack = _Vertex(slot: _currentSlot, index: _currentIndex)

//addDescriptor(slot: currentSlot, stack: currentStack, index: currentIndex)

//var isAmbiguous = true

var _failedParses = 0
var _successfullParses = 0
var _addedDescriptors = 0


for m in _messages {
    trace = true
    initScanner(fromString: m, patterns: _terminals)
    // TODO: reset parser after every message     grammarRoot.resetParseResults()
    // TODO: set startSymbol depending on the message
    
    _currentSlot = _grammarRoot
    _currentStack = _Vertex(slot: _currentSlot, index: _currentIndex)
    _addDescriptor(slot: _currentSlot, stack: _currentStack, index: _currentIndex)

    trace = true
    _failedParses = 0
    _successfullParses = 0
    _addedDescriptors = 0
    
    // use the AST to parse the message
    try _parseMessage()
}

//_generateParser()
trace = false
let parserFile = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("output")
    .appendingPathExtension("swift")
let parserGenerator = ParserGenerator(outputFile: parserFile)
do {
    try parserGenerator.generateParser()
} catch {
    print("error: could not write to \(parserFile.absoluteString)")
    exit(5)
}

//_generateDiagrams()
trace = false
let diagramFile = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("ART")
    .appendingPathExtension("gv")
let diagramsGenerator = DiagramsGenerator(outputFile: diagramFile)
do {
    try diagramsGenerator.generateDiagrams()
} catch {
    print("error: could not write to \(diagramFile.absoluteString)")
    exit(6)
}

// NEW ART


//// transform the APUS ('EBNF') grammar from the input file into a grammar tree ('Abstract Syntax Tree')
//// ParseGrammar is a handbuilt recursive descent parser
//let startSymbol = "S"
//guard let grammarRoot = parseGrammar(startSymbol: startSymbol) else {
//    print("error: Start Symbol '\(startSymbol)' not found")
//    exit(1)
//}
//
//// the GrammarNode being processed
//var currentSlot = grammarRoot
//
//// the top of one of the stacks in the Graph Structured Stack
//var currentStack = Vertex(slot: currentSlot, index: currentIndex)
//
////addDescriptor(slot: currentSlot, stack: currentStack, index: currentIndex)
//
//var isAmbiguous = true
//var failedParses = 0
//var successfullParses = 0
//var addedDescriptors = 0
//
//for m in messages {
//    trace = true
//    initScanner(fromString: m, patterns: terminals)
//    // TODO: reset parser after every message     grammarRoot.resetParseResults()
//    // TODO: set startSymbol depending on the message
//    
//    currentSlot = grammarRoot
//    currentStack = Vertex(slot: currentSlot, index: currentIndex)
//    addDescriptor(slot: currentSlot, stack: currentStack, index: currentIndex)
//
//    trace = true
//    failedParses = 0
//    successfullParses = 0
//    addedDescriptors = 0
//    
//    // use the AST to parse the message
//    parseMessage()
//}
//
//trace = false
//generateParser()
//
//trace = false
//generateDiagrams()
//// BEFORE ART
