//
//  ApusParser.swift
//  Advent
//
//  Created by Johannes Brands on 23/12/2024.
//

import OSLog
import Foundation
import RegexBuilder
import AdventMacros

enum ApusParserError: Error {
    case terminalNonterminalConflict(symbols: Set<String>)
    case invalidRegex(image: String, error: Error)
    case unexpectedToken(expected: [String], found: String)
    case scanningFailed(error: Error)
    case undefinedNonTerminal(name: String, definedAsTerminal: Bool)
    case startSymbolNotFound(name: String)
}

class ApusParser {
    
    let grammar = Grammar()
    var scanner: Scanner
    var tokens: [Token] { scanner.tokens }
    var cI: Int = 0               // current input position
    var token: Token { tokens[cI] }
    
    init(fromString inputString: String) throws {
        scanner = try Scanner(fromString: inputString, patterns: apusTerminals)
    }
    
    init(fromFile inputFileURL: URL) throws {
        // Define a list of commonly supported encodings
        let encodings: [String.Encoding] = [
            .utf8,                // UTF-8
            .macOSRoman,          // Mac Roman (classic Mac OS encoding) PUT HIGH ON THE LIST BECAUSE OF PILCROW QUIRK
            .isoLatin1,           // ISO-8859-1 (Western European)
            .isoLatin2,           // ISO-8859-2 (Central/Eastern European)
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
        
        var input = ""
        for encoding in encodings {
            do {
                input = try String(contentsOf: inputFileURL, encoding: encoding)
                #Trace("Successfully read input file with \(encoding)")
                break
            } catch {
                #Trace("Failed reading input file with \(encoding): \(error)")
            }
        }
        
        scanner = try Scanner(fromString: input, patterns: apusTerminals)
    }
    
    func parse(explicitStartSymbol: String = "") throws -> Grammar {
        cI = 0
        
        grammar.startSymbol = explicitStartSymbol
        try parseApusGrammar()
        
        trace = false
        #Trace("terminals: \(grammar.terminals.count)")
        for (name, tokenPattern) in grammar.terminals {
            #Trace("\t", name, "\t", tokenPattern.source)
        }
        #Trace("nonTerminals:")
        for (name, node) in grammar.nonTerminals {
            #Trace("\t", name, "\t", node.kind)
        }
        
        let conflictSet = Set(grammar.terminals.keys).intersection(Set(grammar.nonTerminals.keys))
        if !conflictSet.isEmpty {
            #Trace("grammar parser error: the following symbols have been defined as both terminal and nontermimal:", conflictSet)
            throw ApusParserError.terminalNonterminalConflict(symbols: conflictSet)
        }
        
        guard let root = grammar.nonTerminals[grammar.startSymbol] else {
            throw ApusParserError.startSymbolNotFound(name: grammar.startSymbol)
        }
        grammar.root = root
        
        for (name, node) in grammar.nonTerminals.sorted(by: { $0.key > $1.key }) {      // a fixed ordering with 'S' appearing first in small test grammars
            #Trace("Processing END nodes for:", name)
            node.resolveEndNodeLinks(parent: node, alternate: node.alt)
        }
        
        // TODO: finalize representation for EOS
        grammar.root.follow.insert("$")
        grammar.finalizeSymbolTable()
        grammar.assignNameIDs()
        trace = false
        #Trace("start symbol '\(grammar.startSymbol)' first:", grammar.root.first, "follow:", grammar.root.follow)
        
        trace = false
        var oldSize = 0
        var newSize = 0
        repeat {
            oldSize = newSize
            newSize = 0
            for (_, node) in grammar.nonTerminals {
                #Trace("nonterminalcount", grammar.nonTerminals.count)
                GrammarNode.sizeofSets = 0
                try grammar.populateFirstFollowSets(for: node)
                newSize += GrammarNode.sizeofSets
            }
            #Trace("first & follow", newSize)
        } while newSize != oldSize
        // store the cumulative set size
        GrammarNode.sizeofSets = newSize
        
        GrammarNode.isLL1 = true
        for (name, node) in grammar.nonTerminals {
            #Trace("Detecting ambiguity for:", name)
            node.detectAmbiguity()
        }
        grammar.isLL1 = GrammarNode.isLL1
        grammar.populateBitSets()
        
        return grammar
    }
    
    private var skip = false
    private var terminalAlias: String?
    
    func parseApusGrammar() throws {
        #Trace("parseApusGrammar", token)
        
        // Collect preamble actions (before first production)
        grammar.preamble = collectActions(at: 0)
        
        try expect(["identifier"])
        repeat {
            try production()
        } while token.kind == "identifier"
        
        // Collect epilogue actions (after last production, before messages/$)
        grammar.epilogue = collectActions(at: cI)
        
        try expect(["message", "$"])
        while token.kind == "message" {
            message()
        }
        
        try expect(["$"])
    }
    
    func production() throws {
        #Trace("production", token)
        let nonTerminalName = String(token.image)
        cI += 1
        
        if token.kind == ":" || token.kind == "-" {
            // terminal definition: ":" = silent, "-" = visible
            skip = (token.kind == ":")
            cI += 1
            try expect(["regex"])
            terminalAlias = nonTerminalName
            _ = try regex()
            // reset
            terminalAlias = nil
            skip = false
        } else {
            // production rule
            try expect(["="])
            // Collect signature actions (between nonterminal name and "=")
            let signatureActions = collectActions(at: cI)
            cI += 1
            // Actions between "=" and body naturally land on the first ALT node
            // via sequence()'s collectActions(at: cI) — no separate locals collection needed.
            if grammar.startSymbol == "" {
                grammar.startSymbol = nonTerminalName
            }
            let node = try selection()
            let lhsNode: GrammarNode
            if let existing = grammar.nonTerminals[nonTerminalName] {
                var endOfList = existing
                while let next = endOfList.alt {
                    endOfList = next
                }
                endOfList.alt = node
                lhsNode = existing
            } else {
                lhsNode = GrammarNode(kind: .N, name: nonTerminalName, alt: node)
                grammar.nonTerminals[nonTerminalName] = lhsNode
            }
            // Store signature on the LHS .N node
            if let sig = signatureActions.first {
                lhsNode.signature = sig
            }
        }
        
        try expect(["."])
        cI += 1
    }
    
    func message() {
        #Trace("message", token)
        grammar.messages.append(token.stripped)
        cI += 1
    }
    
    func selection() throws -> GrammarNode {
        #Trace("selection", token)
        let startOfAlternates = try sequence()
        var tmp = startOfAlternates
        while token.kind == "|" {
            cI += 1
            tmp.alt = try sequence()
            tmp = tmp.alt!
        }
        return startOfAlternates
    }
    
    /// Collect action tokens from the skipped tokens at the given visible-token index.
    /// Since action is now a silent terminal, action tokens land in scanner.skippedTokens.
    private func collectActions(at index: Int) -> [String] {
        guard index < scanner.skippedTokens.count else { return [] }
        return scanner.skippedTokens[index]
            .filter { $0.kind == "action" }
            .map { $0.stripped }
    }
    
    func sequence() throws -> GrammarNode {
        // sequence = < factor [ "?" | "*" | "+" ] > .
        // Actions are collected from skippedTokens at each position.
        #Trace("sequence", token)
        let startOfSequence = GrammarNode(kind: .ALT, name: "")
        var termNode = startOfSequence
        
        // leading actions (before first factor)
        termNode.actions = collectActions(at: cI)
        
        repeat {
            termNode.seq = try factor()
            // handle postfix EBNF operators
            if ["?", "*", "+"].contains(token.kind) {
                // wrap the preceding factor in its own little sequence
                let miniSeq = GrammarNode(kind: .ALT, name: "")
                miniSeq.seq = termNode.seq
                miniSeq.seq?.seq = GrammarNode(kind: .END, name: "")
                if token.kind == "?" {
                    termNode.seq = GrammarNode(kind: .OPT, name: "", alt: miniSeq)
                } else if token.kind == "*" {
                    termNode.seq = GrammarNode(kind: .KLN, name: "", alt: miniSeq)
                } else if token.kind == "+" {
                    termNode.seq = GrammarNode(kind: .POS, name: "", alt: miniSeq)
                }
                termNode.seq?.alt = miniSeq
                cI += 1
            }
            
            termNode = termNode.seq!
            // trailing actions (after factor/operator, before next factor or end)
            termNode.actions = collectActions(at: cI)

        } while ["literal", "identifier", "epsilon", "regex", "(", "[", "{", "<"].contains(token.kind)
        
        termNode.seq = GrammarNode(kind: .END, name: "")
        // the .alt and .seq links of an END node are set in resolveEndNodeLinks()
        return startOfSequence
    }
    
    func regex() throws -> GrammarNode {
        #Trace("regex", token)
        let name = terminalAlias ?? scanner.input.linePosition(of: token.image.startIndex)
        
        if let definition = grammar.terminals[name] {
            if definition.isSkip != skip {
                #Trace("parse warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
            }
        }
        do {
            // the token is a regex definition, try to initialize a Regex with it
            let regex = try Regex<Substring>(String(token.stripped))
            grammar.terminals[name] = (String(token.image), regex, false, skip)
            grammar.registerTerminal(name)
            #Trace("regex name:", name, "image:", token.image)
        } catch {
            #Trace("grammar parse error: \(token.image) is not a valid literal Regex \(error)")
            throw ApusParserError.invalidRegex(image: String(token.image), error: error)
        }
        
        cI += 1
        return GrammarNode(kind: .T, name: name)
    }
    
    func literal() -> GrammarNode {
        #Trace("literal", token, token.stripped)
        
        if token.stripped == "" {
            // epsilon is its own terminal, will never show up here in literal()
            #Trace(token, token.stripped)
            cI += 1
            return GrammarNode(kind: .EPS, name: "ε")
        }
        
        let name = terminalAlias ?? token.stripped
        if let definition = grammar.terminals[name] {
            if definition.isSkip != skip {
                #Trace("parse warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
            }
        }
        // the token is a string literal, use a regex builder to create a Regex
        let regex = Regex { token.stripped }
        grammar.terminals[name] = (String(token.image), regex, true, skip)
        grammar.registerTerminal(name)
        #Trace("literal name:", name, "image:", token.image)
        
        cI += 1
        return GrammarNode(kind: .T, name: name)
    }
    
    func epsilon() -> GrammarNode {
        #Trace("epsilon", token, token.stripped)
        cI += 1
        return GrammarNode(kind: .EPS, name: "ε")
    }
    
    func factor() throws -> GrammarNode {
        #Trace("factor", token)
        let node: GrammarNode
        switch token.kind {
        case "identifier":
            // the identifier can be a terminal or nonTerminal but not both
            if grammar.terminals[String(token.image)] != nil {
                if grammar.nonTerminals[String(token.image)] != nil {
                    #Trace("grammar parse error: \(token.image) is both a terminal and a nonTerminal")
                }
                // this string was defined previously as a terminal
                // TODO: currently all terminals must be defined BEFORE they are used
                node = GrammarNode(kind: .T, name: token.stripped)
            } else {
                // this string is assumed to be a nonTerminal
                // nonTerminals may be used before they are defined, and are resolved later
                node = GrammarNode(kind: .N, name: token.stripped)
            }
            cI += 1
        case "literal":
            node = literal()
        case "epsilon":
            node = epsilon()
        case "regex":
            node = try regex()
        case "(":
            cI += 1
            node = GrammarNode(kind: .DO, name: "", alt: try selection())
            try expect([")"])
            cI += 1
        case "[":
            cI += 1
            node = GrammarNode(kind: .OPT, name: "", alt: try selection())
            try expect(["]"])
            cI += 1
        case "{":
            cI += 1
            node = GrammarNode(kind: .KLN, name: "", alt: try selection())
            try expect(["}"])
            cI += 1
        case "<":
            cI += 1
            node = GrammarNode(kind: .POS, name: "", alt: try selection())
            try expect([">"])
            cI += 1
        default:
            try expect(["identifier", "literal", "epsilon", "regex", "(", "[", "{", "<"])
            fatalError("expect() should have thrown - this line should never be reached")
        }
        return node
    }
    
    func expect(_ expectedTokens: Set<String>) throws {
        #Trace("expect \"\(token.kind)\" to be in", expectedTokens)
        if !expectedTokens.contains(token.kind) {
            #Trace("parse error: found \"\(token.kind)\" but expected one of \(expectedTokens)")
            #Trace(token.image, token.image.endIndex > scanner.input.endIndex )
            let lineRange = scanner.input.lineRange(for: token.image.startIndex ..< token.image.endIndex)
            #Trace(scanner.input[lineRange], terminator: "")
            let before = lineRange.lowerBound ..< token.image.startIndex
            for _ in 0 ..< scanner.input[before].count {
                #Trace("~", terminator: "")
            }
            for _ in 0 ..< token.image.count {
                #Trace("^", terminator: "")
            }
            #Trace()
            throw ApusParserError.unexpectedToken(expected: Array(expectedTokens), found: String(token.kind))
        }
    }
    
}
