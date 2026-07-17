//
//  main.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import OSLog
import Foundation

trace = false

let grammarFileURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
//    .appendingPathComponent("apus grammars/charGLL")
    .appendingPathComponent("apus grammars/Swift")
//    .appendingPathComponent("apus grammars/layout")
//    .appendingPathComponent("apus grammars/apus")
//    .appendingPathComponent("grammars/Python/Python")
//    .appendingPathComponent("apus grammars/ScanModeTest")
//    .appendingPathComponent("apus grammars/CommentTest")
//    .appendingPathComponent("apus grammars/attributeHunt")
//    .appendingPathComponent("apus grammars/AfroozehHunt")
//    .appendingPathComponent("apus grammars/apusWithAction")
//    .appendingPathComponent("apus grammars/TortureSyntax")
//    .appendingPathComponent("apus grammars/test")
//    .appendingPathComponent("apus grammars/regex-operator")
//    .appendingPathComponent("apus grammars/tortureART")
//    .appendingPathComponent("apus grammars/tortureEBNF")
//    .appendingPathComponent("apus grammars/apusAmbiguous")
    .appendingPathExtension("apus")

let grammar: Grammar
do {
    let apusParser = try ApusParser(fromFile: grammarFileURL)
    do {
        grammar = try apusParser.parse(explicitStartSymbol: "")
    } catch {
        Logger.ui.error("failed to parse grammar: \(grammarFileURL, privacy: .public), error: \(error, privacy: .public)")
        exit(1)
    }
} catch {
    Logger.ui.error("failed to scan grammar: \(grammarFileURL, privacy: .public), error: \(error, privacy: .public)")
    exit(1)
}

let messageParser = MessageParser(grammar: grammar)

//let ball = 1 ⚽️ 2

print("grammar: \(grammarFileURL.lastPathComponent), messages: \(grammar.messages.count)")
if grammar.messages.isEmpty {
    print("no messages found (^^^ blocks). nothing to parse")
}

for (mi, message) in grammar.messages.enumerated() {
    print("\n=== message \(mi+1)/\(grammar.messages.count): \(message.prefix(60)) ===")
    let input: String
    if message.hasPrefix("#") {
        let fileName = message.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        let messageFileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent(fileName)
        do {
            input = try String(contentsOf: messageFileURL, encoding: .utf8)
        } catch {
            Logger.ui.error("failed to read message file: \(messageFileURL.lastPathComponent, privacy: .public)")
            continue
        }
    } else {
        input = String(message)
    }

    // use the AST to parse the message
    let start = clock()

    for _ in 0..<1 {
        messageParser.parse(input: input)
    }

    let end = clock()
    let cpuTime = Double(end - start) / Double(CLOCKS_PER_SEC)

    // Oracle: post-parse disambiguation (rules from grammar annotations)
//    Oracle(parser: messageParser, input: input).disambiguate()

    // Ambiguity-harvest driver (opt-in via APUS_SIG_DUMP=1). Runs the Oracle +
    // AST build and emits one canonical signature line per residual ambiguity:
    //   SIG <TAB> <messageIndex> <TAB> node <TAB> message <TAB> signature
    // The Phase-1 harvester (harvest_ambiguity.py) feeds all failing snippets as
    // `^^^` messages, runs this, and clusters the SIG lines into the signature table.
    if ProcessInfo.processInfo.environment["APUS_SIG_DUMP"] == "1" {
        Oracle(parser: messageParser, input: input).disambiguate()
        let sigBuilder = DerivationBuilder(parser: messageParser, input: input)
        _ = sigBuilder.buildAST()
        for d in sigBuilder.diagnostics {
            print("SIG\t\(mi)\t\(d.fingerprint)")
        }
    }
    var stats = "cpuTime, descriptorCount, crf.count, sizeOfSets, yieldCount\n"
    stats += "\(cpuTime), \(messageParser.descriptorCount), \(messageParser.crf.count), \(GrammarNode.sizeofSets), \(messageParser.yieldCount)\n"
    Logger.ui.info("\(stats, privacy: .public)")
//    print("tokenPatterns:")
//    for tp in grammar.terminals {
//        print(tp.key, tp.value.source)
//    }

//    do {
//        var keywords: [String] = []
//        var macro: [String] = []
//        var punctuation: [String] = []
//        for (key, value) in grammar.terminals {
//            if value.isLiteral {
//                if let first = key.first, first.isLetter {
//                    keywords.append(key)
//                } else if let first = key.first, first == "#" {
//                    macro.append(key)
//                } else{
//                    punctuation.append(key)
//                }
//            }
//        }
//        for k in keywords.sorted() {
//            print("\"\(k)\" ", terminator: "")
//        }
//        print()
//        for m in macro.sorted() {
//            print("\"\(m)\" ", terminator: "")
//        }
//        print()
//        for p in punctuation.sorted() {
//            print("\"\(p)\" ", terminator: "")
//        }
//    }
//    print(cpuTime, messageParser.descriptorCount, messageParser.crf.count)

    // Sort elements (if BSR is Comparable) then join
    //    // Global BSR set removed; to inspect yields, iterate per grammar node.
    //    // Example: print total distributed-yield cardinality used by stats.
    //    // Logger.parse.debug("yieldCount = \(messageParser.yieldCount)")



#if DEBUG
    let enableDiagrams = false

    if enableDiagrams && grammar.nonTerminals.count < 1000 && messageParser.crf.count < 1000 {

        trace = true
        var info = ""

        // MARK: - Generate New Parser

        let parserFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("GeneratedParser")
            .appendingPathComponent(grammar.startSymbol + "_parser")
            .appendingPathExtension("swift")
        info += "LL1 is \(grammar.isLL1)\n"
        if grammar.isLL1 {
            let parserGenerator = ParserGenerator(outputFile: parserFile, grammar: grammar)
            try parserGenerator.generate()
            info += "LL1 recursive descent parser written to \(parserFile.lastPathComponent)\n"
        }

        // MARK: - Generate CRF and AST diagrams

        let diagramFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("ART")
            .appendingPathExtension("gv")
        let diagramGenerator = ASTDiagramGenerator(outputFile: diagramFile, grammar: grammar, messageParser: messageParser)
        try diagramGenerator.generate()
        info += "AST diagram written to \(diagramFile.lastPathComponent)\n"

        // MARK: - Generate SPPF Diagram
        let sppfExtractor = SPPFExtractor(parser: messageParser, input: input)

        if let sppfRoot = sppfExtractor.extractSPPF() {
            let sppfFile = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("SPPF")
                .appendingPathExtension("gv")
            try generateSPPFDiagram(outputFile: sppfFile, root: sppfRoot)
            info += "SPPF diagram written to \(sppfFile.lastPathComponent)\n"
        } else {
            Logger.ui.warning("SPPF: no parse tree to extract")
        }

        // MARK: - Generate Derivation Diagram
        let derivFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Derivations")
            .appendingPathExtension("gv")
        try generateDerivationDiagram(outputFile: derivFile, parser: messageParser, input: input)
        info += "Derivation diagram written to \(derivFile.lastPathComponent)\n"

        Logger.ui.info("\(info, privacy: .public)")
    }
#endif

}

