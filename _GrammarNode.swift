//
//  _GrammarNode.swift
//  Advent
//
//  Created by Johannes Brands on 20/05/2024.
//

import Foundation

enum GKind { case EOS, T, TI, C, B, EPS, N, ALT, END, DO, OPT, POS, KLN }

final class _GrammarNode {
    let kind: GKind
    let str: String
    var alt: _GrammarNode? {
        didSet {
            assert(alt?.kind == .ALT, "alt should always point to an .ALT node")
        }
    }
    var seq: _GrammarNode? {
        didSet {
            assert(seq?.kind != .ALT, "seq should never point to an .ALT node")
        }
    }
    init(kind: GKind, str: String, alt: _GrammarNode? = nil, seq: _GrammarNode? = nil) {
        self.kind = kind
        self.str = str
        self.alt = alt
        self.seq = seq
        self.number = _GrammarNode.count
        _GrammarNode.count += 1
    }
    
    var first:      Set<String> = []
    var follow:     Set<String> = []
    var ambiguous:  Set<String> = []
    static var sizeofSets = 0
    
    static var count = 0
    let number: Int
}

extension _GrammarNode {
    func isExpecting(_ token: Token) -> Bool {
        if first.contains(token.kind) {
            return true
        } else if first.contains("") && follow.contains(token.kind) {
            return true
        } else {
            // TODO: invent some error message relevant to GLL parsing
            //            var expected = first
            //            if expected.remove("") == "" {
            //                expected.formUnion(follow)
            //            }
            //            expect(expected)
            return false
        }
    }
}

extension _GrammarNode: Hashable {
    static func == (lhs: _GrammarNode, rhs: _GrammarNode) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension _GrammarNode: CustomStringConvertible {
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

extension _GrammarNode {
    func __populateFirstFollowSets() {
        switch kind {
        case .EOS, .T, .TI, .C, .B:
            first = [str]
            handleSeq()
        case .EPS:
            first = [""]
            handleSeq()
        case .N:
            handleNonTerminal()
        case .ALT:
            handleAlt()
        case .DO:
            handleBrackets()
        case .OPT:
            first.insert("")
            handleBrackets()
        case .KLN:
            first.insert("")
            handleBrackets()
            // TODO: not sure following is right, even though it is in ART...
            // /Users/janwillem/ART/referenceImplementation/src/uk/ac/rhul/cs/csle/art/cfg/grammar/Grammar.java
            follow.formUnion(first)
        case .POS:
            handleBrackets()
            // TODO: not sure following is right
            follow.formUnion(first.subtracting([""]))
        case .END:
            first = [""]
            // the follow of .END is the follow of the .SEQ that started it
            follow = seq?.follow ?? []
        }
        _GrammarNode.sizeofSets += first.count + follow.count
    }
    
    private func handleSeq() {
        if let seq {
            seq.__populateFirstFollowSets()
            updateFollow(with: seq)
        }
    }
    
    private func handleNonTerminal() {
        if let seq { // a rhs nonterminal instance is part of a sequence
            seq.__populateFirstFollowSets()
            updateFollow(with: seq)
            if let production = _nonTerminals[str] {
                // TODO: doublecheck if this .alt assignment is correct
                alt = production.alt
                // rhs first is first of lhs production rule
                first = production.first
                // TODO:  ????
                //                production.follow.formUnion(follow)
            } else {
                print("error: '\(str)' has not been defined as a grammar rule")
                exit(4)
            }
        } else { // a lhs nonterminal defines a production rule and is NOT part of a sequence
            processAlternatives()
            // the follow set of a lhs nonterminal production rule is [“”] if startsymbol, and [] otherwise.
            // both have already been set before calling populateFirstFollowSets.
        }
    }
    
    private func handleAlt() {
        if let seq {
            seq.__populateFirstFollowSets()
            first = seq.first
            if first.contains("") && !seq.follow.isEmpty{
                first.remove("")
                first.formUnion(seq.follow)
            }
        }
    }
    
    private func handleBrackets() {
        processAlternatives()
        if let seq {
            seq.__populateFirstFollowSets()
            updateFollow(with: seq)
        }
    }
    
    private func processAlternatives() {
        // the first set of a lhs nonterminal production rule, or a bracketed expression, is the union of first sets of all its .alt's
        var currentAlt = alt
        while let altNode = currentAlt {
            altNode.__populateFirstFollowSets()
            first.formUnion(altNode.first)
            altNode.follow = follow
            currentAlt = altNode.alt
        }
    }
    
    private func updateFollow(with node: _GrammarNode) {
        follow = node.first
        if follow.contains("") && !node.follow.isEmpty{
            follow.remove("")
            follow.formUnion(node.follow)
        }
    }
}

extension _GrammarNode {
    func resolveEndNodeLinks(parent: _GrammarNode?, alternate: _GrammarNode?) {
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            seq?.resolveEndNodeLinks(parent: parent, alternate: alternate)
        case .N:
            if let seq { // rhs
                seq.resolveEndNodeLinks(parent: parent, alternate: alternate)
            } else { // lhs
                alt?.resolveEndNodeLinks(parent: self, alternate: alternate)
            }
        case .ALT:
            seq?.resolveEndNodeLinks(parent: parent, alternate: self)
            alt?.resolveEndNodeLinks(parent: parent, alternate: alternate)
        case .DO, .POS, .OPT, .KLN:
            alt?.resolveEndNodeLinks(parent: self, alternate: alternate)
            seq?.resolveEndNodeLinks(parent: parent, alternate: alternate)
        case .END:
            seq = parent
            alt = alternate
        }
    }
}

extension _GrammarNode {
    
    // TODO: doublecheck the role of "" in first/follow/ambiguity
    func detectAmbiguity() {
        if kind == .N, seq == nil {
            trace("_RULE:", str)
        }
        
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            seq?.detectAmbiguity()
        case .N:
            if let seq { // rhs
                seq.detectAmbiguity()
                if first.contains("") {
                    ambiguous = first.intersection(follow)
                }
            } else { // lhs
                handleAlternatesAmbiguity()
            }
        case .ALT:
            seq?.detectAmbiguity()
            if first.contains("") {
                ambiguous = first.intersection(follow)
            }
        case .DO, .POS, .OPT, .KLN:
            seq?.detectAmbiguity()
            handleAlternatesAmbiguity()
        case .END:
            break
        }
        traceIndent += 2
        trace(kind, number)
        traceIndent += 2
        trace("first    ", first.sorted())
        trace("follow   ", follow.sorted())
        trace("ambiguous", ambiguous.sorted())
        traceIndent -= 4
        
    }
    
    private func handleAlternatesAmbiguity() {
        var occurances: [String:Int] = [:]
        var currentAlt = self.alt
        while let altNode = currentAlt {
            currentAlt?.detectAmbiguity()
            for element in altNode.first {
                occurances[element, default: 0] += 1
            }
            currentAlt = altNode.alt
        }
        for (element, count) in occurances where count > 1 {
            ambiguous.insert(element)
        }
        if first.contains("") {
            let overlapFirstFollow = first.intersection(follow)
            ambiguous = ambiguous.union(overlapFirstFollow)
        }
    }
    
}

//enum GKind { case EOS, T, EPS, N, ALT, END }
//enum GKind { case EOS, T, TI, C, B, EPS, N, ALT, END, DO, OPT, POS, KLN }
//enum ApusKind { case EOS, TRM, EPS, NTR, ALT, END, ONE, ZOO, OOM, ZOM }
//enum SwiftKind { case endOfString, terminal, epsilon, nonterminal, alternate, end, one, zeroOrOne, oneOrMore, zeroOrMore}
/*
 EOS    end of string ("$")
 T      terminal (singleton, case sensitive)
 TI     terminal (singleton, case insensitive
 C      terminal character
 B      terminal builtin (whitespace, comment, etc)
 EPS    empty string ("#")
 N      nonterminal
 ALT    start of alternate
 END    end of alternate
 DO     group ()
 OPT    optional []
 POS    one or more <>
 KLN    zero or more (Kleene) {}
 
 END.seq references start of production 'N'
 END.alt references start of alternate 'ALT'
 Extends naturally to EBNF brackets if END.alt references the enclosing bracket 'DO', 'OPT', 'POS', or 'KLN'
 */

extension _GrammarNode {
    func ebnf() -> String {
        var s = ""
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            s += "\"" + str + "\" "
            if let seq { s += seq.ebnf() }
        case .N:
            if let seq { // rhs
                s += str + " " + seq.ebnf()
            } else { // lhs
                if let alt {
                    s += str + " = " + alt.ebnf() + "."
                }
            }
        case .ALT:
            if let seq { s += seq.ebnf() }
            if let alt { s +=  "| " + alt.ebnf() }
        case .END:
            break
        case .DO:
            if let alt { s += "( " + alt.ebnf() + ") " }
            if let seq { s += seq.ebnf() }
        case .OPT:
            if let alt { s += "[ " + alt.ebnf() + "] " }
            if let seq { s += seq.ebnf() }
        case .POS:
            if let alt { s += "< " + alt.ebnf() + "> " }
            if let seq { s += seq.ebnf() }
        case .KLN:
            if let alt { s += "{ " + alt.ebnf() + "} " }
            if let seq { s += seq.ebnf() }
        }
        return s
    }
}

