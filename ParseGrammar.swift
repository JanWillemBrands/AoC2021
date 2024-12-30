////
////  ParseGrammar.swift
////  Advent
////
////  Created by Johannes Brands on 23/12/2024.
////
//
//import Foundation
//
//class Parser {
//    let startSymbol: String
//    let scanner: Scanner
//    let grammarRoot: GrammarNode?
//    
//    init(startSymbol: String, scanner: Scanner) throws {
//        self.startSymbol = startSymbol
//        self.scanner = scanner
//        grammarRoot = parseGrammar(startSymbol: startSymbol)
//        if grammarRoot == nil {
//            print("error: Start Symbol '\(_startSymbol)' not found")
//            exit(1)
//        }
//    }
//}
//
//func parseGrammar(startSymbol: String) -> GrammarNode? {
//    let inputFileURL = URL(fileURLWithPath: #filePath)
//        .deletingLastPathComponent()
//    
//        .appendingPathComponent("test")
////        .appendingPathComponent("TortureSyntax")
////        .appendingPathComponent("apus")
////        .appendingPathComponent("apusNoAction")
////        .appendingPathComponent("apusAmbiguous")
//    
//        .appendingPathExtension("apus")
//    
//    initScanner(fromFile: inputFileURL, patterns: apusTerminals)
//    
//    currentIndex = 0
//    initParser()
//    parseApusGrammar()
//    
//    trace("terminals:")
//    for (name, tokenPattern) in terminals {
//        trace("\t", name, "\t", tokenPattern.source)
//    }
//    
//    trace("nonTerminals:")
//    for (name, grammarNode) in nonTerminals {
//        trace("\t", name, "\t", grammarNode.kind)
//    }
//    
//    guard let root = nonTerminals[startSymbol] else { return nil }
//    
//    root.follow.insert("")
//    trace("start symbol '\(startSymbol)' first:", root.first, "follow:", root.follow)
//    
//    var oldSize = 0
//    var newSize = 0
//    repeat {
//        oldSize = newSize
//        newSize = 0
//        for nt in nonTerminals {
//            newSize += nt.value.populateFirstFollowSets()
//        }
//        trace("first & follow", newSize)
//    } while newSize != oldSize
//    
//    trace = true
//    for nonTerminal in nonTerminals.sorted(by: { $0.key < $1.key } ) {
//        traceIndent = 0
//        trace("RULE: '\(nonTerminal.key)'")
//        nonTerminal.value.detectAmbiguity()
//    }
//    
//    return root
//}
//
