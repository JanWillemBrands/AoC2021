//
//  main.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import Foundation

// transform the APUS ('EBNF') grammar from the input file into a grammar tree ('Abstract Syntax Tree')
// by using grammarParser, which is a hand-built recursive descent parser
trace = false
let grammarFileURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
//        .appendingPathComponent("test")
//        .appendingPathComponent("apusNoAction")
//        .appendingPathComponent("TortureSyntax")
//    .appendingPathComponent("apus")
    .appendingPathComponent("tortureART")
//        .appendingPathComponent("apusAmbiguous")
    .appendingPathExtension("apus")

var grammarParser: GrammarParser
do {
    grammarParser = try GrammarParser(inputFile: grammarFileURL, patterns: apusTerminals)
} catch {
    print("error: could not read from \(grammarFileURL.absoluteString)")
    exit(0)
}

let startSymbol = "S"
let grammarRoot: GrammarNode
guard let root = grammarParser.parseGrammar(startSymbol: startSymbol) else {
    print("Error: Start symbol '\(startSymbol)' not found")
    exit(1)
}
grammarRoot = root

trace = false
trace("all grammar tokens:")
for t in tokens {
    trace(t)
}

// the GrammarNode being processed
var currentSlot = grammarRoot

// the top of one of the stacks in the Graph Structured Stack
var currentStack = gssRoot

var failedParses = 0
var successfullParses = 0
var descriptorCount = 0

for m in messages {
    trace = false
    initScanner(fromString: m, patterns: terminals)

    trace("all message tokens:")
    for t in tokens {
        trace(t)
    }

    trace = true
    resetMessageParser()
    // TODO: set startSymbol depending on the message
    currentSlot = grammarRoot
    currentStack = gssRoot

    addDescriptor(slot: grammarRoot.alt!, stack: currentStack, index: currentIndex)

    // use the AST to parse the message
    let start = clock()
    try parseMessage()
    let end = clock()
    let cpuTime = Double(end - start) / Double(CLOCKS_PER_SEC)
    print(cpuTime, descriptorCount)
//    print("CPU time: \(cpuTime) seconds")
}

#if DEBUG
trace = false
let generatedParserFile = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("output")
    .appendingPathExtension("swift")
let parserGenerator = ParserGenerator(outputFile: generatedParserFile)
do {
    try parserGenerator.generateParser()
} catch {
    print("error: could not write to \(generatedParserFile.absoluteString)")
    exit(5)
}


trace = false
let generatedDiagramFile = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("ART")
    .appendingPathExtension("gv")
let diagramsGenerator = DiagramsGenerator(outputFile: generatedDiagramFile)
do {
    try diagramsGenerator.generateDiagrams()
} catch {
    print("error: could not write to \(generatedDiagramFile.absoluteString)")
    exit(6)
}
#endif
