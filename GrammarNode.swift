//
//  GrammarNode.swift
//  Advent
//
//  Created by Johannes Brands on 20/05/2024.
//

//enum GKind { case EOS, T, EPS, N, ALT, END }
//enum GKind { case EOS, T, TI, C, B, EPS, N, ALT, END, DO, OPT, POS, KLN }
//enum ApusKind { case EOS, TRM, EPS, NTR, ALT, END, ONE, ZOO, OOM, ZOM }
//enum SwiftKind { case endOfString, terminal, epsilon, nonTerminal, alternate, end, one, zeroOrOne, oneOrMore, zeroOrMore}
/*
 EOS    end of string ("$")
 T      terminal (singleton, case sensitive)
 TI     terminal (singleton, case insensitive)
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
 */

import Foundation

enum GrammarNodeKind { case EOS, T, TI, C, B, EPS, N, ALT, END, DO, OPT, POS, KLN }

final class GrammarNode {
//    static var nodesWithLet: Set<String> = []

    static var count = 0
    var number = 0
    
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
    }
    
    var actions: [String] = [] // stores semantic actions
    
    var first:      Set<String> = []
    var follow:     Set<String> = []
    var ambiguous:  Set<String> = []
    static var sizeofSets = 0
    
    var bsr: Set<Triple> = []
    
    var cell = Cell(name: "", r: 0, c: 0)
}

struct Triple: Hashable, CustomStringConvertible {
    let i: Int  // left
    let k: Int  // pivot
    let j: Int  // right
    var description: String { "\(i):\(k):\(j)" }
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
#if DEBUG
            trace("expect \"\(token.kind)\" to be in", expectedTokens)
#endif
            return false
        }
    }
}

//extension GrammarNode: Hashable {
//    static func == (lhs: GrammarNode, rhs: GrammarNode) -> Bool {
//        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
//    }
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(ObjectIdentifier(self))
//    }
//}

extension GrammarNode: Hashable {
    static func == (lhs: GrammarNode, rhs: GrammarNode) -> Bool {
        lhs.number == rhs.number
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}

extension GrammarNode: CustomStringConvertible {
//    var description: String {
//        cell.description
//    }
    
    var description: String { number.description }
    
    // generate labels like A, B, C, ... AA, AB, AC, ...
    var _description: String {
        if kind == .EOS { return "00" }
        let latin = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        func toLatin(_ n: Int) -> String {
            let letter = String(latin[n % 26])
            if n < 26 {
                return letter
            } else {
                return toLatin(n / 26 - 1) + letter
            }
        }
        return toLatin(self.number).graphvizHTML
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
    func resolveEndNodeLinks(parent: GrammarNode?, alternate: GrammarNode?) {
        number = GrammarNode.count
        GrammarNode.count += 1
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
    // TODO: ambiguity set of KLN and POS is the intersection of follow(KLN) with the union of the pairwise intersections of all its first(ALT)'s ('duplicates')
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
            // TODO: there is never ambiguity with .DO
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
//        if ambiguous.count > 0 {
//            print("ambiguous", ambiguous.sorted())
//        }
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

extension GrammarNode {
    func populateFirstFollowSets() {
        switch kind {
        case .EPS:
            seq!.populateFirstFollowSets()
//            first = [""]
            first = seq!.first
            updateFollow()
        case .EOS, .T, .TI, .C, .B:
            seq!.populateFirstFollowSets()
            first = [str]
            updateFollow()
        case .N:
            handleNonTerminal()
        case .ALT:
            seq!.populateFirstFollowSets()
            // copy first & follow from the first (real) node in the sequence
            first = seq!.first
            follow = seq!.follow
        case .DO:
            handleBracket()
        case .OPT:
            first.insert("")
            handleBracket()
        case .KLN:
            first.insert("")
            handleBracket()
//             TODO: not sure following is right, even though it is in ART...
//             it complicates ambiguous because it's longer overlap(first, follow)
//             file://Users/janwillem/ART/referenceImplementation/src/uk/ac/rhul/cs/csle/art/cfg/grammar/Grammar.java
//             For closure nodes, fold first into follow
//             if (root.elm.kind == GrammarKind.POS || root.elm.kind == GrammarKind.KLN) changed |= root.instanceFollow.addAll(removeEpsilon(root.instanceFirst));
//            follow.formUnion(first.subtracting([""]))
        case .POS:
            handleBracket()
        case .END:
            // .END first is epsilon so that the follow of the previous node copies the follow of the .END
            first = [""]
            // the follow of .END is the follow of the starting bracket or nonterminal node
            follow = seq!.follow
            // if the starting node was a closure (POS, KLN) then the first of the starting node folds into the follow
            if seq!.kind == .KLN || seq!.kind == .POS {
                follow.formUnion(seq!.first.subtracting([""]))
            }
       }
        GrammarNode.sizeofSets += first.count + follow.count
//        if first.contains("let") && kind == .N {
//            print(str)
//            print(GrammarNode.nodesWithLet)
//            GrammarNode.nodesWithLet.insert(str)
//        }
    }
    
    private func handleNonTerminal() {
        if let seq {
            // a RHS nonterminal instance is part of a sequence
            seq.populateFirstFollowSets()
            updateFollow()
            if let production = nonTerminals[str] {
                // assign the alt of the rhs to the alt of the lhs
                alt = production.alt
                // rhs first of the rhs nonterminal is equal to the first of lhs production rule
                first = production.first
                if first.contains("") {
                    first.remove("")
                    first.formUnion(seq.first)
                }
                // update the follow of the lhs nonterminal as the union of the follows of all rhs nonterminals
                production.follow.formUnion(follow)
            } else {
                print("grammar parse error: '\(str)' was not defined as a grammar rule")
                if let terminal = terminals[str] {
                    print("but it was defined as terminal \(terminal.source) instead, please move the terminal definition before its first use.")
                }
                exit(4)
            }
        } else {
            // a LHS nonterminal defines a production rule and is NOT part of a sequence
            assignUnionOfAltFirst()
            // the follow set of a lhs nonterminal production rule is [“$”] if startsymbol, and [] otherwise.
            // this is already set before calling populateFirstFollowSets.
        }
    }
    
    private func handleBracket() {
        assignUnionOfAltFirst()
        seq!.populateFirstFollowSets()
        if first.contains("") {
            first.remove("")
            first.formUnion(seq!.first)
        }
        updateFollow()
    }
    
    private func assignUnionOfAltFirst() {
        // set the first set of a lhs nonterminal production rule, or a bracketed expression, to the union of first sets of all its .alt's
        var current = alt
        while let altNode = current {
            altNode.populateFirstFollowSets()
            first.formUnion(altNode.first)
            current = altNode.alt
        }
    }
    
    private func updateFollow() {
        follow = seq!.first
        if follow.contains("") {
            follow.remove("")
            follow.formUnion(seq!.follow)
        }
    }
}

extension GrammarNode {
    func clearNodes() {
        bsr = []
        // recursively clear child nodes but avoid loops
        if kind != .END {
            seq?.clearNodes()
        }
        if kind != .END && kind != .N {
            alt?.clearNodes()
        }
    }
}

extension GrammarNode {
    // when called on a lhs nonterminal GrammarNode this generates its full EBNF grammar
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


extension GrammarNode {
    static var containingNonterminal: GrammarNode?          // will be set to the containing N (lhs) node
    static var toplevelAlternate: GrammarNode?              // will be set to the toplevel ALT node
    static var dot: GrammarNode?                            // will be set to the dotted GrammarNode slot
    static var s = ""
    
    enum Exit: Error { case endOfToplevel }
    
    func emit() throws {
        if self == GrammarNode.dot { GrammarNode.s += "·" }
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            GrammarNode.s += str
            if let seq { try seq.emit() }
        case .N:
            if let seq { // rhs
                GrammarNode.s += str
                try seq.emit()
            } else { // lhs
                if let alt {
                    GrammarNode.s += str
//                    + "="
//                    try alt.emit()
//                    GrammarNode.s += "."
                }
            }
        case .ALT:
            if let seq { try seq.emit() }
            if let alt {
                GrammarNode.s +=  "|"
                try alt.emit()
            }
        case .END:
            if seq?.kind == .N {
                // this is the end of the top level alternate
                GrammarNode.containingNonterminal = seq
                GrammarNode.toplevelAlternate = alt
                throw Exit.endOfToplevel
            }
        case .DO:
            if let alt {
                GrammarNode.s += "("
                try alt.emit()
                GrammarNode.s += ")"
            }
            if let seq { try seq.emit() }
        case .OPT:
            if let alt {
                GrammarNode.s += "["
                try alt.emit()
                GrammarNode.s += "]"
            }
            if let seq { try seq.emit() }
        case .POS:
            if let alt {
                GrammarNode.s += "<"
                try alt.emit()
                GrammarNode.s += ">"
            }
            if let seq { try seq.emit() }
        case .KLN:
            if let alt {
                GrammarNode.s += "{"
                try alt.emit()
                GrammarNode.s += "}"
            }
            if let seq { try seq.emit() }
        }
    }
    
    func toplevels() -> (GrammarNode?, GrammarNode?) {
        // returns the the highest level alternate and the containing nonterminal
        var node = self
        while node.seq != nil {
            if node.kind == .END && node.seq?.kind == .N {
                return (node.alt, node.seq)
            }
            else {
                node = node.seq!
            }
        }
        return (nil, nil)
    }

    // generates the dotted ebnf for the toplevel containing alternate of the containing nonterminal
    func ebnfDot() -> String {
        (GrammarNode.toplevelAlternate, GrammarNode.containingNonterminal) = toplevels()
        // construct the ebnf for the toplevel alternate containing the dot
        GrammarNode.s = ""
        GrammarNode.dot = self
        if let tla = GrammarNode.toplevelAlternate, let cnt = GrammarNode.containingNonterminal {
            try? tla.emit()
            let ebnfPlusDot = GrammarNode.s
            return cnt.str + "=" + ebnfPlusDot
        } else {
            return GrammarNode.s
        }
    }
}

