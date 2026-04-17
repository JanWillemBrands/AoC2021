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

//import ArgumentParser
//@main
//struct Repeat: ParsableCommand {
//  @Argument(help: "The phrase to repeat.")
//  var phrase: String
//
//  @Option(help: "The number of times to repeat 'phrase'.")
//  var count: Int? = nil
//
//  mutating func run() throws {
//    let repeatCount = count ?? .max
//
//    for i in 1...repeatCount {
//      print(phrase)
//    }
//  }
//}

//func run() {

trace = false

// transform the APUS EBNF grammar from the input file into a grammar tree (Abstract Syntax Tree)
// by using grammarParser, which is a hand-built recursive descent parser
// then use the grammar tree as an interpretor to parse a message.
// then generate a stand-alone parser

let grammarFileURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
//    .appendingPathComponent("apus")
//    .appendingPathComponent("ScanModeTest")
//    .appendingPathComponent("Swift")
//    .appendingPathComponent("CommentTest")
//    .appendingPathComponent("attributeHunt")
//    .appendingPathComponent("AfroozehHunt")
//    .appendingPathComponent("apusWithAction")
//    .appendingPathComponent("TortureSyntax")
    .appendingPathComponent("test")
//    .appendingPathComponent("silent")
//    .appendingPathComponent("tortureART")
//    .appendingPathComponent("tortureEBNF")
//    .appendingPathComponent("apusAmbiguous")
    .appendingPathExtension("apus")

let grammar: Grammar
do {
    let apusParser = try ApusParser(fromFile: grammarFileURL)
    do {
        grammar = try apusParser.parse(explicitStartSymbol: "")
    } catch {
        Logger.ui.error("failed to parse grammar: \(grammarFileURL), error: \(error)")
        exit(1)
    }
} catch {
    Logger.ui.error("failed to scan grammar: \(grammarFileURL), error: \(error)")
    exit(1)
}

let messageParser = MessageParser(grammar: grammar)

for message in grammar.messages {
    let messageScanner: Scanner
    do {
        if message.hasPrefix("#") {
            let fileName = message.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            let messageFileURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent(fileName)
            let fileMessage = try String(contentsOf: messageFileURL, encoding: .utf8)
            messageScanner = try Scanner(fromString: fileMessage, patterns: grammar.terminals)
        } else {
            messageScanner = try Scanner(fromString: message, patterns: grammar.terminals)
        }
    } catch {
        Logger.ui.error("failed to scan message: \(message.prefix(100))...")
        continue
    }
    
    // use the AST to parse the message
    let start = clock()
    
    for _ in 0..<1 {
        messageParser.parse(tokens: messageScanner.tokens)
    }
    
    let end = clock()
    let cpuTime = Double(end - start) / Double(CLOCKS_PER_SEC)
    var stats = "cpuTime, descriptorCount, crf.count, sizeOfSets, yieldCount\n"
    stats += "\(cpuTime), \(messageParser.descriptorCount), \(messageParser.crf.count), \(GrammarNode.sizeofSets), \(messageParser.yield.count)\n"
    stats += "descriptor size: \(MemoryLayout<Descriptor>.size) bytes"
    Logger.ui.info("\(stats)")
    print("all tokens:")
    for t in messageScanner.tokens {
        print(t, "image", t.image)
    }
    //    print("tokensPatterns:")
    //    for tp in grammar.terminals {
    //        print(tp.key, tp.value.source)
    //    }
    
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
    var info = ""
    
    if grammar.nonTerminals.count < 1000 && messageParser.crf.count < 1000 {    // to avoid huge diagrams and parsers
        
        // MARK: - Generate New Parser
        
        let parserFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("GeneratedParser")
            .appendingPathComponent(grammar.startSymbol + "_parser")
            .appendingPathExtension("swift")
        info += "LL1 is \(grammar.isLL1)\n"
        //        Logger.ui.info("LL1 is \(grammar.isLL1)")
        //        #Trace("LL1 is", grammar.isLL1)
        if grammar.isLL1 {
            let parserGenerator = ParserGenerator(outputFile: parserFile, grammar: grammar)
            try parserGenerator.generate()
            info += "LL1 recursive descent parser written to \(parserFile.lastPathComponent)\n"
            //            Logger.ui.info( "LL1 recursive descent parser written to \(parserFile.lastPathComponent)")
        }
        
        // MARK: - Generate CRF and AST diagrams
        
        let diagramFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("ART")
            .appendingPathExtension("gv")
        let diagramGenerator = ASTDiagramGenerator(outputFile: diagramFile, grammar: grammar, messageParser: messageParser)
        try diagramGenerator.generate()
        info += "AST diagram written to \(diagramFile.lastPathComponent)\n"
        //        Logger.ui.info( "AST diagram written to \(diagramFile.lastPathComponent)")
    }
    
    // MARK: - Generate SPPF Diagram
    let sppfExtractor = SPPFExtractor(grammar: grammar, tokens: messageScanner.tokens)
    
    if let sppfRoot = sppfExtractor.extractSPPF() {
        let sppfFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("SPPF")
            .appendingPathExtension("gv")
        try generateSPPFDiagram(outputFile: sppfFile, root: sppfRoot)
        info += "SPPF diagram written to \(sppfFile.lastPathComponent)\n"
        //            Logger.ui.info( "SPPF diagram written to \(sppfFile.lastPathComponent)")
        //            #Trace("SPPF diagram written to \(sppfFile.lastPathComponent)")
        
    } else {
        Logger.ui.warning( "SPPF: no parse tree to extract")
        //            #Trace("\nSPPF: no parse tree to extract")
    }
    
    // MARK: - Generate Derivation Diagram
    let derivFile = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Derivations")
        .appendingPathExtension("gv")
    try generateDerivationDiagram(outputFile: derivFile, grammar: grammar, tokens: messageScanner.tokens)
    info += "Derivation diagram written to \(derivFile.lastPathComponent)\n"
    //        Logger.ui.info( "Derivation diagram written to \(derivFile.lastPathComponent)")
    //        #Trace("Derivation diagram written to \(derivFile.lastPathComponent)")
    
    Logger.ui.info("\(info)")
    //    }
#endif
    
    Logger.ui.debug("first/follow set size: \(GrammarNode.sizeofSets) terminals.count: \(grammar.terminals.count) nonTerminals.count: \(grammar.nonTerminals.count)")
    
}
//}
