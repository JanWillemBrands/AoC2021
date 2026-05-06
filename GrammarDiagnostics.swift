//
//  GrammarDiagnostics.swift
//  Advent
//
//  Created by Johannes Brands on 2026.04.12.
//

import OSLog
//import AdventMacros

extension GrammarNode {

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
            isLocallyLL1 = false
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
