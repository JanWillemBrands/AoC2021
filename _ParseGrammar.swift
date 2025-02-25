//
//  _ParseGrammar.swift
//  Advent
//
//  Created by Johannes Brands on 23/12/2024.
//

import Foundation

func _parseGrammar(startSymbol: String) -> GrammarNode? {
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
    _initParser()
    _parseApusGrammar()
    
    trace("_terminals:")
    for (name, tokenPattern) in _terminals {
        trace("\t", name, "\t", tokenPattern.source)
    }
    
    trace("_nonTerminals:")
    for (name, node) in _nonTerminals {
        trace("\t", name, "\t", node.kind)
    }
    
    guard let root = _nonTerminals[startSymbol] else { return nil }
    
    for (name, node) in _nonTerminals {
        trace("Processing END nodes for:", name)
        node.resolveEndNodeLinks(parent: node, alternate: node.alt)
    }
    
    // TODO: finalize representation for EOS
//    root.follow.insert("$")
    root.follow.insert("")
    trace = false
    trace("_start symbol '\(startSymbol)' first:", root.first, "follow:", root.follow)
    
    var _oldSize = 0
    var _newSize = 0
    repeat {
        _oldSize = _newSize
        _newSize = 0
        for (_, node) in _nonTerminals {
            GrammarNode.sizeofSets = 0
            node.__populateFirstFollowSets()
            _newSize += GrammarNode.sizeofSets
        }
        trace("first & follow", _newSize)
    } while _newSize != _oldSize

    for (name, node) in _nonTerminals {
        trace("Detecting ambiguity for:", name)
        node.detectAmbiguity()
    }
    
    return root
}

