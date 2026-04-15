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

import OSLog
import Foundation
import AdventMacros
import BitCollections

enum GrammarNodeError: Error {
    case undefinedNonTerminal(name: String, definedAsTerminal: Bool)
}

enum GrammarNodeKind { case EOS, T, TI, C, B, EPS, N, ALT, END, DO, OPT, POS, KLN }

extension GrammarNodeKind {
    var isTerminal: Bool { self == .T || self == .TI || self == .C || self == .B }
    var isBracket:  Bool { self == .DO || self == .OPT || self == .KLN || self == .POS }
    var isLeaf:     Bool { isTerminal || self == .EPS }
    var isClosure:  Bool { self == .KLN || self == .POS }
}

final class GrammarNode {
    
    var frankensteinMatchAllowed = false    // only valid for GrammarNodes with kind = "literal"
    
    static var count = 0
    
    // this is to give GrammarNodes access to the grammar
    static weak var grammar: Grammar?
    
    var number = 0
    /// Integer ID from `Grammar.symbolToID`, set by `assignNameIDs()`.
    /// Only meaningful for terminal-like nodes (.T, .TI, .C, .B, .EOS, .EPS);
    /// nonterminals keep the default -1. Used by `tokenMatch()` for O(1) integer comparison.
    var nameID: Int!
    
    let kind: GrammarNodeKind
    let name: String
    
//    var alt, seq: GrammarNode?
    var alt: GrammarNode? {
        didSet {
            // alt is overloaded:
            // - ALT/END nodes: alt points to an .ALT node
            // - RHS nonterminals (N with seq): alt points to the LHS .N definition
            if let alt {
                switch kind {
                case .N where seq != nil:
                    assert(alt.kind == .N, "RHS nonterminal alt should point to its LHS .N definition, got \(alt.kind)")
                default:
                    assert(alt.kind == .ALT, "alt should always point to a .ALT node, got \(alt.kind)")
                }
            }
        }
    }
    var seq: GrammarNode? {
        didSet {
            assert(seq?.kind != .ALT, "seq should never point to a .ALT node")
        }
    }
    init(kind: GrammarNodeKind, name: String, alt: GrammarNode? = nil, seq: GrammarNode? = nil) {
        self.kind = kind
        self.name = name
        self.alt = alt
        self.seq = seq
    }
    
    var actions: [String] = []  // stores semantic actions
    var signature: String?      // function signature text (params, throws, return) for .N nodes
    var locals: [String] = []   // local declarations for generated function  TODO: can this be removed ???
    
    // first is a positional prediction set: the tokens that can appear at this
    // position in the sequence, including look-through of nullable elements.
    // During FIRST/FOLLOW propagation (Grammar.handleBracket), ε is removed
    // from OPT/KLN and replaced by the continuation's FIRST (concatenation rule).
    // This means first does NOT contain ε for OPT/KLN, even though they are
    // intrinsically nullable. Use isNullable for nullability checks instead.
    var first:      Set<String> = []
    var follow:     Set<String> = []
    var ambiguous:  Set<String> = []
    
    /// BitSet mirrors of first/follow/ambiguous, populated by `Grammar.populateBitSets()`.
    /// Used by `testSelect()` and the follow check on the hot path for O(1) membership tests.
    var firstBS:      BitSet = []
    var followBS:     BitSet = []
    var ambiguousBS:  BitSet = []
    
    static var sizeofSets = 0
    static var isLL1 = true
    
    // Whether this node is intrinsically nullable (can derive ε).
    // Per Definition 6 of "GLL syntax analysers for EBNF grammars":
    // FIRST([ψ]) = FIRST(ψ) ∪ {ε} and FIRST({ψ}) = FIRST(ψ) ∪ {ε}
    // OPT and KLN are always nullable by definition.
    var isNullable: Bool {
        switch kind {
        case .OPT, .KLN: return true
        default: return first.contains("ε")
        }
    }
    
    var yield: Set<BinarySpan> = []
    
    var cell = Cell(name: "", r: 0, c: 0)
}

extension GrammarNode {
    func isExpecting(_ token: Token) -> Bool {
        if first.contains(token.kind) {
            return true
        } else if first.contains("ε") && follow.contains(token.kind) {
            return true
        } else {
            var expectedTokens = first
            if first.contains("ε") {
                expectedTokens.formUnion(follow)
            }
            #Trace("expected \"\(token.kind)\" to be in", expectedTokens)
            return false
        }
    }
}

extension GrammarNode {
    /// LHS nonterminal: defines a production rule (has .alt chain, no .seq)
    var isLHS: Bool { kind == .N && seq == nil }
    
    /// RHS nonterminal: reference inside a sequence (has .seq, .alt → LHS definition)
    var isRHS: Bool { kind == .N && seq != nil }
    
    /// Collect the symbols of an alternate's body: walk .seq chain until .END.
    /// Call on an ALT node.
    var bodySymbols: [GrammarNode] {
        var symbols: [GrammarNode] = []
        var s = seq
        while let n = s {
            if n.kind == .END { break }
            symbols.append(n)
            s = n.seq
        }
        return symbols
    }
    
    /// Find the END node inside a bracket's first alternate body.
    var bracketEndNode: GrammarNode? {
        guard kind.isBracket else { return nil }
        var node = alt?.seq
        while let n = node {
            if n.kind == .END { return n }
            node = n.seq
        }
        return nil
    }
}

extension GrammarNode: Hashable {
    static func == (lhs: GrammarNode, rhs: GrammarNode) -> Bool {
        lhs.number == rhs.number
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}

extension GrammarNode: CustomStringConvertible {
    
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
    func clearNodes() {
        yield = []
        // recursively clear child nodes but avoid loops
        if kind != .END {
            seq?.clearNodes()
        }
        // TODO: check if this treatment of .N is correct
        if kind != .END && kind != .N {
            alt?.clearNodes()
        }
    }
}

extension GrammarNode {
    /// Label for a bracket node showing only its own content, not the continuation.
    /// e.g. `{ "a" }` instead of `{ "a" } { "a" }`.
    func bracketLabel() -> String {
        switch kind {
        case .DO:  return "(\((alt?.ebnf() ?? "").trimmingCharacters(in: .whitespaces)))"
        case .OPT: return "[\((alt?.ebnf() ?? "").trimmingCharacters(in: .whitespaces))]"
        case .POS: return "<\((alt?.ebnf() ?? "").trimmingCharacters(in: .whitespaces))>"
        case .KLN: return "{\((alt?.ebnf() ?? "").trimmingCharacters(in: .whitespaces))}"
        default:   return name
        }
    }
    
    // when called on a lhs nonterminal GrammarNode this generates its full EBNF grammar
    func ebnf() -> String {
        var s = ""
        switch kind {
        case .EOS, .EPS:
            s += name + " "
            if let seq { s += seq.ebnf() }
        case .T, .TI, .C, .B:
            s += "\"" + name + "\" "
            if let seq { s += seq.ebnf() }
        case .N:
            if let seq { // rhs
                s += name + " " + seq.ebnf()
            } else { // lhs
                if let alt {
                    s += name + " = " + alt.ebnf() + "."
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
    static var dottedSlot: GrammarNode?                     // will be set to the dotted GrammarNode slot
    static var dottedEBNF = ""                              // will be set to the dotted EBNF production
    enum Exit: Error { case endOfToplevel }
    
    func emit() throws {
        let middleDot = "\u{00B7}"
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            GrammarNode.dottedEBNF += name
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if let seq { try seq.emit() }
        case .N:
            if let seq { // rhs
                GrammarNode.dottedEBNF += name
                if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
                try seq.emit()
            } else { // lhs
                GrammarNode.dottedEBNF += name
            }
        case .ALT:
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if let seq { try seq.emit() }
            if let alt {
                GrammarNode.dottedEBNF +=  "|"
                try alt.emit()
            }
        case .END:
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if seq?.kind == .N {
                // this is the end of the top level alternate
                GrammarNode.containingNonterminal = seq
                GrammarNode.toplevelAlternate = alt
                throw Exit.endOfToplevel
            }
        case .DO:
            if let alt {
                GrammarNode.dottedEBNF += "("
                try alt.emit()
                GrammarNode.dottedEBNF += ")"
            }
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if let seq { try seq.emit() }
        case .OPT:
            if let alt {
                GrammarNode.dottedEBNF += "["
                try alt.emit()
                GrammarNode.dottedEBNF += "]"
            }
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if let seq { try seq.emit() }
        case .POS:
            if let alt {
                GrammarNode.dottedEBNF += "<"
                try alt.emit()
                GrammarNode.dottedEBNF += ">"
            }
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if let seq { try seq.emit() }
        case .KLN:
            if let alt {
                GrammarNode.dottedEBNF += "{"
                try alt.emit()
                GrammarNode.dottedEBNF += "}"
            }
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
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
    // the dot is placed after the dottedSlot node:
    //   terminal/nonterminal: dot after the symbol  e.g. S="a"·{"a"}
    //   bracket (KLN etc):    dot after closing }   e.g. S="a"{"a"}·
    //   ALT:                  dot at start of body  e.g. S="a"{·"a"}
    //   END:                  dot at end of body    e.g. S="a"{"a"·}
    func ebnfDot() -> String {
        if kind == .N && seq == nil {
            // a lhs nonterminal
            return name
        } else {
            // construct the ebnf for the toplevel alternate production containing the dot
            GrammarNode.dottedEBNF = ""
            GrammarNode.dottedSlot = self
            (GrammarNode.toplevelAlternate, GrammarNode.containingNonterminal) = toplevels()
            if let tla = GrammarNode.toplevelAlternate, let cnt = GrammarNode.containingNonterminal {
                try? tla.emit()
                return cnt.name + "=" + GrammarNode.dottedEBNF
            } else {
                return GrammarNode.dottedEBNF
            }
        }
    }
}

