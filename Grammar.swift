//
//  Grammar.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.13.
//

/// Result of parsing an APUS grammar file.
/// Holds all grammar artifacts needed by downstream consumers.
public class Grammar {
    public internal(set) var startSymbol: String = ""
    public internal(set) var terminals: [String: TokenPattern] = [:]
    public internal(set) var nonTerminals: [String: GrammarNode] = [:]
    public internal(set) var messages: [String] = []
    public internal(set) var root: GrammarNode = GrammarNode(kind: .EOS, str: "$")
}

extension Grammar {
    func populateFirstFollowSets(for node: GrammarNode) throws {
        switch node.kind {
        case .EPS:
            try populateFirstFollowSets(for: node.seq!)
            node.first = node.seq!.first
            updateFollow(for: node)
        case .EOS, .T, .TI, .C, .B:
            try populateFirstFollowSets(for: node.seq!)
            node.first = [node.str]
            updateFollow(for: node)
        case .N:
            try handleNonTerminal(node)
        case .ALT:
            try populateFirstFollowSets(for: node.seq!)
            node.first = node.seq!.first
            node.follow = node.seq!.follow
        case .DO:
            try handleBracket(node)
        case .OPT:
            node.first.insert("")
            try handleBracket(node)
        case .KLN:
            node.first.insert("")
            try handleBracket(node)
        case .POS:
            try handleBracket(node)
        case .END:
            node.first = [""]
            node.follow = node.seq!.follow
            if node.seq!.kind == .KLN || node.seq!.kind == .POS {
                node.follow.formUnion(node.seq!.first.subtracting([""]))
            }
        }
        GrammarNode.sizeofSets += node.first.count + node.follow.count
    }
    
    private func handleNonTerminal(_ node: GrammarNode) throws {
        if let seq = node.seq {
            try populateFirstFollowSets(for: seq)
            updateFollow(for: node)
            if let production = nonTerminals[node.str] {
                node.alt = production
                node.first = production.first
                if node.first.contains("") {
                    node.first.remove("")
                    node.first.formUnion(seq.first)
                }
                production.follow.formUnion(node.follow)
            } else {
                print("grammar parse error: '\(node.str)' was not defined as a grammar rule")
                let definedAsTerminal = terminals[node.str] != nil
                if definedAsTerminal {
                    print("but it was defined as terminal \(terminals[node.str]!.source) instead, if this was intended please define the terminal before using it in the grammar.")
                }
                throw GrammarNodeError.undefinedNonTerminal(name: node.str, definedAsTerminal: definedAsTerminal)
            }
        } else {
            try populateFirstFromAlts(node)
        }
    }
    
    private func handleBracket(_ node: GrammarNode) throws {
        try populateFirstFromAlts(node)
        try populateFirstFollowSets(for: node.seq!)
        if node.first.contains("") {
            node.first.remove("")
            node.first.formUnion(node.seq!.first)
        }
        updateFollow(for: node)
    }
    
    private func populateFirstFromAlts(_ node: GrammarNode) throws {
        var current = node.alt
        while let altNode = current {
            try populateFirstFollowSets(for: altNode)
            node.first.formUnion(altNode.first)
            current = altNode.alt
        }
    }
    
    private func updateFollow(for node: GrammarNode) {
        node.follow = node.seq!.first
        if node.follow.contains("") {
            node.follow.remove("")
            node.follow.formUnion(node.seq!.follow)
        }
    }
}
