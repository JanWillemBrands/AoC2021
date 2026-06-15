//
//  Grammar.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.13.
//

import OSLog
//import AdventMacros
import BitCollections

// Internal sentinel strings for FIRST/FOLLOW sets and the symbol table:
//   end-of-input:  "○" (WHITE CIRCLE U+25CB)
//   epsilon:       ""  (empty string), displayed as "ε"


// Result of parsing an APUS grammar file.
// Holds all grammar artifacts needed by downstream consumers.
class Grammar {
    var startSymbol: String = ""
    var terminals: [String: TokenPattern] = [:]
    var nonTerminals: [String: GrammarNode] = [:]
    var messages: [String] = []
    var preamble: [String] = []
    var epilogue: [String] = []
    var root: GrammarNode = GrammarNode(kind: .EOS, name: "○")
    var isLL1: Bool = true
    /// True when unquoted synthetic layout terminals (>>| / |<<) are used in productions.
    var usesInjectedLayoutTokens: Bool = false
    
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
    
    // the representation of the BNF empty production are:
    // in apus grammar specifications: the empty string "" or the epsilon character 'ε'
    // in canonical ebnf() or ebnfDot() output: 'ε' GREEK SMALL LETTER EPSILON U+03B5
    // internally in FIRST and FOLLOW sets: "" (empty string)

    // the representation of the end-of-input token: "○" (BLACK CIRCLE U+25CF), displayed as "$"

    /// Maps terminal name → integer ID. Initialised with "○" → 0 (EOS).
    var symbolToID: [String: Int] = ["○": 0]

    /// The integer ID for the epsilon sentinel in first/follow BitSets.
    /// Set by `finalizeSymbolTable()` after all terminals are registered.
    var epsilonID: Int!

    /// The integer ID for the end-of-string sentinel "○" token.
    /// Pre-seeded at Grammar init with ID 0 (see `symbolToID` default value).
    var eosID: Int { 0 }
    
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
        symbolToID[""] = epsilonID
    }
    
    /// Walk all grammar nodes and set `nameID` on terminal-like nodes
    /// (.T, .TI, .C, .B, .EOS, .EPS) by looking up their `str` in `symbolToID`.
    /// Nonterminal nodes keep the default `nameID = -1` since they are never
    /// compared against tokens — only terminal nodes need to match token kinds.
    func assignNameIDs() {
        root.nameID = symbolToID["○"]!
        for (_, node) in nonTerminals {
            assignNameIDsRecursive(node)
        }
    }

    private func assignNameIDsRecursive(_ node: GrammarNode) {
        switch node.kind {
        case .EOS:
            node.nameID = symbolToID["○"]!
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

    // MARK: - @unless(X) Target Resolution

    /// Resolve `unlessTargetName` strings (captured at parse time) to GrammarNode
    /// pointers. Walks every alternate chain under each nonterminal. Call after
    /// `assignNameIDs()` and before `populateBitSets()`.
    func resolveUnlessTargets() throws {
        for (_, nt) in nonTerminals {
            var alt: GrammarNode? = nt.alt
            while let a = alt {
                if let name = a.unlessTargetName {
                    guard let target = nonTerminals[name] else {
                        throw ApusParserError.undefinedNonTerminal(name: name, definedAsTerminal: terminals[name] != nil)
                    }
                    a.unlessTarget = target
                }
                alt = a.alt
            }
        }
    }

    // MARK: - Schrödinger Exclusion Set Propagation
    //
    // Background: the scanner produces Schrödinger tokens when multiple patterns
    // match the same input at the same length (e.g. "if" matches both the `if`
    // keyword and `plainIdentifier`). The GLL parser explores ALL duals, which
    // is correct but creates many descriptors that will ultimately fail.
    //
    // The `---` annotation in APUS grammar files declares that certain keywords
    // should never be treated as a specific terminal in that context:
    //
    //   identifier = plainIdentifier ---("if" "let" "var" ...) | escapedIdentifier .
    //
    // This means: when the head token is "if", don't try the plainIdentifier dual
    // for this grammar node. The annotation seeds an `exclude` set on the terminal.
    //
    // Propagation: the exclude set is propagated upward through the grammar so that
    // parent nonterminals can reject Schrödinger duals early in `testSelect`,
    // before creating descriptors that would fail deep inside the grammar.
    //
    // The propagation rules are:
    //   - Terminal with `---`:    seed (already set by ApusParser)
    //   - RHS nonterminal N(X):  inherit from LHS definition of X
    //   - LHS nonterminal:       intersection over alternates that contribute the terminal
    //   - ALT:                   inherit from the first seq-chain symbol that contributes
    //   - Bracket (DO/OPT/KLN/POS): intersection over alternates
    //   - Sequence with nullable prefix: skip nullable nodes whose own content doesn't
    //     contribute, continue to the next symbol in the chain
    //
    // Intersection semantics ensure that if ANY path to the terminal lacks an
    // exclusion, the parent conservatively allows the dual (no false rejections).
    // Alternates with empty exclude (not yet resolved) are skipped to let the
    // fixpoint converge for self-referencing rules.
    //
    // The exclude sets are independent of FIRST/FOLLOW — they are computed in a
    // separate pass after FIRST/FOLLOW have converged, and stored in `exclude`
    // (Set<String>) / `excludeBS` (BitSet) on each GrammarNode.
    //
    // At parse time, `testSelect` and `tokenMatch` check: when walking the
    // Schrödinger dual chain, if the head token's kindID is in `slot.excludeBS`,
    // skip the dual.

    /// Entry point: propagate `exclude` sets from seed terminals upward through the grammar.
    /// Call after FIRST/FOLLOW have converged and before `populateBitSets`.
    func propagateExcludeSets() {
        var excludedTerminals: Set<String> = []
        for (_, nt) in nonTerminals {
            collectExcludedTerminals(nt, into: &excludedTerminals)
        }
        guard !excludedTerminals.isEmpty else { return }

        var changed = true
        while changed {
            changed = false
            for (_, nt) in nonTerminals {
                changed = propagateExcludeRecursive(nt, excludedTerminals: excludedTerminals) || changed
            }
        }
    }

    private func collectExcludedTerminals(_ node: GrammarNode, into result: inout Set<String>) {
        if !node.exclude.isEmpty && node.kind.isTerminal {
            result.insert(node.name)
        }
        walkChildren(node) { collectExcludedTerminals($0, into: &result) }
    }

    private func propagateExcludeRecursive(_ node: GrammarNode, excludedTerminals: Set<String>) -> Bool {
        var changed = false

        guard !node.first.isDisjoint(with: excludedTerminals) else {
            return walkChildrenChanged(node, excludedTerminals: excludedTerminals)
        }

        if !node.kind.isTerminal && node.kind != .EPS {
            let newExclude: Set<String>
            switch node.kind {
            case .N where node.seq != nil:
                newExclude = node.alt?.exclude ?? []
            case .N:
                newExclude = intersectExcludesFromAlts(node, excludedTerminals: excludedTerminals)
            case .ALT:
                newExclude = excludeFromSeqChain(node.seq, excludedTerminals: excludedTerminals)
            case .DO, .OPT, .KLN, .POS:
                newExclude = intersectExcludesFromAlts(node, excludedTerminals: excludedTerminals)
            default:
                newExclude = []
            }
            if !newExclude.isEmpty && !newExclude.isSubset(of: node.exclude) {
                node.exclude.formUnion(newExclude)
                changed = true
            }
        }

        return walkChildrenChanged(node, excludedTerminals: excludedTerminals) || changed
    }

    private func intersectExcludesFromAlts(_ node: GrammarNode, excludedTerminals: Set<String>) -> Set<String> {
        var result: Set<String>? = nil
        var alt = node.alt
        while let a = alt {
            if !a.first.isDisjoint(with: excludedTerminals) && !a.exclude.isEmpty {
                if let current = result {
                    result = current.intersection(a.exclude)
                } else {
                    result = a.exclude
                }
            }
            alt = a.alt
        }
        return result ?? []
    }

    private func excludeFromSeqChain(_ start: GrammarNode?, excludedTerminals: Set<String>) -> Set<String> {
        var node = start
        while let n = node {
            if n.kind == .END { break }
            if ownFirstContains(n, excludedTerminals: excludedTerminals) {
                if n.isNullable {
                    let contExclude = excludeFromSeqChain(n.seq, excludedTerminals: excludedTerminals)
                    return contExclude.isEmpty ? n.exclude : n.exclude.intersection(contExclude)
                }
                return n.exclude
            }
            guard n.isNullable else { break }
            node = n.seq
        }
        return []
    }

    /// Does this node's OWN content (not continuation) contribute an excluded terminal to FIRST?
    private func ownFirstContains(_ node: GrammarNode, excludedTerminals: Set<String>) -> Bool {
        switch node.kind {
        case .T, .TI, .C, .B:
            return excludedTerminals.contains(node.name)
        case .N:
            guard let lhs = node.alt else { return false }
            return !lhs.first.isDisjoint(with: excludedTerminals)
        case .DO, .OPT, .KLN, .POS:
            var alt = node.alt
            while let a = alt {
                if !a.first.isDisjoint(with: excludedTerminals) { return true }
                alt = a.alt
            }
            return false
        default:
            return false
        }
    }

    // MARK: - Grammar Graph Traversal Helpers

    /// Visit children of a grammar node (seq and alt links), avoiding cycles.
    private func walkChildren(_ node: GrammarNode, _ visit: (GrammarNode) -> Void) {
        if node.kind != .END, let seq = node.seq { visit(seq) }
        if node.kind == .N {
            if node.seq == nil, let alt = node.alt { visit(alt) }
        } else if node.kind != .END {
            if let alt = node.alt { visit(alt) }
        }
    }

    /// Recurse into children for exclude propagation, returning whether anything changed.
    private func walkChildrenChanged(_ node: GrammarNode, excludedTerminals: Set<String>) -> Bool {
        var changed = false
        walkChildren(node) {
            changed = propagateExcludeRecursive($0, excludedTerminals: excludedTerminals) || changed
        }
        return changed
    }

    /// Convert each node's string-based first/follow/ambiguous `Set<String>`
    /// into the corresponding `firstBS`/`followBS`/`ambiguousBS` `BitSet`,
    /// using `symbolToID` for the mapping.
    /// Call after the first/follow fixpoint has converged and after `verifyLL1`.
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
        node.excludeBS = BitSet()
        for s in node.exclude {
            if let id = symbolToID[s] { node.excludeBS.insert(id) }
        }
        node.followAheadBS = BitSet()
        for s in node.followAhead {
            if let id = symbolToID[s] { node.followAheadBS.insert(id) }
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
        case .EOS, .T, .TI, .C:
            try populateFirstFollowSets(for: node.seq!)
//            node.first = [node.name]
            node.first.insert(node.name)
            updateFollow(for: node)
        case .B:
            // Boundary/trivia constraints are not part of FIRST/FOLLOW token prediction.
            try populateFirstFollowSets(for: node.seq!)
            node.first = node.seq!.first
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
            if let production = nonTerminals[node.name] {
                node.alt = production
                node.first = production.first
                if node.first.contains("") {
                    node.first.remove("")
                    node.first.formUnion(seq.first)
                }
                production.follow.formUnion(node.follow)
            } else {
                var error = "grammar parse error: '\(node.name)' was not defined as a grammar rule\n"
//                trace("grammar parse error: '\(node.name)' was not defined as a grammar rule")
                let definedAsTerminal = terminals[node.name] != nil
                if definedAsTerminal {
                    error += "instead it was defined as terminal \(terminals[node.name]!.source)\n"
                    error += "if this was intended please define the terminal before using it in the grammar"
                    Logger.grammar.error("\(error, privacy: .public)")
//                    trace("but it was defined as terminal \(terminals[node.name]!.source) instead, if this was intended please define the terminal before using it in the grammar.")
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
