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

var apusParser = try ApusParser(fromFile: grammarFileURL)

print("DEBUG: About to parse grammar")
let grammar: Grammar
do {
    guard let g = try apusParser.parseGrammar(explicitStartSymbol: "") else {
        print("parse error: Start symbol not found")
        exit(1)
    }
    grammar = g
    print("DEBUG: Grammar parsed successfully, root = \(grammar.root)")
} catch {
    print("parse error: Failed to parse grammar: \(error)")
    exit(1)
}

trace = false
trace("all grammar tokens:")
for t in tokens {
    trace(t)
}


//while let m = messages.first {
print("DEBUG: messages.count = \(grammar.messages.count)")
for m in grammar.messages {
    print("DEBUG: processing message: '\(m)'")
    trace = false
    let messageScanner: Scanner
    do {
        messageScanner = try Scanner(fromString: m, patterns: grammar.terminals)
    } catch {
        print("scan error: Failed to scan message: \(error)")
        continue
    }
    tokens = messageScanner.tokens
    cI = 0

    trace = true
    print("all message tokens:")
    for t in tokens {
        print("'\(t.image)' \(t)")
    }

    trace = false
    print("DEBUG: about to call resetMessageParser")
    resetMessageParser(root: grammar.root)
    print("DEBUG: resetMessageParser completed")

    print("DEBUG: grammarRoot.alt = \(String(describing: grammar.root.alt))")
    print("DEBUG: grammarRoot.first = \(grammar.root.first)")
    print("DEBUG: grammarRoot.follow = \(grammar.root.follow)")

    // Paper: ntAdd — add descriptors for the root's alternates
    ntAdd(X: grammar.root, k: 0, i: 0)
    
    print("DEBUG: R count after ntAdd = \(remaining.count)")
    
    // use the AST to parse the message
    let start = clock()
    
    parseMessage()
    
    let end = clock()
    let cpuTime = Double(end - start) / Double(CLOCKS_PER_SEC)
    print("cpuTime, descriptorCount, crf.count")
    print(cpuTime, descriptorCount, crf.count)
    
    for y in yield {
        print(y)
    }
    
    // Extract SPPF from BSR set
    let inputExtent = tokens.count - 1  // exclude EOS
    if let sppfRoot = extractSPPF(startSymbol: grammar.root, extent: inputExtent, nonTerminals: grammar.nonTerminals) {
        print("\nSPPF extracted: \(sppfAllNodes.count) nodes")
        
        let sppfDiagramFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("SPPF")
            .appendingPathExtension("gv")
        do {
            try generateSPPFDiagram(root: sppfRoot, to: sppfDiagramFile)
            print("SPPF diagram written to \(sppfDiagramFile.lastPathComponent)")
        } catch {
            print("file error: could not write SPPF diagram: \(error)")
        }
    } else {
        print("\nSPPF: no parse tree to extract")
    }
}

if grammar.nonTerminals.count < 1000 && crf.count < 1000 {    // to avoid huge diagrams and parsers
    trace = false
    let generatedParserFile = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("output")
        .appendingPathExtension("swift")
    let parserGenerator = ParserGenerator(outputFile: generatedParserFile, grammar: grammar)
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
    let diagramsGenerator = DiagramsGenerator(outputFile: generatedDiagramFile, grammar: grammar)
    do {
        try diagramsGenerator.generateDiagrams()
    } catch {
        print("file error: could not write to \(generatedDiagramFile.absoluteString)")
        exit(6)
    }
}
