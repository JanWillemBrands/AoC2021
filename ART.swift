//
//  ART.swift
//  Advent
//
//  Created by Johannes Brands on 20/05/2024.
//

import Foundation

//enum GKind { case EOS, T, EPS, N, ALT, END }
enum GKind { case EOS, T, TI, C, B, EPS, N, ALT, END, DO, OPT, POS, KLN }

final class GNode {
    let kind: GKind
    let str: String
    var alt: GNode? {
        didSet {
            assert(alt?.kind == .ALT, "alt should point to .ALT node")
        }
    }
    var seq: GNode?
    {
       didSet {
           assert(seq?.kind != .ALT, "seq should never point to .ALT node")
       }
   }
    init(kind: GKind, str: String, alt: GNode? = nil, seq: GNode? = nil) {
        self.number = GNode.count
        GNode.count += 1
        self.kind = kind
        self.str = str
        self.alt = alt
        self.seq = seq
    }
    
    var first:      Set<String> = []
    var follow:     Set<String> = []
    var ambiguous:  Set<String> = []
    static var sizeofSets = 0

    static var count = 0
    let number: Int
}

extension GNode {
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

extension GNode: Hashable {
    static func == (lhs: GNode, rhs: GNode) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension GNode: CustomStringConvertible {
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

extension GNode {
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
            handleBrackets()
            first.insert("")
        case .KLN:
            handleBrackets()
            first.insert("")
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
        GNode.sizeofSets += first.count + follow.count
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
            // find the lhs nonterminal production rule that corresponds to this rhs nonterminal instance
            if let production = _nonTerminals[str] {
                // TODO: doublecheck if this .alt assignment is correct
                alt = production.alt
                // rhs first is first of lhs production rule
                first = production.first
                // TODO: doublecheck that this follow union is necessary (does a lhs nonterminal need a follow set?)
//                 production.follow.formUnion(follow)
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

    private func updateFollow(with node: GNode) {
        follow = node.first
        if follow.contains("") && !node.follow.isEmpty{
            follow.remove("")
            follow.formUnion(node.follow)
        }
    }
}

extension GNode {
    func resolveEndNodeLinks(parent: GNode?, alternate: GNode?) {
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

extension GNode {
    
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

var _skip = false

var _terminalAlias: String?

var _nonTerminals: [String:GNode] = [:]
var _terminals: [String:TokenPattern] = [:]
var _messages: [String] = []

//var rules: [GNode] = []

func _initParser() {
    _terminals = [:]
    _nonTerminals = [:]
    _messages = []
}

func _parseApusGrammar() {
    trace("parseApusGrammar", token)
    expect(["identifier", "message"])
    while token.kind == "identifier" {
        _production()
    }
    // TODO: change ¶ into $ to match ART
    expect(["message"])
    while token.kind == "message" {
        _message()
    }
}

func _production() {
    trace("production", token)
    let nonTerminalName = String(token.image)
    next()
    var node: GNode
    if token.kind == "=" {
        next()
        if token.kind == "regex" {
            _terminalAlias = nonTerminalName
            node = _regex()
            _terminalAlias = nil
            next()
        } else {
            node = _alternates()
            if let existing = _nonTerminals[nonTerminalName] {
                // add this production to the end of the existing ALT list
                var endOfList = existing
                while let next = endOfList.alt {
                    endOfList = next
                }
                endOfList.alt = node
            } else {
                _nonTerminals[nonTerminalName] = GNode(kind: .N, str: nonTerminalName, alt: node)
            }
        }
    } else {
        expect([":"])
        next()
        skip = true
        _terminalAlias = nonTerminalName
        if token.kind == "regex" {
            node = _regex()
        } else {
            expect(["literal"])
            node = _literal()
        }
        skip = false
        _terminalAlias = nil
        next()
    }
    // TODO: do we really want regex and literal terminals also listed as nonTerminals?
    //    if let existing = _nonTerminals[nonTerminalName] {
    //        // add this production to the end of the existing ALT list
    //        var current = existing
    //        while let next = current.alt {
    //            current = next
    //        }
    //        current.alt = node
    //    } else {
    //        _nonTerminals[nonTerminalName] = node
    //    }
    expect(["."])
    next()
}

func _message() {
    trace("message", token)
    messages.append(token.stripped)
    next()
}

func _alternates() -> GNode {
    trace("alternates", token)
    let startOfAlternates = _sequence()
    var tmp = startOfAlternates
    while token.kind == "|" {
        next()
        tmp.alt = _sequence()
        tmp = tmp.alt!
    }
    return startOfAlternates
}

func _sequence() -> GNode {
    trace("sequence", token)
    let startOfSequence = GNode(kind: .ALT, str: "")
    var tmp = _term()
    startOfSequence.seq = tmp
    while ["literal", "identifier", "regex", "(", "[", "{", "<"].contains(token.kind) {
        tmp.seq = _term()
        tmp = tmp.seq!
    }
    tmp.seq = GNode(kind: .END, str: "")
    // TODO: need to set the .seq of the .END node to the enclosing nonterminal or bracket, but .alt could be done here
    // tmp.seq?.alt = startOfSequence
    return startOfSequence
}

func _regex() -> GNode {
    trace("regex", token)
    // TODO: insert lineposition name?
    let name = _terminalAlias ?? input.linePosition(of: token.range.lowerBound)
    
    //    let name = _terminalAlias ?? String(token.image)
    if _terminals[name] != nil {
        print("warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
    }
    do {
        let regex = try Regex<Substring>(String(token.stripped))
        // TODO: why is the name not 'name'?
        _terminals[name] = (String(token.image), regex, false, skip)
        trace("regex name:", name, "image:", token.image)
    } catch {
        print("error: \(token.image) is not a valid /regex/")
        exit(9)
    }
    return GNode(kind: .T, str: name)
}

func _literal() -> GNode {
    trace("literal", token)
    let name = _terminalAlias ?? token.stripped
    if _terminals[name] != nil {
        print("warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
    }
    do {
        let regex = try Regex<Substring>(String(token.stripped))
        _terminals[name] = (String(token.image), regex, true, skip)
        trace("literal name:", name, "image:", token.image)
    } catch {
        print("error: \(token.image) is not a valid \"literal\"")
        exit(8)
    }
    return GNode(kind: .T, str: name)
}

func _term() -> GNode {
    trace("term", token)
    var node: GNode
    switch token.kind {
    case "identifier":
        node = GNode(kind: .N, str: token.stripped)
    case "literal":
        node = _literal()
    case "regex":
        // TODO: add support for anonymous regexes
        node = _regex()
    case "(":
        next()
        node = _alternates()
        switch token.kind {
        case ")":
            node = GNode(kind: .DO, str: "", alt: node)
        case ")?":
            node = GNode(kind: .OPT, str: "", alt: node)
        case ")*":
            node = GNode(kind: .KLN, str: "", alt: node)
        case ")+":
            node = GNode(kind: .POS, str: "", alt: node)
        default:
            expect([")", ")?", ")+", ")*"])
            exit(7)
        }
    case "[":
        next()
        node = GNode(kind: .OPT, str: "", alt: _alternates())
        expect(["]"])
    case "{":
        next()
        node = GNode(kind: .KLN, str: "", alt: _alternates())
        expect(["}"])
    case "<":
        next()
        node = GNode(kind: .POS, str: "", alt: _alternates())
        expect([">"])
    default:
        expect(["identifier", "literal", "(", "[", "{", "<"])
        exit(7)
    }
    next()
    return node
}

func _generateDiagrams() {
    let diagramFileURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("ART")
        .appendingPathExtension("gv")
    
    var d = #"""
        digraph G {
          fontname = Menlo
          fontsize = 10
          node [fontname = Menlo, fontsize = 10, color = gray, height = 0, width = 0, margin= 0.04]
          edge [fontname = Menlo, fontsize = 10, color = gray, arrowsize = 0.3]
          graph [ordering = out, ranksep = 0.2]
          rankdir = "TB"
        """#
    
    var crosslinks: [(from: GNode, to: GNode)] = []
    
    func draw(node: GNode) {
        var str = node.str
        if node.kind == .T {
            str = "\"" + str + "\""
        }
//        d.append("\n    \(node.number) [label = <\(node.number)<br/><font color=\"gray\" point-size=\"8.0\"> \(node.kind) \(str)</font>>]")
        d.append("\n    \(node.number) [label = <\(node.number)<br/>\(node.kind) \(str)<br/>fi \(node.first.sorted())<br/>fo \(node.follow.sorted())<br/>am \(node.ambiguous.sorted())>]")
        if let alt = node.alt {
            if node.kind == .END {
                crosslinks.append((from: node, to: alt))
            } else if node.kind == .N && node.seq != nil { // rhs nonterminal
                crosslinks.append((from: node, to: alt))
            } else {
                d.append("\n    \(node.number) -> \(alt.number) {rank = same; \(node.number); \(alt.number);}")
                draw(node: alt)
            }
        }
        if let seq = node.seq {
            if node.kind == .END {
                crosslinks.append((from: node, to: seq))
            } else {
                d.append("\n    \(node.number) -> \(seq.number) [weight=100]")
                draw(node: seq)
            }
        }
    }
    
    for (name, node) in _nonTerminals {
        d.append("\n  subgraph cluster\(name) {")
//        d.append("\n    cluster = true")
        d.append("\n    node [shape = box]")
        d.append("\n    label = <\(node.ebnf().graphvizHTML)>")
        d.append("\n    labeljust = l")
        draw(node: node)
        d.append("\n  }")
    }
    
    for (from, to) in crosslinks {
        d.append("\n  \(from.number):e -> \(to.number) [style = dotted, color = red, constraint = false]")
    }
    
    d.append("\n}")
    
    do {
        try d.write(to: diagramFileURL, atomically: true, encoding: .utf8)
    } catch {
        print("error: could not write to \(diagramFileURL.absoluteString)")
        exit(6)
    }
}

//enum GKind { case EOS, T, EPS, N, ALT, END }
//enum GKind2 { case EOS, T, TI, C, B, EPS, N, ALT, END, DO, OPT, POS, KLN }
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

extension GNode {
    func ebnf() -> String {
        var s = ""
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            s += "\"" + str + "\" "
            if let seq { s += seq.ebnf() }
            // TODO: fix a better string for terminals
            //            if let t = _terminals[kind] {
            //                s.append(t.source)
            //            }
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

