//
//  _GrammarNode.swift
//  Advent
//
//  Created by Johannes Brands on 20/05/2024.
//

import Foundation

enum GrammarNodeKind { case EOS, T, TI, C, B, EPS, N, ALT, END, DO, OPT, POS, KLN }

final class GrammarNode {
    let kind: GrammarNodeKind
    let str: String
    var alt: GrammarNode? {
        didSet {
            assert(alt?.kind == .ALT, "alt should always point to a .ALT node")
        }
    }
    var seq: GrammarNode? {
        didSet {
            assert(seq?.kind != .ALT, "seq should never point to a .ALT node")
        }
    }
    init(kind: GrammarNodeKind, str: String, alt: GrammarNode? = nil, seq: GrammarNode? = nil) {
        self.kind = kind
        self.str = str
        self.alt = alt
        self.seq = seq
        self.number = GrammarNode.count
        GrammarNode.count += 1
    }
    
    var first:      Set<String> = []
    var follow:     Set<String> = []
    var ambiguous:  Set<String> = []
    static var sizeofSets = 0
    
    var yield: Set<Split> = []
    
    // TODO: remove or keep in DEBUG mode only
    static var count = 0
    let number: Int
    
    var cell = Cell(name: "", r: 0, c: 0)

}

extension GrammarNode {
    func isExpecting(_ token: Token) -> Bool {
        if first.contains(token.kind) {
            return true
        } else if first.contains("") && follow.contains(token.kind) {
            return true
        } else {
            var expectedTokens = first
            if first.contains( "") {
                expectedTokens.formUnion(follow)
            }
            trace("expect \"\(token.kind)\" to be in", expectedTokens)
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
//    var description: String {
//        cell.description
//    }
    
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
    
    var __description: String {
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
    func __populateFirstFollowSets() {
        switch kind {
        case .EPS:
            if let seq {
                seq.__populateFirstFollowSets()
                updateFollow(with: seq)
            }
//            first = []
            first = follow // since .EPS matches the empty string ""
        case .EOS, .T, .TI, .C, .B:
            first = [str]
            if let seq {
                seq.__populateFirstFollowSets()
                updateFollow(with: seq)
            }
        case .N:
            handleNonTerminal()
        case .ALT:
            if let seq {
                seq.__populateFirstFollowSets()
                first = seq.first
                if first.contains("") && !seq.follow.isEmpty{
                    first.remove("")
                    first.formUnion(seq.follow)
                }
            }
        case .DO:
            handleBrackets()
        case .OPT:
            first.insert("")
            handleBrackets()
        case .KLN:
            first.insert("")
            handleBrackets()
            // TODO: not sure following is right, even though it is in ART...
            // it complicates ambiguous because it's longer overlap(first, follow)
            // file://Users/janwillem/ART/referenceImplementation/src/uk/ac/rhul/cs/csle/art/cfg/grammar/Grammar.java
            // For closure nodes, fold first into follow
            // if (root.elm.kind == GrammarKind.POS || root.elm.kind == GrammarKind.KLN) changed |= root.instanceFollow.addAll(removeEpsilon(root.instanceFirst));
            follow.formUnion(first.subtracting([""]))
        case .POS:
            handleBrackets()
            // TODO: not sure following is right, even though it is in ART...
            // file://Users/janwillem/ART/referenceImplementation/src/uk/ac/rhul/cs/csle/art/cfg/grammar/Grammar.java
            // For closure nodes, fold first into follow
            // if (root.elm.kind == GrammarKind.POS || root.elm.kind == GrammarKind.KLN) changed |= root.instanceFollow.addAll(removeEpsilon(root.instanceFirst));
            follow.formUnion(first.subtracting([""]))
        case .END:
//            first = []
            first = [""]
            // the follow of .END is the follow of the .seq that started it
            follow = seq?.follow ?? []
        }
        GrammarNode.sizeofSets += first.count + follow.count
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
    
    private func updateFollow(with node: GrammarNode) {
        follow = node.first
        if follow.contains("") && !node.follow.isEmpty{
            follow.remove("")
            follow.formUnion(node.follow)
        }
    }
}

extension GrammarNode {
    func resolveEndNodeLinks(parent: GrammarNode?, alternate: GrammarNode?) {
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

extension GrammarNode {
    
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
        ambiguous.remove("")    // to handle both uses of "" in first (as ε, ϵ, epsilon) and in follow (as $, EOF)
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
 EOS    end of string ("" or "$")
 T      terminal (singleton, case sensitive)
 TI     terminal (singleton, case insensitive
 C      terminal character
 B      terminal builtin (whitespace, comment, etc)
 EPS    empty string ("#" or "")
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
 //TODO: above breaks the invariant that .alt always references an ALT node.  Change to 'END.seq' references the bracket
 */

extension GrammarNode {
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

