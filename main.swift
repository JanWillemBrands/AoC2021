//
//  main.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import OSLog
import Foundation
//import RegexBuilder
//import AdventMacros

trace = false

// transform the APUS EBNF grammar from the input file into a grammar tree (Abstract Syntax Tree)
// by using grammarParser, which is a hand-built recursive descent parser
// then use the grammar tree as an interpretor to parse a message.
// then generate a stand-alone parser

let grammarFileURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
//    .appendingPathComponent("apus")
    .appendingPathComponent("Swift")
//    .appendingPathComponent("AfroozehHunt")
//    .appendingPathComponent("apusWithAction")
//    .appendingPathComponent("TortureSyntax")
//    .appendingPathComponent("test")
//    .appendingPathComponent("silent")
//    .appendingPathComponent("tortureART")
//    .appendingPathComponent("tortureEBNF")
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
    
    for _ in 0..<1 {
        messageParser.parse(tokens: messageScanner.tokens)
    }
    
    let end = clock()
    let cpuTime = Double(end - start) / Double(CLOCKS_PER_SEC)
    Logger.ui.info("cpuTime: \(cpuTime)")
    print("cpuTime, descriptorCount, crf.count, sizeOfSets, yieldCount")
    print(cpuTime, messageParser.descriptorCount, messageParser.crf.count, GrammarNode.sizeofSets, messageParser.yield.count)
    print("descriptor size:", MemoryLayout<Descriptor>.size, "bytes")
    
//    print(cpuTime, messageParser.descriptorCount, messageParser.crf.count)
    
    // Sort elements (if BSR is Comparable) then join
//    let sortedOutput = messageParser.yield.map { "\($0)" }.sorted().joined(separator: "\n")
//    Logger.parse.debug("\(sortedOutput)")

//    trace = false
//    for y in messageParser.yield {
//        #Trace(y)
//        Logger.parse.debug("\(y)")
//    }

    
    
#if DEBUG
    trace = false
    
    if grammar.nonTerminals.count < 1000 && messageParser.crf.count < 1000 {    // to avoid huge diagrams and parsers
        
        // MARK: - Generate New Parser
        
        let parserFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("GeneratedParser")
            .appendingPathComponent(grammar.startSymbol + "_parser")
            .appendingPathExtension("swift")
        Logger.ui.info("LL1 is \(grammar.isLL1)")
//        #Trace("LL1 is", grammar.isLL1)
        if grammar.isLL1 {
            let parserGenerator = ParserGenerator(outputFile: parserFile, grammar: grammar)
            try parserGenerator.generate()
            Logger.ui.info( "LL1 recursive descent parser written to \(parserFile.lastPathComponent)")
        }

        // MARK: - Generate CRF and AST diagrams
        
        let diagramFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("ART")
            .appendingPathExtension("gv")
        let diagramGenerator = ASTDiagramGenerator(outputFile: diagramFile, grammar: grammar, messageParser: messageParser)
        try diagramGenerator.generate()
        Logger.ui.info( "AST diagram written to \(diagramFile.lastPathComponent)")

        // MARK: - SPPF and Derivation Diagrams
        let sppfExtractor = SPPFExtractor(grammar: grammar, tokens: messageScanner.tokens)
        
        if let sppfRoot = sppfExtractor.extractSPPF() {
            let sppfFile = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("SPPF")
                .appendingPathExtension("gv")
            try generateSPPFDiagram(outputFile: sppfFile, root: sppfRoot)
            Logger.ui.info( "SPPF diagram written to \(sppfFile.lastPathComponent)")
//            #Trace("SPPF diagram written to \(sppfFile.lastPathComponent)")
            
        } else {
            Logger.ui.warning( "SPPF: no parse tree to extract")
//            #Trace("\nSPPF: no parse tree to extract")
        }
        
        let derivFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Derivations")
            .appendingPathExtension("gv")
        try generateDerivationDiagram(outputFile: derivFile, grammar: grammar, tokens: messageScanner.tokens)
        Logger.ui.info( "🟢 Derivation diagram written to \(derivFile.lastPathComponent)")
//        #Trace("Derivation diagram written to \(derivFile.lastPathComponent)")
    }
#endif

    Logger.ui.debug("first/follow set size: \(GrammarNode.sizeofSets) terminals.count: \(grammar.terminals.count) nonTerminals.count: \(grammar.nonTerminals.count)")
    
}
