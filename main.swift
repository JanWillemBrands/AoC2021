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
    .appendingPathComponent("test")
//    .appendingPathComponent("tortureART")
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
        print(y)
    }
    
    
    
    trace = false
    
    if grammar.nonTerminals.count < 1000 && messageParser.crf.count < 1000 {    // to avoid huge diagrams and parsers
        
        // MARK: - Generate New Parser
        
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
        
        // MARK: - Generate CRF and AST diagrams
        
        let generatedDiagramFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("ART")
            .appendingPathExtension("gv")
        let diagramsGenerator = DiagramsGenerator(outputFile: generatedDiagramFile, grammar: grammar, messageParser: messageParser)
        do {
            try diagramsGenerator.generateDiagrams()
        } catch {
            print("file error: could not write to \(generatedDiagramFile.absoluteString)")
            exit(6)
        }
        
        // MARK: - Extract SPPF from BSR set
        let inputExtent = messageParser.tokens.count - 1  // exclude EOS
        if let sppfRoot = messageParser.extractSPPF(startSymbol: grammar.root, extent: inputExtent, nonTerminals: grammar.nonTerminals) {
            print("\nSPPF extracted: \(messageParser.sppfAllNodes.count) nodes")
            
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
}
