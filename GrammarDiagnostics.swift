//
//  GrammarDiagnostics.swift
//  Advent
//
//  Created by Johannes Brands on 2026.04.12.
//

import OSLog

extension GrammarNode {

//  What it computes: pairwise intersections of alternates' FIRST sets, plus FIRST ∩ FOLLOW where the node is nullable. Pure set arithmetic over terminal IDs, done once at grammar load from the FIRST/FOLLOW fixpoint. It also populates node.ambiguous, which the tracing/diagnostics read.
//
//  Who consumes it: grammar.isLL1, asserted by LL1DetectionTests against small textbook grammars, and printed by main.swift. Nothing in the parser. Since isLocallyLL1 is gone, verifyLL1's result no longer influences parsing at all.
//
//  So it reliably means exactly one thing: no terminal ID appears in two alternates' FIRST sets (or in FIRST and FOLLOW when nullable). That is a statement about grammar symbols.
//
//  What it does not mean — and this is the part that's stale relative to lex-on-demand: it does not mean at most one alternate can be predicted at a given input position. Three reasons, all of which survive symbol-disjointness:
//
//    • Distinct terminal IDs can co-match the same characters — an identifier regex and the literal "for" are different IDs with disjoint FIRST sets, and both match for.
//    • testSelect asks the lexer a per-position question ("does any terminal in this alternate's FIRST match here?"). Set disjointness cannot answer it.
//    • The lexer returns a set of matches of differing lengths — maximal munch isn't global — so even a single terminal can fork.
//
//  verifyLL1 is a grammar-structure signal — useful for the detection tests, for main's report, and for populating ambiguous — but it is no longer, and can no longer be treated as, a parser precondition. Anyone reading "LL1 is true" should not infer prediction determinism.

    @discardableResult
    func verifyLL1() -> Bool {
        var subtreeIsLL1 = true
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            if seq?.verifyLL1() == false { subtreeIsLL1 = false }
        case .N:
            if let seq { // rhs
                if !seq.verifyLL1() { subtreeIsLL1 = false }
                // For a RHS nonterminal, check the definition's FIRST (via alt)
                // against this position's FOLLOW. The positional 'first' includes
                // look-through tokens from the continuation, which would cause
                // false conflicts.
                if let production = alt, production.isNullable {
                    let definitionFirst = production.first.subtracting([""])
                    ambiguous = definitionFirst.intersection(follow)
                }
            } else { // lhs
//                Logger.grammar.debug("verifyLL1 in RULE: \(self.name)")
                if !handleAlternatesAmbiguity() { subtreeIsLL1 = false }
            }
        case .ALT:
            if seq?.verifyLL1() == false { subtreeIsLL1 = false }
        case .DO, .POS, .OPT, .KLN:
            if seq?.verifyLL1() == false { subtreeIsLL1 = false }
            if !handleAlternatesAmbiguity() { subtreeIsLL1 = false }
        case .END:
            break
        }
        if !ambiguous.isEmpty {
            subtreeIsLL1 = false
        }
        let saved = traceIndent
        traceIndent += 2
        trace(kind, number)
        traceIndent += 2
        trace("first    ", first.sorted())
        trace("follow   ", follow.sorted())
        trace("ambiguous", ambiguous.sorted())
        traceIndent = saved

        return subtreeIsLL1
    }

    private func handleAlternatesAmbiguity() -> Bool {
        // ambiguity set of KLN and POS is the intersection of follow(KLN) with the union of the pairwise intersections of all its first(ALT)'s ('duplicates')
        var subtreeIsLL1 = true

        var occurances: [String:Int] = [:]
        // count occurances in firsts
        var current = self.alt
        while let altNode = current {
            if current?.verifyLL1() == false { subtreeIsLL1 = false }
            for element in altNode.first {
                occurances[element, default: 0] += 1
            }
            current = altNode.alt
        }
        // count occurances in follow only when this node can derive ε,
        // because a token in FOLLOW then competes with the alternates' FIRST tokens
        if isNullable {
            for element in follow {
                occurances[element, default: 0] += 1
            }
        }
        // keep only duplicated occurances
        for (element, count) in occurances where count > 1 {
            ambiguous.insert(element)
        }
        if !ambiguous.isEmpty {
            subtreeIsLL1 = false
        }

        return subtreeIsLL1
    }
}

extension GrammarNode {

    func detectSchrödingerConflict() {
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            seq?.detectSchrödingerConflict()
        case .N:
            if let seq { // rhs
                seq.detectSchrödingerConflict()
            } else { // lhs
//                Logger.grammar.debug("detectSchrödingerConflict in RULE: \(self.name)")
                handleAlternatesSchrödingerConflict()
            }
        case .ALT:
            seq?.detectSchrödingerConflict()
        case .DO, .POS, .OPT, .KLN:
            seq?.detectSchrödingerConflict()
            handleAlternatesSchrödingerConflict()
        case .END:
            break
        }
        identifierKeywordConflict()
    }

    func possibleMatch(of tokenType: String, with: String) -> Bool {
        return true
    }
    
    func possibleIdentifier(_ element: String) -> Bool {
        let startsWithLetter = element.first?.isLetter ?? false
        let isLiteral = GrammarNode.grammar?.terminals[element]?.isLiteral == true
        return startsWithLetter && isLiteral
    }
    
    func identifierKeywordConflict() {
        if first.contains("plainIdentifier") {
            let overlap = Set(first.filter { possibleIdentifier($0) })
            if !overlap.isEmpty {
                print("Schrödinger NODE plainIdentifier ~ \(overlap.sorted())\n  \(self.ebnfDot())")
            }
        }
    }

    private func handleAlternatesSchrödingerConflict() {
        // Schrödinger tokens may match additional branches compared with the pure FIRST and FOLLOW sets.
        // this creates more GLL descriptors and more work.
        // here we check ambiguous overlap between plainIdentifier and keywords
        var schrödingerAlert = false
        var conflicts: Set<String> = []
        
        var current = self.alt
        while let altNode = current {
            current?.detectSchrödingerConflict()
//            Logger.grammar.debug("ALT: \(altNode.first.sorted())")
            if first.contains("plainIdentifier") {
                schrödingerAlert = true
            } else {
                for element in altNode.first {
                    if possibleIdentifier(element) {
                        conflicts.insert(element)
                    }
                }
            }
            current = altNode.alt
        }
        
        // inspect elements in follow only when this node can derive ε,
        // because a token in FOLLOW then competes with the alternates' FIRST tokens
        if isNullable {
            if follow.contains("plainIdentifier") {
                schrödingerAlert = true
            } else {
                for element in follow {
                    if possibleIdentifier(element) {
                        conflicts.insert(element)
                    }
                }
            }
        }
        if schrödingerAlert && !conflicts.isEmpty {
            print("Schrödinger ALTERNATES plainIdentifier ~ \(conflicts.sorted())\n  \(self.ebnfDot())")
        }
    }
    
}
