//
//  main.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import Foundation
import RegexBuilder

// transform the APUS EBNF grammar from the input file into a grammar tree (Abstract Syntax Tree)
// by using grammarParser, which is a hand-built recursive descent parser

let grammarFileURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
//    .appendingPathComponent("apus")
//    .appendingPathComponent("Swift")
//    .appendingPathComponent("AfroozehHunt")
//    .appendingPathComponent("apusWithAction")
//    .appendingPathComponent("TortureSyntax")
//    .appendingPathComponent("test")
    .appendingPathComponent("tortureART")
//    .appendingPathComponent("apusAmbiguous")
    .appendingPathExtension("apus")

let apusParser = try ApusParser(fromFile: grammarFileURL)

let grammar = try apusParser.parse(explicitStartSymbol: "")

let messageParser = MessageParser(grammar: grammar)

for m in grammar.messages {
    let messageScanner: Scanner
    do {
        messageScanner = try Scanner(fromString: m, patterns: grammar.terminals)
    } catch {
        continue
    }
    
    // use the AST to parse the message
    let start = clock()
    
    messageParser.parse(tokens: messageScanner.tokens)
    
    let end = clock()
    let cpuTime = Double(end - start) / Double(CLOCKS_PER_SEC)
    print("cpuTime, descriptorCount, crf.count")
    print(cpuTime, messageParser.descriptorCount, messageParser.crf.count)
    
    for y in messageParser.yield {
        trace(y)
    }
    
    
#if DEBUG
    trace = false
    
    if grammar.nonTerminals.count < 1000 && messageParser.crf.count < 1000 {    // to avoid huge diagrams and parsers
        
        // MARK: - Generate New Parser
        
        let parserFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("output")
            .appendingPathExtension("swift")
        let parserGenerator = ParserGenerator(outputFile: parserFile, grammar: grammar)
        try parserGenerator.generate()
        
        // MARK: - Generate CRF and AST diagrams
        
        let diagramFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("ART")
            .appendingPathExtension("gv")
        let diagramGenerator = ASTDiagramGenerator(outputFile: diagramFile, grammar: grammar, messageParser: messageParser)
        try diagramGenerator.generate()
        
        // MARK: - Extract SPPF from BSR set
        if let sppfRoot = messageParser.extractSPPF() {
            let sppfFile = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("SPPF")
                .appendingPathExtension("gv")
            try generateSPPFDiagram(outputFile: sppfFile, root: sppfRoot)
            trace("SPPF diagram written to \(sppfFile.lastPathComponent)")
        } else {
            trace("\nSPPF: no parse tree to extract")
        }
    }
#endif
    
}
