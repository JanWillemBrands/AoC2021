//
//  ParseGrammar.swift
//  Advent
//
//  Created by Johannes Brands on 23/12/2024.
//

import Foundation

func parseGrammar(startSymbol: String) -> GrammarNode? {
    let inputFileURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
//        .appendingPathComponent("TortureSyntax")
//        .appendingPathComponent("test")
//        .appendingPathComponent("apus")
        .appendingPathComponent("apusNoAction")
//        .appendingPathComponent("apusAmbiguous")
        .appendingPathExtension("apus")
    
    initScanner(fromFile: inputFileURL, patterns: apusTerminals)
    
    index = 0
    initParser()
    parseApusGrammar()
    
    trace("terminals:")
    for (name, tokenPattern) in terminals {
        trace("\t", name, "\t", tokenPattern.source)
    }
    
    trace("nonTerminals:")
    for (name, node) in nonTerminals {
        trace("\t", name, "\t", node.kind)
    }
    
    guard let root = nonTerminals[startSymbol] else { return nil }
    
    for (name, node) in nonTerminals {
        trace("Processing END nodes for:", name)
        node.resolveEndNodeLinks(parent: node, alternate: node.alt)
    }
    
    // TODO: finalize representation for EOS
    root.follow.insert("$")
    trace = true
    trace("start symbol '\(startSymbol)' first:", root.first, "follow:", root.follow)
    
    var oldSize = 0
    var newSize = 0
    repeat {
        oldSize = newSize
        newSize = 0
        for (_, node) in nonTerminals {
            GrammarNode.sizeofSets = 0
            node.populateFirstFollowSets()
            newSize += GrammarNode.sizeofSets
        }
        trace("first & follow", newSize)
    } while newSize != oldSize

    for (name, node) in nonTerminals {
        trace("Detecting ambiguity for:", name)
        node.detectAmbiguity()
    }
    
    return root
}

