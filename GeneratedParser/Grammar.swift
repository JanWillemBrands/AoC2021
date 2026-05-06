//
//  GrammarStore.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.13.
//

//import AdventMacros
import BitCollections

// Result of parsing an APUS grammar file.
// Holds all grammar artifacts needed by downstream consumers.
class Grammar {
    var startSymbol: String = ""
    var terminals: [String: TokenPattern] = [:]
    var nonTerminals: [String: GrammarNode] = [:]
    var messages: [String] = []
    var root: GrammarNode = GrammarNode(kind: .EOS, name: "$")
    var isLL1: Bool = true
    
    // MARK: - Integer Symbol Table
    //
    // The parsing hot path (testSelect, tokenMatch) originally compared strings:
    //   slot.first.contains(token.kind)    — hashes a String, probes a Set<String>
    //   cL.name == token.kind              — compares two Strings
    //
    // To eliminate string hashing/comparison overhead, we assign each terminal
    // a sequential integer ID following the ART numbering convention:
    //   0        = EOS ($)
    //   1..T     = terminals (assigned during grammar construction)
    //   T+1      = epsilon (ε) — a sentinel in first sets signalling nullability
    //
    // Token.kindID and GrammarNode.nameID mirror the string-based kind/name fields.
    // Set<String> first/follow/ambiguous are mirrored by BitSet firstBS/followBS/ambiguousBS.
    // The hot path then uses integer comparison and BitSet.contains() (O(1) bit test).
    // Strings are retained for diagnostics, error messages, and diagram generation.
    
    /// Maps terminal name → integer ID. Initialised with "$" → 0 (EOS).
    var symbolToID: [String: Int] = ["$": 0]
    
    /// The integer ID for the epsilon sentinel "ε" in first/follow BitSets.
    /// Set by `finalizeSymbolTable()` to T+1 (one past the last terminal ID).
    var epsilonID: Int!
    
    /// Register a terminal kind and return its integer ID. Idempotent.
    /// Called from `regex()` and `literal()` during grammar construction.
    @discardableResult
    func registerTerminal(_ name: String) -> Int {
        if let existing = symbolToID[name] { return existing }
        let id = symbolToID.count
        symbolToID[name] = id
        return id
    }
    
    /// Assign epsilon its ID (T+1). Call after all terminals are registered
    /// but before `assignNameIDs()`.
    func finalizeSymbolTable() {
        epsilonID = symbolToID.count
        symbolToID["ε"] = epsilonID
    }
    
    /// Walk all grammar nodes and set `nameID` on terminal-like nodes
    /// (.T, .TI, .C, .B, .EOS, .EPS) by looking up their `str` in `symbolToID`.
    /// Nonterminal nodes keep the default `nameID = -1` since they are never
    /// compared against tokens — only terminal nodes need to match token kinds.
    func assignNameIDs() {
        root.nameID = symbolToID["$"]!
        for (_, node) in nonTerminals {
            assignNameIDsRecursive(node)
        }
    }
    
    private func assignNameIDsRecursive(_ node: GrammarNode) {
        switch node.kind {
        case .EOS:
            node.nameID = symbolToID["$"]!
        case .T, .TI, .C, .B:
            node.nameID = symbolToID[node.name]!
        case .EPS:
            node.nameID = epsilonID
        default:
            break
        }
        // Follow seq/alt links, avoiding cycles:
        // - END.seq points back to its bracket
        // - RHS nonterminal .alt points to the LHS definition (would cause infinite loop)
        // LHS nonterminals (seq == nil) must follow .alt to reach their production alternates.
        if node.kind != .END {
            if let seq = node.seq { assignNameIDsRecursive(seq) }
        }
        if node.kind == .N {
            if node.seq == nil, let alt = node.alt { assignNameIDsRecursive(alt) }
        } else if node.kind != .END {
            if let alt = node.alt { assignNameIDsRecursive(alt) }
        }
    }
    
    /// Convert each node's string-based first/follow/ambiguous `Set<String>`
    /// into the corresponding `firstBS`/`followBS`/`ambiguousBS` `BitSet`,
    /// using `symbolToID` for the mapping.
    /// Call after the first/follow fixpoint has converged and after `detectAmbiguity`.
    func populateBitSets() {
        for (_, node) in nonTerminals {
            populateBitSetsRecursive(node)
        }
    }
    
    private func populateBitSetsRecursive(_ node: GrammarNode) {
        node.firstBS = BitSet()
        for s in node.first {
            if let id = symbolToID[s] { node.firstBS.insert(id) }
        }
        node.followBS = BitSet()
        for s in node.follow {
            if let id = symbolToID[s] { node.followBS.insert(id) }
        }
        node.ambiguousBS = BitSet()
        for s in node.ambiguous {
            if let id = symbolToID[s] { node.ambiguousBS.insert(id) }
        }
        if node.kind != .END {
            if let seq = node.seq { populateBitSetsRecursive(seq) }
        }
        // Follow alt links, but avoid cycles:
        // - END.alt points back to its enclosing ALT (handled by .END check above)
        // - RHS nonterminal .alt points to the LHS definition (would cause infinite loop)
        // LHS nonterminals (seq == nil) must follow .alt to reach their production alternates.
        if node.kind == .N {
            if node.seq == nil, let alt = node.alt { populateBitSetsRecursive(alt) }
        } else if node.kind != .END {
            if let alt = node.alt { populateBitSetsRecursive(alt) }
        }
    }
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
            node.first = [node.name]
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
            node.first.insert("ε")
            try handleBracket(node)
        case .KLN:
            node.first.insert("ε")
            try handleBracket(node)
        case .POS:
            try handleBracket(node)
        case .END:
            node.first = ["ε"]
            node.follow = node.seq!.follow
            if node.seq!.kind == .KLN || node.seq!.kind == .POS {
                node.follow.formUnion(node.seq!.first.subtracting(["ε"]))
            }
        }
        GrammarNode.sizeofSets += node.first.count + node.follow.count
    }
    
    private func handleNonTerminal(_ node: GrammarNode) throws {
        if let seq = node.seq {
            try populateFirstFollowSets(for: seq)
            updateFollow(for: node)
            if let production = nonTerminals[node.name] {
                node.alt = production
                node.first = production.first
                if node.first.contains("ε") {
                    node.first.remove("ε")
                    node.first.formUnion(seq.first)
                }
                production.follow.formUnion(node.follow)
            } else {
                trace("grammar parse error: '\(node.name)' was not defined as a grammar rule")
                let definedAsTerminal = terminals[node.name] != nil
                if definedAsTerminal {
                    trace("but it was defined as terminal \(terminals[node.name]!.source) instead, if this was intended please define the terminal before using it in the grammar.")
                }
                throw GrammarNodeError.undefinedNonTerminal(name: node.name, definedAsTerminal: definedAsTerminal)
            }
        } else {
            try populateFirstFromAlts(node)
        }
    }
    
    private func handleBracket(_ node: GrammarNode) throws {
        try populateFirstFromAlts(node)
        try populateFirstFollowSets(for: node.seq!)
        if node.first.contains("ε") {
            node.first.remove("ε")
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
        if node.follow.contains("ε") {
            node.follow.remove("ε")
            node.follow.formUnion(node.seq!.follow)
        }
    }
}
