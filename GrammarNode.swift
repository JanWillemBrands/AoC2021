//
//  GrammarSlot.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import Foundation

final class GrammarNode {
    enum Kind {
        case SEQ(children: [GrammarNode])
        case ALT(children: [GrammarNode])
        case OPT(child: GrammarNode)
        case REP(child: GrammarNode)
        case NTR(name: String, link: GrammarNode? = nil)
        case TRM(type: String)
    }
    var kind: Kind
    
    init(_ kind: Kind) {
        self.kind = kind
    }
    
    var first:      Set<String> = []
    var follow:     Set<String> = []
    var ambiguous:  Set<String> = []
    
    var yield: Set<Split> = []
    
    static var count = 0
    var number = 0
}

extension GrammarNode {
    func isExpecting(_ token: Token) -> Bool {
        if first.contains(token.kind) {
            return true
        } else if first.contains("") && follow.contains(token.kind) {
            return true
        } else {
            var expected = first
            if expected.remove("") == "" {
                expected.formUnion(follow)
            }
            expect(expected)
            return false
        }
    }
}

extension GrammarNode: Hashable {
    static func == (lhs: GrammarNode, rhs: GrammarNode) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension GrammarNode: CustomStringConvertible {
    // generate labels like A, B, C, ... AA, AB, AC, ...
    var description: String {
        let latin = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        func toLatin(_ n: Int) -> String {
            let letter = String(latin[n % 26])
            if n < 26 {
                return letter
            } else {
                return toLatin(n / 26 - 1) + letter
            }
        }
        return toLatin(self.number)
    }
    
    var description_: String {
        let greek = Array("αβγδεζηθικλμνξοπρστυφχωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ")
        func toGreek(_ n: Int) -> String {
            let letter = String(greek[n % 24])
            if n < 24 {
                return letter
            } else {
                return toGreek(n / 24 - 1) + letter
            }
        }
        return toGreek(self.number)
    }
    
    var kindName: String {
        "." + String(describing: self.kind).prefix(3)
    }
}

extension GrammarNode {
    final func populateFirstFollowSets() -> Int {
        var sizeofSets = 0
        
        switch kind {
        case .SEQ(let children):
            var f = follow
            for child in children.reversed() {
                child.follow = f
                sizeofSets += child.populateFirstFollowSets()
                f = child.first
                if f.contains("") {
                    f.subtract([""])
                    f.formUnion(child.follow)
                }
            }
            first = children.first!.first
            if first.contains("") {
                first.subtract([""])
                first.formUnion(children.first!.follow)
            }
            
        case .ALT(let children):
            for child in children {
                child.follow = follow
                sizeofSets += child.populateFirstFollowSets()
                first.formUnion(child.first)
            }
            
        case .OPT(let child):
            child.follow = follow
            sizeofSets += child.populateFirstFollowSets()
            first = child.first
            first.insert("")
            
        case .REP(let child):
            child.follow = follow
            sizeofSets += child.populateFirstFollowSets()
            child.follow = child.follow.union(child.first.subtracting([""]))
            first = child.first
            first.insert("")
            
        case .NTR(let name, _):
            if let production = nonTerminals[name] {
                kind = .NTR(name: name, link: production)
                first = production.first
                production.follow.formUnion(follow)
            } else {
                print("error: '\(name)' has not been defined as a grammar rule")
                exit(4)
            }
            
        case .TRM(let type):
            first = [type]
        }
        return sizeofSets + first.count + follow.count
    }
}

extension GrammarNode {
    final func detectAmbiguity() {
        trace(kind)
        traceIndent += 4
        trace("first ", first.sorted())
        trace("follow", follow.sorted())
        traceIndent -= 4
        
        traceIndent += 1
        
        // manually assign the node number here so that the entire tree gets a top-down-left-to-right numbering sequence
        self.number = GrammarNode.count
        GrammarNode.count += 1
        
        switch kind {
        case .SEQ(let children):
            for child in children {
                child.detectAmbiguity()
            }
        case .ALT(let children):
            var occurance: [String:Int] = [:]
            for child in children {
                for token in child.first {
                    occurance[token] = (occurance[token] ?? 0) + 1
                    child.detectAmbiguity()
                }
            }
            for key in occurance.keys where (occurance[key] ?? 0) > 1 {
                ambiguous.insert(key)
            }
        case .OPT(let child):
            ambiguous = child.first.intersection(follow)
            child.detectAmbiguity()
        case .REP(let child):
            ambiguous = child.first.intersection(follow)
            child.detectAmbiguity()
        case .NTR(_, _):
            if first.contains("") {
                ambiguous = first.intersection(follow)
            }
        case .TRM(_): break
        }
        traceIndent -= 1
        
        ambiguous.remove("")    // to handle both uses of "" in first (as ε, ϵ, epsilon) and in follow (as $, EOF)
        if !ambiguous.isEmpty {
            if isAmbiguous {
                trace("^ ERROR: node is not LL1, ambiguous set:", ambiguous)
                exit(3)
            } else {
                trace("^ warning: processing may be slower due to ambiguity of set:", ambiguous)
            }
        }
    }
}

extension GrammarNode {
    func resetParseResults() {
        //        seen_U = []
        //        done_P = []
        //        var ambiguous: Set<String> = []
        yield = []
        switch kind {
        case .SEQ(let children):
            for child in children {
                child.resetParseResults()
            }
        case .ALT(let children):
            for child in children {
                child.resetParseResults()
            }
        case .OPT(let child):
            child.resetParseResults()
        case .REP(let child):
            child.resetParseResults()
        case .NTR(_, let link):
            link!.resetParseResults()
        case .TRM(_):
            break
        }
    }
}

extension GrammarNode {
    func ebnf() -> String {
        var s = ""
        switch kind {
        case .SEQ(let children):
            for child in children {
                if case .ALT = child.kind { s.append("( ") }
                s.append(child.ebnf())
                if case .ALT = child.kind { s.append(" )") }
                s.append(" ")
            }
            s.removeLast(1)
        case .ALT(let children):
            for child in children {
                s.append(child.ebnf())
                s.append(" | ")
            }
            s.removeLast(3)
        case .OPT(let child):
            s.append("[ ")
            s.append(child.ebnf())
            s.append(" ]")
        case .REP(let child):
            s.append("{ ")
            s.append(child.ebnf())
            s.append(" }")
        case .NTR(let name, _):
            s.append(name)
        case .TRM(let type):
            if let t = terminals[type] {
                s.append(t.source)
            }
        }
        return s
    }
}
