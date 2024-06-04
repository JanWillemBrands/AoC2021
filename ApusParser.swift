//
//  ApusParser.swift
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
    trace("parseApusGrammar", token)
    expect(["identifier", "message"])
    while token.kind == "identifier" {
        production()
    }
    // TODO: change ¶ into $ to match ART
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
            node = alternates()
            if let existing = nonTerminals[nonTerminalName] {
                nonTerminals[nonTerminalName] = GrammarNode(.ALT(children: [existing, node]))
            } else {
                nonTerminals[nonTerminalName] = node
            }
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
    // TODO:  this causes the terminals to end up in the nonterminals
//    if let existing = nonTerminals[nonTerminalName] {
//        nonTerminals[nonTerminalName] = GrammarNode(.ALT(children: [existing, node]))
//    } else {
//        nonTerminals[nonTerminalName] = node
//    }
    expect(["."])
    next()
}

func message() {
    trace("message", token)
    messages.append(token.stripped)
    next()
}

func alternates() -> GrammarNode {
    trace("alternates", token)
    var nodes: [GrammarNode] = []
    nodes.append(sequence())
    while token.kind == "|" {
        next()
        nodes.append(sequence())
    }
    if nodes.count == 1 {
        return nodes[0]
    } else {
        return GrammarNode(.ALT(children: nodes))
    }
}

func sequence() -> GrammarNode {
    trace("sequence", token)
    var nodes: [GrammarNode] = []
    nodes.append(term())
    while ["literal", "identifier", "regex", "action", "(", "[", "{", "<"].contains(token.kind) {
        nodes.append(term())
    }
    if nodes.count == 1 {
        return nodes[0]
    } else {
        return GrammarNode(.SEQ(children: nodes))
    }
}

func regex() -> GrammarNode {
    // TODO: insert lineposition name?
    let name = terminalAlias ?? input.linePosition(of: token.range.lowerBound)
//    let name = terminalAlias ?? String(token.image)
    if let definition = terminals[name] {
        if definition.isSkip != skip {
            print("warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
        }
    }
    do {
        let r = try Regex<Substring>(String(token.stripped))
        terminals[name] = (String(token.image), r, false, skip)
        trace("regex name:", name, "image", token.image)
    } catch {
        print("error: \(token.image) is not a valid /regex/")
        exit(9)
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
        terminals[name] = (String(token.image), r, true, skip)
        trace("literal name:", name, "image:", token.image)
    } catch {
        print("error: \(token.image) is not a valid \"literal\"")
        exit(8)
    }
    return GrammarNode(.TRM(type: name))
}

func term() -> GrammarNode {
    trace("term", token)
    var node: GrammarNode
    switch token.kind {
    case "identifier":
        node = GrammarNode(.NTR(name: token.stripped))
    case "literal":
        node = literal()
    case "regex":
        // TODO: add support for anonymous regexes
        node = regex()
    case "action":
        node = GrammarNode(.TRM(type: "action"))
        actionList[node] = token.stripped
    case "(":
        next()
        node = alternates()
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
        node = GrammarNode(.OPT(child: alternates()))
        expect(["]"])
    case "{":
        next()
        node = GrammarNode(.REP(child: alternates()))
        expect(["}"])
    case "<":
        next()
        node = alternates()
        let repetition = GrammarNode(.REP(child: node))
        node = GrammarNode(.SEQ(children: [node, repetition]))
        expect([">"])
    default:
        expect(["identifier", "literal", "regex", "action", "(", "[", "{", "<"])
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

