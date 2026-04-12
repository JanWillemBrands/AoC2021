//
//  GrammarDiagnostics.swift
//  Advent
//
//  Created by Johannes Brands on 2026.04.12.
//

import OSLog
import AdventMacros

extension GrammarNode {

    func detectAmbiguity() {
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            seq?.detectAmbiguity()
        case .N:
            if let seq { // rhs
                seq.detectAmbiguity()
                // For a RHS nonterminal, check the definition's FIRST (via alt)
                // against this position's FOLLOW. The positional 'first' includes
                // look-through tokens from the continuation, which would cause
                // false conflicts.
                if let production = alt, production.isNullable {
                    let definitionFirst = production.first.subtracting(["ε"])
                    ambiguous = definitionFirst.intersection(follow)
                }
            } else { // lhs
//                Logger.grammar.debug("detectAmbiguity in RULE: \(self.name)")
                handleAlternatesAmbiguity()
            }
        case .ALT:
            seq?.detectAmbiguity()
        case .DO, .POS, .OPT, .KLN:
            seq?.detectAmbiguity()
            handleAlternatesAmbiguity()
        case .END:
            break
        }
        if !ambiguous.isEmpty {
            GrammarNode.isLL1 = false
        }
        let saved = traceIndent
        traceIndent += 2
        #Trace(kind, number)
        traceIndent += 2
        #Trace("first    ", first.sorted())
        #Trace("follow   ", follow.sorted())
        #Trace("ambiguous", ambiguous.sorted())
//        if !ambiguous.isEmpty {
//            if kind == .N, seq == nil {
//                print("Ambiguity in \(name)", ambiguous.sorted())
//            }
//        }
        traceIndent = saved
        
//        identifierKeywordConflict()

    }

    private func handleAlternatesAmbiguity() {
        // ambiguity set of KLN and POS is the intersection of follow(KLN) with the union of the pairwise intersections of all its first(ALT)'s ('duplicates')

        var occurances: [String:Int] = [:]
        // count occurances in firsts
        var current = self.alt
        while let altNode = current {
            current?.detectAmbiguity()
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
//        identifierKeywordConflict()
    }

    func possibleMatch(of tokenType: String, with: String) -> Bool {
        return true
    }
    
    func possibleIdentifier(_ element: String) -> Bool {
        let startsWithLetter = element.first?.isLetter ?? false
        let isKeyword = GrammarNode.grammar?.terminals[element]?.isKeyword == true
        return startsWithLetter && isKeyword
    }
    
    func identifierKeywordConflict() {
        if first.contains("plainIdentifier") {
            let overlap = Set(first.filter { possibleIdentifier($0) })
            if !overlap.isEmpty {
                Logger.grammar.debug("Schrödinger plainIdentifier ~ \(overlap.sorted())\n\(self.ebnfDot())")
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
            Logger.grammar.debug("ALT: \(altNode.first.sorted())")
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
            Logger.grammar.debug("Schrödinger plainIdentifier ~ \(conflicts.sorted())\n\(self.ebnfDot())")
        }
    }
    
}

