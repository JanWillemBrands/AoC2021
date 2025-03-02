//
//  GrammarParser.swift
//  Advent
//
//  Created by Johannes Brands on 23/12/2024.
//

import Foundation

// input is the string that's being scanned and parsed
var input: String = ""

var terminals: [String:TokenPattern] = [:]
var nonTerminals: [String:GrammarNode] = [:]
var messages: [String] = []

class GrammarParser {
    
    init(inputFile inputFileURL: URL, patterns: [String:TokenPattern]) throws {
        input = try String(contentsOf: inputFileURL, encoding: .utf8)
        initScanner(fromString: input, patterns: patterns)

        terminals = [:]
        nonTerminals = [:]
        messages = []
    }
    
    func parseGrammar(startSymbol: String) -> GrammarNode? {
        initScanner(fromString: input, patterns: apusTerminals)

        parseApusGrammar()
        
        trace("terminals:")
        for (name, tokenPattern) in terminals {
            trace("\t", name, "\t", tokenPattern.source)
        }
        
        trace("nonTerminals:")
        for (name, node) in nonTerminals {
            trace("\t", name, "\t", node.kind)
        }
        
        guard let root = nonTerminals[startSymbol] else { return nil }
        
        for (name, node) in nonTerminals {
            trace("Processing END nodes for:", name)
            node.resolveEndNodeLinks(parent: node, alternate: node.alt)
        }
        
        // TODO: finalize representation for EOS
        root.follow.insert("$")
        trace = false
        trace("start symbol '\(startSymbol)' first:", root.first, "follow:", root.follow)
        
        var oldSize = 0
        var newSize = 0
        repeat {
            oldSize = newSize
            newSize = 0
            for (_, node) in nonTerminals {
                GrammarNode.sizeofSets = 0
                node.populateFirstFollowSets()
                newSize += GrammarNode.sizeofSets
            }
            trace("first & follow", newSize)
        } while newSize != oldSize
        
        for (name, node) in nonTerminals {
            trace("Detecting ambiguity for:", name)
            node.detectAmbiguity()
        }
        
        return root
    }
    
    private var skip = false
    private var terminalAlias: String?

    func parseApusGrammar() {
        trace("parseApusGrammar", token)
        expect(["identifier", "message"])
        while token.kind == "identifier" {
            production()
        }
        expect(["message", "¶"])
        while token.kind == "message" {
            message()
        }
        // TODO: finalize EOS representation
        expect(["$"])
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
                    // add this production to the end of the existing ALT list
                    var endOfList = existing
                    while let next = endOfList.alt {
                        endOfList = next
                    }
                    endOfList.alt = node
                } else {
                    nonTerminals[nonTerminalName] = GrammarNode(kind: .N, str: nonTerminalName, alt: node)
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
        // TODO: do we really want regex and literal terminals also listed as nonTerminals?
        // TODO:  this causes the terminals to end up in the nonterminals
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
        let startOfAlternates = sequence()
        var tmp = startOfAlternates
        while token.kind == "|" {
            next()
            tmp.alt = sequence()
            tmp = tmp.alt!
        }
        return startOfAlternates
    }

    func sequence() -> GrammarNode {
        trace("sequence", token)
        let startOfSequence = GrammarNode(kind: .ALT, str: "")
        var tmp = term()
        startOfSequence.seq = tmp
        while ["literal", "identifier", "regex", "(", "[", "{", "<"].contains(token.kind) {
            tmp.seq = term()
            tmp = tmp.seq!
        }
        tmp.seq = GrammarNode(kind: .END, str: "")
        // Setting the .alt and .seq links of an END node is done in resolveEndNodeLinks
        return startOfSequence
    }

    func regex() -> GrammarNode {
        trace("regex", token)
        let name = terminalAlias ?? input.linePosition(of: token.range.lowerBound)
        
        if let definition = terminals[name] {
            if definition.isSkip != skip {
                print("warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
            }
        }
        do {
            // the token is a regex definition, try to initialize a Regex with it
            let regex = try Regex<Substring>(String(token.stripped))
            terminals[name] = (String(token.image), regex, false, skip)
            trace("regex name:", name, "image:", token.image)
        } catch {
            print("error: \(token.image) is not a valid /regex/")
            exit(9)
        }

        return GrammarNode(kind: .T, str: name)
    }

    func literal() -> GrammarNode {
        trace("literal", token, token.stripped)

        if token.stripped == "" || token.stripped.count == 1 && token.stripped.first!.isEpsilon {
            return GrammarNode(kind: .EPS, str: "")
        }
        
        let name = terminalAlias ?? token.stripped
        if let definition = terminals[name] {
            if definition.isSkip != skip {
                print("warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
            }
        }
        // the token is a string literal, use a regex builder to create a Regex
        let regex = Regex { token.stripped }
        terminals[name] = (String(token.image), regex, true, skip)
        trace("literal name:", name, "image:", token.image)

        return GrammarNode(kind: .T, str: name)
    }

    func term() -> GrammarNode {
        trace("term", token)
        var node: GrammarNode
        switch token.kind {
        case "identifier":
            if terminals[String(token.image)] != nil {
                // this string was defined previously as a terminal
                // TODO: currently all terminals must be defined BEFORE they are used
                node = GrammarNode(kind: .T, str: token.stripped)
            } else {
                // this string is assumed to be a nonTerminal
                // nonTerminals may be used before they are defined, and are resolved later
                node = GrammarNode(kind: .N, str: token.stripped)
            }
        case "literal":
            node = literal()
        case "regex":
            // TODO: add support for anonymous regexes
            node = regex()
        case "(":
            next()
            node = alternates()
            switch token.kind {
            case ")":
                node = GrammarNode(kind: .DO, str: "", alt: node)
            case ")?":
                node = GrammarNode(kind: .OPT, str: "", alt: node)
            case ")*":
                node = GrammarNode(kind: .KLN, str: "", alt: node)
            case ")+":
                node = GrammarNode(kind: .POS, str: "", alt: node)
            default:
                expect([")", ")?", ")+", ")*"])
                exit(7)
            }
        case "[":
            next()
            node = GrammarNode(kind: .OPT, str: "", alt: alternates())
            expect(["]"])
        case "{":
            next()
            node = GrammarNode(kind: .KLN, str: "", alt: alternates())
            expect(["}"])
        case "<":
            next()
            node = GrammarNode(kind: .POS, str: "", alt: alternates())
            expect([">"])
        default:
            expect(["identifier", "literal", "regex", "(", "[", "{", "<"])
            exit(7)
        }
        next()
        return node
    }
    
    func expect(_ expectedTokens: Set<String>) {
        trace("expect \"\(token.kind)\" to be in", expectedTokens)
        if !expectedTokens.contains(token.kind) {
            print("error: found \"\(token.kind)\" but expected one of \(expectedTokens)")
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

}
