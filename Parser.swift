//
//  Parser.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import Foundation

var skip = false

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

func parseApusGrammar() {
    trace("parseGrammar", token)
//    next()
    expect(["identifier", "message"])
    while token.kind == "identifier" {
        production()
    }
    expect(["message"])
    while token.kind == "message" {
        message()
    }
}

func production() {
    trace("production", token)
    let nonTerminalName = String(token.image)
    next()
    var node: GrammarNode
    if token.kind == "=" {
        next()
        if token.kind == "regex" {
            terminalAlias = nonTerminalName
            node = regex()
            terminalAlias = nil
            next()
        } else {
            node = selection()
        }
    } else {
        expect([":"])
        next()
        skip = true
        terminalAlias = nonTerminalName
        if token.kind == "regex" {
            node = regex()
        } else {
            expect(["literal"])
            node = literal()
        }
        skip = false
        terminalAlias = nil
        next()
    }
    if let existing = nonTerminals[nonTerminalName] {
        nonTerminals[nonTerminalName] = GrammarNode(.ALT(children: [existing, node]))
    } else {
        nonTerminals[nonTerminalName] = node
    }
    expect(["."])
    next()
}

func message() {
    trace("message", token)
    messages.append(token.stripped)
    next()
}

func selection() -> GrammarNode {
    trace("selection", token)
    var nodes: [GrammarNode] = []
    nodes.append(factor())
    while token.kind == "|" {
        next()
        nodes.append(factor())
    }
    if nodes.count == 1 {
        return nodes[0]
    } else {
        return GrammarNode(.ALT(children: nodes))
    }
}

func factor() -> GrammarNode {
    trace("factor", token)
    var nodes: [GrammarNode] = []
    nodes.append(term())
    while ["literal", "identifier", "action", "leftParenthesis", "[", "{", "<"].contains(token.kind) {
        nodes.append(term())
    }
    if nodes.count == 1 {
        return nodes[0]
    } else {
        return GrammarNode(.SEQ(children: nodes))
    }
}

func regex() -> GrammarNode {
    let name = terminalAlias ?? String(token.image)
    if let definition = terminals[name] {
        if definition.isSkip != skip {
            print("warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
        }
    }
    do {
        let r = try Regex<Substring>(String(token.stripped))
        print("success", token.image)
        terminals[name] = (String(token.image), r, false, skip)
        trace("regex name:", name, "image", token.image)
    } catch {
        print("ERROR: \(token.image) is not a valid /regex/")
        exit(4)
    }
    return GrammarNode(.TRM(type: name))
}

func literal() -> GrammarNode {
    let name = terminalAlias ?? token.stripped
    if let definition = terminals[name] {
        if definition.isSkip != skip {
            print("warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
        }
    }
    do {
        let r = try Regex<Substring>(String(token.stripped))
        print("success", token.image)
        terminals[name] = (String(token.image), r, true, skip)
        trace("literal name:", name, "image:", token.image)
    } catch {
        print("ERROR: \(token.image) is not a valid \"literal\"")
        exit(4)
    }
    return GrammarNode(.TRM(type: name))
}

//func regex() -> GrammarNode {
//    let name = terminalAlias ?? String(token.image)
//    if let definition = terminals[name] {
//        if definition.muted != muted {
//            print("warning: redefinition of \(name) as\(muted ? " " : " not ")muted")
//        }
//    }
//    // TODO: add new regexes to the back of the terminal list
//    terminals[name] = (token.stripped, true, muted)
//    trace("regex name:", name, "guts:", token.stripped)
//    return GrammarNode(.TRM(type: name))
//}
//
//func literal() -> GrammarNode {
//    let name = terminalAlias ?? token.stripped
//    if let definition = terminals[name] {
//        if definition.muted != muted {
//            print("warning: redefinition of \(name) as\(muted ? " " : " not ")muted")
//        }
//    }
//    // TODO: add new literals to the front of the terminal list
//    terminals[name] = (token.stripped, false, muted)
//    trace("literal name:", name, "guts:", token.stripped)
//    return GrammarNode(.TRM(type: name))
//}
//
func term() -> GrammarNode {
    trace("term", token)
    var node: GrammarNode
    switch token.kind {
    case "identifier":
        node = GrammarNode(.NTR(name: token.stripped))
    case "literal":
        node = literal()
    case "action":
        node = GrammarNode(.TRM(type: "action"))
        actionList[node] = token.stripped
    case "(":
        next()
        node = selection()
        switch token.kind {
        case ")": break
        case ")?":
            node = GrammarNode(.OPT(child: node))
        case ")*":
            node = GrammarNode(.REP(child: node))
        case ")+":
            let repetition = GrammarNode(.REP(child: node))
            node = GrammarNode(.SEQ(children: [node, repetition]))
        default:
            expect([")", ")?", ")+", ")*"])
        }
    case "[":
        next()
        node = GrammarNode(.OPT(child: selection()))
        expect(["]"])
    case "{":
        next()
        node = GrammarNode(.REP(child: selection()))
        expect(["}"])
    case "<":
        next()
        node = selection()
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
