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
//    .appendingPathComponent("test")
    .appendingPathComponent("Swift")
//    .appendingPathComponent("apusNoActionKLN")
//    .appendingPathComponent("TortureSyntax")
//    .appendingPathComponent("apus")
//    .appendingPathComponent("tortureART")
//    .appendingPathComponent("apusAmbiguous")
    .appendingPathExtension("apus")

var grammarParser: GrammarParser
do {
    grammarParser = try GrammarParser(inputFile: grammarFileURL, patterns: apusTerminals)
} catch {
    print("error: could not read from \(grammarFileURL.absoluteString)")
    exit(0)
}

var startSymbol = ""    // if "" then startSymbol will set set by parseGrammar to the first nonTerminal in the grammar file
let grammarRoot: GrammarNode
guard let root = grammarParser.parseGrammar(explicitStartSymbol: startSymbol) else {
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
var duplicateDescriptorCount = 0

//let a = input.lineRange(for: token.image.startIndex ..< token.image.endIndex)
//let b = token.image.startIndex ..< token.image.endIndex
//let y = 1
//let x = y as? Int
//let t = 0 ... 10
/*
@available(*, unavailable, renamed: "test")
func test() {}
let r = /\/[^\s](?:(?:[^\/\\\s]|\\.)*[^\s])?\//
let e = #/
    \/              # Match the opening forward slash
    [^\s]           # First character must not be whitespace (ensures at least one character)
    (?:
      (?:           # Non-capturing group for middle content
        [^\/\\\s]   # Any character except slash, backslash, or whitespace
        |           # OR
        \\.         # An escaped character (e.g., \. or \/)
      )*            # Zero or more of the above
      [^\s]         # Last character before closing slash must not be whitespace
    )?              # Entire middle-and-last group is optional (allows just one character)
    \/              # Match the closing forward slash
/#
 */



//while let m = messages.first {
for m in messages {
    trace = false
    initScanner(fromString: m, patterns: terminals)

    trace = true
    print("all message tokens:")
    for t in tokens {
        print("'\(t.image)' \(t)")
    }

    trace = false
    resetMessageParser()

    currentSlot = grammarRoot
    currentStack = gssRoot

    addDescriptor(slot: grammarRoot.alt!, stack: currentStack, index: currentIndex)
    
    // use the AST to parse the message
    let start = clock()
    parseMessage()
    let end = clock()
    let cpuTime = Double(end - start) / Double(CLOCKS_PER_SEC)
    print("cpuTime, descriptorCount, gss.count")
    print(cpuTime, descriptorCount, gss.count)
    print(immediateMatch, subsequentMatch, ultimateFail)

}

if nonTerminals.count < 1000 && gss.count < 1000 {    // to avoid huge diagrams and parsers
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
}
