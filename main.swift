//
//  main.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import Foundation
import RegexBuilder

print("========== PROGRAM STARTED ==========")

// transform the APUS ('EBNF') grammar from the input file into a grammar tree ('Abstract Syntax Tree')
// by using grammarParser, which is a hand-built recursive descent parser
trace = false
print("DEBUG: About to load grammar file")
let grammarFileURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
//    .appendingPathComponent("apus")
//    .appendingPathComponent("Swift")
//    .appendingPathComponent("AfroozehHunt")
//    .appendingPathComponent("apusWithAction")
//    .appendingPathComponent("TortureSyntax")
    .appendingPathComponent("test")
//    .appendingPathComponent("tortureART")
//    .appendingPathComponent("apusAmbiguous")
    .appendingPathExtension("apus")

var grammarParser: GrammarParser
do {
    grammarParser = try GrammarParser(inputFile: grammarFileURL, patterns: apusTerminals)
} catch {
    print("file error: could not read from \(grammarFileURL.absoluteString)")
    exit(0)
}

startSymbol = ""    // if "" then startSymbol will be set by parseGrammar to the first nonTerminal in the grammar file
print("DEBUG: About to parse grammar")
let grammarRoot: GrammarNode
do {
    guard let root = try grammarParser.parseGrammar(explicitStartSymbol: startSymbol) else {
        print("parse error: Start symbol '\(startSymbol)' not found")
        exit(1)
    }
    grammarRoot = root
    print("DEBUG: Grammar parsed successfully, root = \(grammarRoot)")
} catch {
    print("parse error: Failed to parse grammar: \(error)")
    exit(1)
}

trace = false
trace("all grammar tokens:")
for t in tokens {
    trace(t)
}

// the GrammarNode being processed
var currentSlot = grammarRoot

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
print("DEBUG: messages.count = \(messages.count)")
for m in messages {
    print("DEBUG: processing message: '\(m)'")
    trace = false
    do {
        try initScanner(fromString: m, patterns: terminals)
    } catch {
        print("scan error: Failed to scan message: \(error)")
        continue
    }

    trace = true
    print("all message tokens:")
    for t in tokens {
        print("'\(t.image)' \(t)")
    }

    trace = false
    print("DEBUG: about to call resetMessageParser")
    resetMessageParser(root: grammarRoot)
    print("DEBUG: resetMessageParser completed")

    print("DEBUG: crfRoot.slot = \(crfRoot.slot)")
    print("DEBUG: crfRoot.slot.alt = \(String(describing: crfRoot.slot.alt))")
    print("DEBUG: crfRoot.slot.first = \(crfRoot.slot.first)")
    print("DEBUG: crfRoot.slot.follow = \(crfRoot.slot.follow)")

    // Add descriptors for the root's alternates
    addDescriptorsForAlternates(bracket: grammarRoot, cluster: crfRoot, index: 0)
    
    print("DEBUG: remainder count after addDescriptorsForAlternates = \(remainder.count)")
    
    // use the AST to parse the message
    let start = clock()
    parseMessage()
    let end = clock()
    let cpuTime = Double(end - start) / Double(CLOCKS_PER_SEC)
    print("cpuTime, descriptorCount, crf.count")
    print(cpuTime, descriptorCount, crf.count)
    
    for y in yields {
        print(y)
    }
}

if nonTerminals.count < 1000 && crf.count < 1000 {    // to avoid huge diagrams and parsers
    trace = false
    let generatedParserFile = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("output")
        .appendingPathExtension("swift")
    let parserGenerator = ParserGenerator(outputFile: generatedParserFile)
    do {
        try parserGenerator.generateParser()
    } catch {
        print("file error: could not write to \(generatedParserFile.absoluteString)")
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
        print("file error: could not write to \(generatedDiagramFile.absoluteString)")
        exit(6)
    }
}
