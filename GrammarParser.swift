//
//  GrammarParser.swift
//  Advent
//
//  Created by Johannes Brands on 23/12/2024.
//

import Foundation
import RegexBuilder

public enum GrammarParserError: Error {
    case terminalNonterminalConflict(symbols: Set<String>)
    case invalidRegex(image: String, error: Error)
    case unexpectedToken(expected: [String], found: String)
    case scanningFailed(error: Error)
    case undefinedNonTerminal(name: String, definedAsTerminal: Bool)
}

// input is the string that's being scanned and parsed
public var input: String = ""

public var startSymbol: String = ""

public var terminals: [String:TokenPattern] = [:]
public var nonTerminals: [String:GrammarNode] = [:]
public var messages: [String] = []

public class GrammarParser {
    
    public init(inputFile inputFileURL: URL, patterns: [String:TokenPattern]) throws {
        // Define a list of commonly supported encodings
        let encodings: [String.Encoding] = [
            .utf8,                // UTF-8
            .macOSRoman,          // Mac Roman (classic Mac OS encoding) PUT HIGH ON THE LIST BECAUSE OF PILCROW QUIRK
            .isoLatin1,           // ISO-8859-1 (Western European)
            .isoLatin2,            // ISO-8859-2 (Central/Eastern European)
            .ascii,               // ASCII
            .utf16,               // UTF-16 (with BOM)
            .utf16BigEndian,      // UTF-16 Big Endian
            .utf16LittleEndian,   // UTF-16 Little Endian
            .utf32,               // UTF-32 (with BOM)
            .utf32BigEndian,      // UTF-32 Big Endian
            .utf32LittleEndian,   // UTF-32 Little Endian
            .windowsCP1250,       // Windows Central European
            .windowsCP1251,       // Windows Cyrillic
            .windowsCP1252,       // Windows Latin-1
            .windowsCP1253,       // Windows Greek
            .windowsCP1254,       // Windows Turkish
            // Add more encodings as needed via raw values below
        ]
        
        for encoding in encodings {
            do {
                input = try String(contentsOf: inputFileURL, encoding: encoding)
                print("Success with \(encoding)")
                break
            } catch {
                print("Failed with \(encoding): \(error)")
            }
        }
        
        try initScanner(fromString: input, patterns: patterns)
        
        terminals = [:]
        nonTerminals = [:]
        messages = []
    }
    
    public func parseGrammar(explicitStartSymbol: String = "") throws -> GrammarNode? {
        do {
            try initScanner(fromString: input, patterns: apusTerminals)
        } catch {
            throw GrammarParserError.scanningFailed(error: error)
        }

        if explicitStartSymbol != "" {
            startSymbol = explicitStartSymbol
        }
        try parseApusGrammar()
        
//        print("TERMINALS")
//        for t in terminals.keys.sorted() { print(t) }
//        print("NONTERMINALS")
//        for t in nonTerminals.keys.sorted() { print(t) }
        trace = false
        trace("terminals:")
        for (name, tokenPattern) in terminals {
            trace("\t", name, "\t", tokenPattern.source)
        }
        trace("nonTerminals:")
        for (name, node) in nonTerminals {
            trace("\t", name, "\t", node.kind)
        }

        let conflictSet = Set(terminals.keys).intersection(Set(nonTerminals.keys))
        if !conflictSet.isEmpty {
            print("grammar parser error: the following symbols have been defined as both terminal and nontermimal:", conflictSet)
            throw GrammarParserError.terminalNonterminalConflict(symbols: conflictSet)
        }
            
        guard let root = nonTerminals[startSymbol] else { return nil }
        
        for (name, node) in nonTerminals.sorted(by: { $0.key > $1.key }) {      // a fixed ordering with 'S' appearing first in small test grammars
            trace("Processing END nodes for:", name)
            node.resolveEndNodeLinks(parent: node, alternate: node.alt)
        }
        
        // TODO: finalize representation for EOS
        root.follow.insert("$")
        trace = false
        trace("start symbol '\(startSymbol)' first:", root.first, "follow:", root.follow)
        
        trace = false
        var oldSize = 0
        var newSize = 0
        repeat {
            oldSize = newSize
            newSize = 0
            for (_, node) in nonTerminals {
                trace("nonterminalcount", nonTerminals.count)
                GrammarNode.sizeofSets = 0
                try node.populateFirstFollowSets()
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

    func parseApusGrammar() throws {
        trace("parseApusGrammar", token)
        
        while token.kind == "identifier" {
            try production()
        }
        
        try expect(["message", "$"])
        while token.kind == "message" {
            message()
        }
        // TODO: finalize EOS representation
        try expect(["$"])
    }

    func production() throws {
        trace("production", token)
        let nonTerminalName = String(token.image)
        next()
        var node: GrammarNode
        if token.kind == "=" {
            next()
            if token.kind == "regex" {
                terminalAlias = nonTerminalName
                node = try regex()
                terminalAlias = nil
                next()
            } else {
                // set the startSymbol to the first nonTerminal in the grammar file
                if startSymbol == "" {
                    startSymbol = nonTerminalName
                }
                node = try alternates()
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
            try expect([":"])
            next()
            skip = true
            terminalAlias = nonTerminalName
            if token.kind == "regex" {
                node = try regex()
            } else {
                try expect(["literal"])
                node = literal()
            }
            skip = false
            terminalAlias = nil
            next()
        }
        // TODO: do we really want regex and literal terminals also listed as nonTerminals?
        // TODO:  this causes the terminals to end up in the nonterminals
        try expect(["."])
        next()
    }

    func message() {
        trace("message", token)
        messages.append(token.stripped)
        next()
    }

    func alternates() throws -> GrammarNode {
        trace("alternates", token)
        let startOfAlternates = try sequence()
        var tmp = startOfAlternates
        while token.kind == "|" {
            next()
            tmp.alt = try sequence()
            tmp = tmp.alt!
        }
        return startOfAlternates
    }

    func sequence() throws -> GrammarNode {
        // TODO: is this correct?   sequence = < term [ "?" | "*" | "+" ] > .
        trace("sequence", token)
        let startOfSequence = GrammarNode(kind: .ALT, str: "")
        var termNode = startOfSequence
        
        repeat {
            if ["action"].contains(token.kind) {
                termNode.actions.append(token.stripped)
                next()
            } else if ["literal", "identifier", "regex", "(", "[", "{", "<"].contains(token.kind) {
                termNode.seq = try term()
                while ["action"].contains(token.kind) {
                    termNode.seq?.actions.append(token.stripped)
                    next()
                }
                // handle postfix EBNF operators
                if ["?", "*", "+"].contains(token.kind) {
                    // wrap the preceding term in its own little sequence
                    let miniSeq = GrammarNode(kind: .ALT, str: "")
                    miniSeq.seq = termNode.seq
                    miniSeq.seq?.seq = GrammarNode(kind: .END, str: "")
                    if token.kind == "?" {
                        termNode.seq = GrammarNode(kind: .OPT, str: "", alt: miniSeq)
                    } else if token.kind == "*" {
                        termNode.seq = GrammarNode(kind: .KLN, str: "", alt: miniSeq)
                    } else if token.kind == "+" {
                        termNode.seq = GrammarNode(kind: .POS, str: "", alt: miniSeq)
                    }
                    termNode.seq?.alt = miniSeq
                    next()
                }
                termNode = termNode.seq!
            }
        } while ["literal", "identifier", "regex", "action", "(", "[", "{", "<"].contains(token.kind)
        
        termNode.seq = GrammarNode(kind: .END, str: "")
        // the .alt and .seq links of an END node are set in resolveEndNodeLinks()
        return startOfSequence
    }

    func regex() throws -> GrammarNode {
        trace("regex", token)
        let name = terminalAlias ?? input.linePosition(of: token.image.startIndex)

        if let definition = terminals[name] {
            if definition.isSkip != skip {
                print("parse warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
            }
        }
        do {
            // the token is a regex definition, try to initialize a Regex with it
            let regex = try Regex<Substring>(String(token.stripped))
            terminals[name] = (String(token.image), regex, false, skip)
            trace("regex name:", name, "image:", token.image)
        } catch {
            print("grammar parse error: \(token.image) is not a valid literal Regex \(error)")
            throw GrammarParserError.invalidRegex(image: String(token.image), error: error)
        }

        return GrammarNode(kind: .T, str: name)
    }

    func literal() -> GrammarNode {
        trace("literal", token, token.stripped)

        if token.stripped == "" || token.stripped == "#" || token.stripped.first?.isEpsilon == true {
            return GrammarNode(kind: .EPS, str: "")
        }
        
        let name = terminalAlias ?? token.stripped
        if let definition = terminals[name] {
            if definition.isSkip != skip {
                print("parse warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
            }
        }
        // the token is a string literal, use a regex builder to create a Regex
        let regex = Regex { token.stripped }
        terminals[name] = (String(token.image), regex, true, skip)
        trace("literal name:", name, "image:", token.image)

        return GrammarNode(kind: .T, str: name)
    }

    func term() throws -> GrammarNode {
        trace("term", token)
        let node: GrammarNode
        switch token.kind {
        case "identifier":
            // the identifier can be a terminal or nonTerminal but not both
            if terminals[String(token.image)] != nil {
                if nonTerminals[String(token.image)] != nil {
                    print("grammar parse error: \(token.image) is both a terminal and a nonTerminal")
                }
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
            node = try regex()
        case "(":
            next()
            node = GrammarNode(kind: .DO, str: "", alt: try alternates())
            try expect([")"])
        case "[":
            next()
            node = GrammarNode(kind: .OPT, str: "", alt: try alternates())
            try expect(["]"])
        case "{":
            next()
            node = GrammarNode(kind: .KLN, str: "", alt: try alternates())
            try expect(["}"])
        case "<":
            next()
            node = GrammarNode(kind: .POS, str: "", alt: try alternates())
            try expect([">"])
        default:
            // This will throw, so we never reach the code below
            try expect(["identifier", "literal", "regex", "action", "(", "[", "{", "<"])
            fatalError("expect() should have thrown - this line should never be reached")
        }
        next()
        return node
    }
    
    func expect(_ expectedTokens: Set<String>) throws {
        trace("expect \"\(token.kind)\" to be in", expectedTokens)
        if !expectedTokens.contains(token.kind) {
            print("parse error: found \"\(token.kind)\" but expected one of \(expectedTokens)")
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
            throw GrammarParserError.unexpectedToken(expected: Array(expectedTokens), found: String(token.kind))
        }
    }

}
