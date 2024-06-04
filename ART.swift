//
//  ART.swift
//  Advent
//
//  Created by Johannes Brands on 20/05/2024.
//

import Foundation

final class GNode: Hashable {
    let ni: Int
    let kind: GKind
    let str: String
    var alt, seq: GNode?
    
    static var gCount = 0
    
    init(kind: GKind, str: String, alt: GNode? = nil, seq: GNode? = nil) {
        self.ni = GNode.gCount
        GNode.gCount += 1
        self.kind = kind
        self.str = str
        self.alt = alt
        self.seq = seq
    }
    
    static func == (lhs: GNode, rhs: GNode) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

var indent = 0
func tab() { for _ in 0..<indent { print(" ", terminator: "")}}
extension GNode {
    func dump() {
        tab()
        print(kind, str)
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            seq?.dump()
        case .N, .ALT, .DO, .OPT, .POS, .KLN:
            seq?.dump()
            indent += 2
            alt?.dump()
        case .END:
            break
        }
    }
}

//enum GKind { case EOS, T, EPS, N, ALT, END }
enum GKind { case EOS, T, TI, C, B, EPS, N, ALT, END, DO, OPT, POS, KLN }

var _skip = false

var _terminalAlias: String?

var _nonTerminals: [String:GNode] = [:]
var _terminals: [String:TokenPattern] = [:]
var _messages: [String] = []

var rules: [GNode] = []

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
    tmp.seq?.alt = startOfSequence
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
        d.append("\n    \(node.ni) [label = <\(node.ni)<br/><font color=\"gray\" point-size=\"8.0\"> \(node.kind) \(node.str)</font>>]")
        if let alt = node.alt {
            if node.kind == .END {
                crosslinks.append((from: node, to: alt))
            } else {
                d.append("\n    \(node.ni) -> \(alt.ni) {rank = same; \(node.ni); \(alt.ni);}")
                draw(node: alt)
            }
        }
        if let seq = node.seq {
            if node.kind == .END {
                crosslinks.append((from: node, to: seq))
            } else {
                d.append("\n    \(node.ni) -> \(seq.ni)")
                draw(node: seq)
            }
        }
    }

    for (name, node) in _nonTerminals {
        d.append("\n    node [shape = box]")
//        d.append("\n    label = \(name)")
        d.append("\n    label = <\(name) =\(node.alt!.ebnf().graphvizHTML).>")
        draw(node: node)
    }
    
//    for (from, to) in crosslinks {
//        d.append("\n  \(from.ni):e -> \(to.ni):e [style = dotted, constraint = false]")
//    }
    
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
 T      terminal (singleton case sensitive)
 TI     terminal (singleton case insensitive
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
 
 END.seq references start of this production
 END.alt references start of alternate
 Extends naturally to EBNF brackets if END.alt references the enclosing bracket
 */

extension GNode {
    func ebnf() -> String {
        var s = ""
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            s.append(str)
            // TODO: fix a better string for terminals
//            if let t = _terminals[kind] {
//                s.append(t.source)
//            }
        case .N:
            s.append(str)
        case .ALT:
            break
        case .END:
            break
        case .DO:
            s.append("(")
            if let alt { s.append(alt.ebnf()) }
            s.append(")")
        case .OPT:
            s.append("[")
            if let alt { s.append(alt.ebnf()) }
            s.append("]")
        case .POS:
            s.append("<")
            if let alt { s.append(alt.ebnf()) }
            s.append(">")
        case .KLN:
            s.append("{")
            if let alt { s.append(alt.ebnf()) }
            s.append("}")
        }
        if let seq {
            s.append(" ")
            s.append(seq.ebnf())
        }
        if let alt, case .ALT = kind {
            s.append("|")
            s.append(alt.ebnf())
        }
        return s
    }
}
