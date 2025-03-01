//
//  main.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import Foundation

trace = true

// transform the APUS ('EBNF') grammar from the input file into a grammar tree ('Abstract Syntax Tree')
// by using parseGrammar, which is a hand-built recursive descent parser
let startSymbol = "S"
guard let grammarRoot = parseGrammar(startSymbol: startSymbol) else {
    print("error: Start Symbol '\(startSymbol)' not found")
    exit(1)
}

trace = true
trace("all grammar tokens:")
for t in tokens {
    trace(t)
}
//trace = false

// the GrammarNode being processed
var currentSlot = grammarRoot

// the top of one of the stacks in the Graph Structured Stack
var currentStack = gssRoot

//addDescriptor(slot: currentSlot, stack: currentStack, index: currentIndex)

//var isAmbiguous = true

var failedParses = 0
var successfullParses = 0
var descriptorCount = 0


for m in messages {
    trace = true
    initScanner(fromString: m, patterns: terminals)
    // TODO: reset parser after every message     grammarRoot.resetParseResults()
    // TODO: set startSymbol depending on the message

    trace("all message tokens:")
    for t in tokens {
        trace(t)
    }

    trace = true
    failedParses = 0
    successfullParses = 0
    descriptorCount = 0
    
    currentSlot = grammarRoot
    currentStack = gssRoot

    addDescriptor(slot: grammarRoot.alt!, stack: currentStack, index: index)

    // use the AST to parse the message
    try parseMessage()
}

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
