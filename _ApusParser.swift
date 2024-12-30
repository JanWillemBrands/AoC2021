//
//  _ApusParser.swift
//  Advent
//
//  Created by Johannes Brands on 03/10/2024.
//

import Foundation

var _skip = false

var _terminalAlias: String?

var _nonTerminals: [String:_GrammarNode] = [:]
var _terminals: [String:TokenPattern] = [:]
var _messages: [String] = []

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
    var node: _GrammarNode
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
                _nonTerminals[nonTerminalName] = _GrammarNode(kind: .N, str: nonTerminalName, alt: node)
            }
        }
    } else {
        expect([":"])
        next()
        _skip = true
        _terminalAlias = nonTerminalName
        if token.kind == "regex" {
            node = _regex()
        } else {
            expect(["literal"])
            node = _literal()
        }
        _skip = false
        _terminalAlias = nil
        next()
    }
    // TODO: do we really want regex and literal terminals also listed as nonTerminals?
    // TODO:  this causes the terminals to end up in the nonterminals
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
    _messages.append(token.stripped)
    next()
}

func _alternates() -> _GrammarNode {
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

func _sequence() -> _GrammarNode {
    trace("sequence", token)
    let startOfSequence = _GrammarNode(kind: .ALT, str: "")
    var tmp = _term()
    startOfSequence.seq = tmp
    while ["literal", "identifier", "regex", "(", "[", "{", "<"].contains(token.kind) {
        tmp.seq = _term()
        tmp = tmp.seq!
    }
    tmp.seq = _GrammarNode(kind: .END, str: "")
    // Setting the .alt and .seq links of an END node is done in resolveEndNodeLinks
    return startOfSequence
}

func _regex() -> _GrammarNode {
    trace("regex", token)
    // TODO: insert lineposition name?
    let name = _terminalAlias ?? input.linePosition(of: token.range.lowerBound)
    
    //    let name = _terminalAlias ?? String(token.image)
    if _terminals[name] != nil {
        print("warning: redefinition of \(name) as \(_skip ? "skipped" : "not skipped")")
    }
    do {
        let regex = try Regex<Substring>(String(token.stripped))
        // TODO: why is the name not 'name'?
        _terminals[name] = (String(token.image), regex, false, _skip)
        trace("regex name:", name, "image:", token.image)
    } catch {
        print("error: \(token.image) is not a valid /regex/")
        exit(9)
    }
    return _GrammarNode(kind: .T, str: name)
}

func _literal() -> _GrammarNode {
    trace("literal", token)
    let name = _terminalAlias ?? token.stripped
    if _terminals[name] != nil {
        print("warning: redefinition of \(name) as \(_skip ? "skipped" : "not skipped")")
    }
    do {
        let regex = try Regex<Substring>(String(token.stripped))
        _terminals[name] = (String(token.image), regex, true, _skip)
        trace("literal name:", name, "image:", token.image)
    } catch {
        print("error: \(token.image) is not a valid \"literal\"")
        exit(8)
    }
    return _GrammarNode(kind: .T, str: name)
}

func _term() -> _GrammarNode {
    trace("term", token)
    var node: _GrammarNode
    switch token.kind {
    case "identifier":
        node = _GrammarNode(kind: .N, str: token.stripped)
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
            node = _GrammarNode(kind: .DO, str: "", alt: node)
        case ")?":
            node = _GrammarNode(kind: .OPT, str: "", alt: node)
        case ")*":
            node = _GrammarNode(kind: .KLN, str: "", alt: node)
        case ")+":
            node = _GrammarNode(kind: .POS, str: "", alt: node)
        default:
            expect([")", ")?", ")+", ")*"])
            exit(7)
        }
    case "[":
        next()
        node = _GrammarNode(kind: .OPT, str: "", alt: _alternates())
        expect(["]"])
    case "{":
        next()
        node = _GrammarNode(kind: .KLN, str: "", alt: _alternates())
        expect(["}"])
    case "<":
        next()
        node = _GrammarNode(kind: .POS, str: "", alt: _alternates())
        expect([">"])
    default:
        expect(["identifier", "literal", "regex", "(", "[", "{", "<"])
        exit(7)
    }
    next()
    return node
}

func expect(_ expectedTokens: Set<String>) {
    trace("expect '\(token.kind)' to be in", expectedTokens)
    if !expectedTokens.contains(token.kind) {
        print("error: found '\(token.kind)' but expected one of \(expectedTokens)")
        print(token.image, token.image.endIndex > input.endIndex )
        let lineRange = input.lineRange(for: token.image.startIndex ..< token.image.endIndex)
        print(input[lineRange], terminator: "")
        let before = lineRange.lowerBound ..< token.image.startIndex
        for _ in 0 ..< input[before].count {
            print("~", terminator: "")
        }
        for _ in 0 ..< token.image.count {
            print("^", terminator: "")
        }
        print()
        exit(10)
    }
}
