//
//  Parser.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import Foundation

var muted = false

var terminalAlias: String?

var actionList: [GrammarNode:String] = [:]

var nonTerminals: [String:GrammarNode] = [:]
var terminals: [String:TokenPattern] = [:]
var messages: [String] = []

func initParser() {
    terminals = [:]
    nonTerminals = [:]
    messages = []
}

func _parseGrammar() {
    trace("_parseGrammar", token)
    next()
    while ["identifier",].contains(token.type) {
        _production()
    }
    while token.type != "" {
        _message()
    }
}

func _production() {
    trace("_production", token)
    expect(["identifier"])
    let nonTerminalName = token.image
    next()
    var node: GrammarNode
    if token.type == "=" {
        next()
        if token.type == "regex" {
            terminalAlias = nonTerminalName
            node = _regex()
            terminalAlias = nil
            next()
        } else {
            node = _selection()
        }
    } else {
        expect([":",])
        next()
        muted = true
        terminalAlias = nonTerminalName
        if token.type == "regex" {
            node = _regex()
        } else {
            expect(["literal"])
            node = _literal()
        }
        muted = false
        terminalAlias = nil
        next()
    }
    if let existing = nonTerminals[nonTerminalName] {
        nonTerminals[nonTerminalName] = GrammarNode(.ALT(children: [existing, node]))
    } else {
        nonTerminals[nonTerminalName] = node
    }
    expect([".",";"])
    next()
}

func _message() {
    trace("_message", token)
    messages.append(token.stripped)
    next()
}

func _selection() -> GrammarNode {
    trace("_selection", token)
    var nodes: [GrammarNode] = []
    nodes.append(_factor())
    while token.type == "|" {
        next()
        nodes.append(_factor())
    }
    if nodes.count == 1 {
        return nodes[0]
    } else {
        return GrammarNode(.ALT(children: nodes))
    }
}

func _factor() -> GrammarNode {
    trace("_factor", token)
    var nodes: [GrammarNode] = []
    nodes.append(_term())
    while ["literal", "identifier", "action", "(", "[", "{", "<", ].contains(token.type) {
        nodes.append(_term())
    }
    if nodes.count == 1 {
        return nodes[0]
    } else {
        return GrammarNode(.SEQ(children: nodes))
    }
}

func _regex() -> GrammarNode {
    let name = terminalAlias ?? token.image
    if let definition = terminals[name] {
        if definition.muted != muted {
            print("warning: redefinition of \(name) as\(muted ? " " : " not ")muted")
        }
    }
    terminals[name] = (token.stripped, true, muted)
    trace("_regex name:", name, "guts:", token.stripped)
    return GrammarNode(.TRM(type: name))
}

func _literal() -> GrammarNode {
    let name = terminalAlias ?? token.stripped
    if let definition = terminals[name] {
        if definition.muted != muted {
            print("warning: redefinition of \(name) as\(muted ? " " : " not ")muted")
        }
    }
    terminals[name] = (token.stripped, false, muted)
    trace("_literal name:", name, "guts:", token.stripped)
    return GrammarNode(.TRM(type: name))
}

func _term() -> GrammarNode {
    trace("_term", token)
    var node: GrammarNode
    switch token.type {
    case "identifier":
        node = GrammarNode(.NTR(name: token.stripped))
    case "literal":
        node = _literal()
    case "action":
        node = GrammarNode(.TRM(type: "action"))
        actionList[node] = token.stripped
    case "(":
        next()
        node = _selection()
        switch token.type {
        case ")": break
        case ")?":
            node = GrammarNode(.OPT(child: node))
        case ")*":
            node = GrammarNode(.REP(child: node))
        case ")+":
            let repetition = GrammarNode(.REP(child: node))
            node = GrammarNode(.SEQ(children: [node, repetition]))
        default:
            expect([")", ")?", ")*", ")+"])
        }
    case "[":
        next()
        node = GrammarNode(.OPT(child: _selection()))
        expect(["]"])
    case "{":
        next()
        node = GrammarNode(.REP(child: _selection()))
        expect(["}"])
    case "<":
        next()
        node = _selection()
        let repetition = GrammarNode(.REP(child: node))
        node = GrammarNode(.SEQ(children: [node, repetition]))
        expect([">"])
    default:
        expect(["identifier", "literal", "action", "(", "[", "{", "<"])
        exit(3)
    }
    next()
    return node
}
