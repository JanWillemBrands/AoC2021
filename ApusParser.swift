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
    case unexpectedToken(explanation: String)
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
        do {
            scanner = try Scanner(fromString: inputString, patterns: apusTerminals)
        } catch {
            Logger.scan.error("Failed to create scanner for input string '\(inputString.prefix(100), privacy: .public)'")
            throw ApusParserError.scanningFailed(error: error)
        }
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
        do {
            scanner = try Scanner(fromString: input, patterns: apusTerminals)
        } catch {
            Logger.scan.info("Failed to create scanner for input file: \(inputFileURL, privacy: .public)")
            throw ApusParserError.scanningFailed(error: error)
        }
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
            node.resolveGrammarNodeLinks(parent: node, alternate: node.alt)
        }
        
        grammar.root.follow.insert("○")
        grammar.finalizeSymbolTable()
        grammar.assignNameIDs()
        trace = false
        #Trace("start symbol '\(grammar.startSymbol)' first:", grammar.root.first, "follow:", grammar.root.follow)
        
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
        
        //        for frank in grammar.frankensteinTerminals {
        //            grammar.backpropagatePartialTokenMatchAllowed(from: frank)
        //        }
        //
        //        for frank in grammar.frankensteinTerminals {
        //            grammar.backpropagatePartialTokenMatchAllowed(from: frank)
        //        }
        //
        //        for frank in grammar.frankensteinTerminals {
        //            grammar.backpropagatePartialTokenMatchAllowed(from: frank)
        //        }
        
        // this is to a give GrammarNodes access to their own grammar
        GrammarNode.grammar = grammar
        
        var isLL1 = true
        for (name, node) in grammar.nonTerminals {
            #Trace("Detecting ambiguity for:", name)
            if !node.verifyLL1() { isLL1 = false }
            node.detectSchrödingerConflict()
        }
        grammar.isLL1 = isLL1
        grammar.propagateExcludeSets()
        grammar.populateBitSets()
        
        return grammar
    }
    
    private var skip = false
    private var terminalAlias: String?
    private var literalAliases: [String: String] = [:]
    
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
        
        try expect(["message", "○"])
        while token.kind == "message" {
            message()
        }
        
        try expect(["○"])
    }
    
    func production() throws {
        #Trace("production", token)
        let nonTerminalName = String(token.image)
        cI += 1
        
        if token.kind == ":" || token.kind == "-" {
            // terminal definition: ":" = silent, "-" = visible
            skip = (token.kind == ":")
            cI += 1
            var terminal: GrammarNode!
            switch token.kind {
            case "regex":
                // assign the name of the production to the regex
                terminalAlias = nonTerminalName
                terminal = try regex()
            case "literal":
                terminal = literal()
                literalAliases[nonTerminalName] = terminal.name
            default:
                try expect(["regex", "literal"])
            }
            
            // reset
            terminalAlias = nil
            skip = false
            
            try expect(["."])
            cI += 1
            
            // handle gated transitions: === "gate" [<<<] [>>> "push"]
            // Gate/push mode names are scanner-state labels, not literals or identifier, although they share the same strucrure.
            // TODO: extend gate/push operand parsing to accept identifier operands (in addition to literal/empty)
            //       so regex named captures can drive mode gating/transitions (e.g. === tag, >>> tag).
            while token.kind == "===" {
                cI += 1
                try expect(["literal", "empty"])
                let gate = token.stripped.escapesRemoved
                cI += 1
                let pops = token.kind == "<<<"
                if pops { cI += 1 }
                var push: String? = nil
                if token.kind == ">>>" {
                    cI += 1
                    try expect(["literal", "empty"])
                    push = token.stripped.escapesRemoved
                    cI += 1
                }
                guard grammar.terminals[terminal.name] != nil else {
                    Logger.parse.warning("WARNING: terminal \(terminal.name, privacy: .public) not found when parsing mode transition")
                    continue
                }
                grammar.terminals[terminal.name]?.transitions.append(GatedTransition(gate: gate, pops: pops, push: push))
            }
            
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
            try expect(["."])
            cI += 1
        }
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
    /// Since action is a silent terminal, action tokens land in scanner.skippedTokens.
    private func collectActions(at index: Int) -> [String] {
        guard index < scanner.trivia.count else { return [] }
        return scanner.trivia[index]
            .filter { $0.kind == "action" }
            .map { $0.stripped }
    }
    
    func sequence() throws -> GrammarNode {
        // sequence = [ layout ] < factor [ "?" | "*" | "+" ] [ layout ] > .
        // Actions are collected from skippedTokens at each position.
        #Trace("sequence", token)
        let startOfSequence = GrammarNode(kind: .ALT, name: "")
        var termNode = startOfSequence
        
        // leading actions (before first factor)
        termNode.actions = collectActions(at: cI)
        var sawFactor = false
        while true {
            // Allow layout operators before a factor.
            while let layoutNode = try layout() {
                termNode.seq = layoutNode
                termNode = layoutNode
                termNode.actions = collectActions(at: cI)
            }

            guard ["literal", "identifier", "epsilon", "empty", "regex", "(", "[", "{", "<"].contains(token.kind) else {
                if !sawFactor {
                    try expect(["identifier", "literal", "epsilon", "empty", "regex", "(", "[", "{", "<"])
                }
                break
            }

            sawFactor = true
            var itemNode = try factor()

            switch token.kind {
            case "?", "*", "+":
                let miniSeq = GrammarNode(kind: .ALT, name: "")
                miniSeq.seq = itemNode
                miniSeq.seq?.seq = GrammarNode(kind: .END, name: "")

                switch token.kind {
                case "?":
                    itemNode = GrammarNode(kind: .OPT, name: "", alt: miniSeq)
                case "*":
                    itemNode = GrammarNode(kind: .KLN, name: "", alt: miniSeq)
                case "+":
                    itemNode = GrammarNode(kind: .POS, name: "", alt: miniSeq)
                default:
                    break
                }
                itemNode.alt = miniSeq
                cI += 1
            default:
                break
            }

            termNode.seq = itemNode
            termNode = itemNode
            termNode.actions = collectActions(at: cI)
        }
        
        termNode.seq = GrammarNode(kind: .END, name: "")
        // the .alt and .seq links of an END node are set in resolveEndNodeLinks()
        return startOfSequence
    }

    func layout() throws -> GrammarNode? {
        switch token.kind {
        case ">>|", "|<<":
            let name = token.kind
            grammar.usesInjectedLayoutTokens = true
            grammar.registerTerminal(name)
            cI += 1
            return GrammarNode(kind: .T, name: name)
        case "<.>", "<:>", ">.<", ">:<":
            let name = token.kind
            grammar.registerTerminal(name)
            cI += 1
            return GrammarNode(kind: .B, name: name)
        default:
            return nil
        }
    }
    
    func regex() throws -> GrammarNode {
        #Trace("regex", token)
        // the name of the regex is either the LHS identifier of the production rule, or the lineposition
        let name = terminalAlias ?? scanner.input.linePosition(of: token.image.startIndex)
        
        if let definition = grammar.terminals[name] {
            if definition.isSkip != skip {
                Logger.parse.warning("redefinition of \(name, privacy: .public) as \(self.skip ? "skipped" : "not skipped", privacy: .public)")
            }
        }
        do {
            // the token is a regex definition, try to initialize a Regex with it
            let regex = try Regex<Substring>(String(token.stripped))
            grammar.terminals[name] = TokenPattern(String(token.image), regex, false, skip)
            grammar.registerTerminal(name)
            #Trace("regex name:", name, "image:", token.image)
        } catch {
            Logger.parse.error("grammar parse error: \(self.token.image, privacy: .public) is not a valid literal Regex \(error, privacy: .public)")
            throw ApusParserError.invalidRegex(image: String(token.image), error: error)
        }
        
        cI += 1
        return GrammarNode(kind: .T, name: name)
    }
    
    func literal() -> GrammarNode {
        #Trace("literal", token, token.stripped)
        
        // epsilon has two representations in apus grammars, either the greek letter ε, or the empty string literal ""
//        if token.stripped == "" {
//            #Trace("epsilon", token, token.stripped)
//            cI += 1
//            return GrammarNode(kind: .EPS, name: "ε")
//        }
        
        //        let name = terminalAlias ?? token.stripped
        //        print("literal terminalAlias: \(terminalAlias ?? "nil") token.stripped: \(token.stripped)")
        let name = token.stripped
        if let definition = grammar.terminals[name] {
            if definition.isSkip != skip {
                #Trace("parse warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
            }
        }
        // the token is a string literal, use a regex builder to create a Regex
        // a literal may occur multiple times in a grammar, including as a terminal definition
        // we don't want to enter the same literal over and over, especially when it might overwrite initial mode annotations
        if grammar.terminals[name] == nil {
            // to build the correct regex we need to remove the escape sequences from the token because the literal uses Swift string notation.
            // e.g. "//" in the grammar matches a single '/' in the message, and a "\t" will match a tab character in the message
            let source = token.stripped.escapesRemoved
            let regex = Regex { source }
            grammar.terminals[name] = TokenPattern(source, regex, true, skip)
            grammar.registerTerminal(name)
            //            Logger.parse.debug("added literal name: \(name) image: \(self.token.image)")
        } else {
            //            Logger.parse.debug("already defined literal name: \(name) image: \(self.token.image)")
        }
        
        
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
            let name = token.stripped
            if let literalName = literalAliases[name] {
                node = GrammarNode(kind: .T, name: literalName)
            } else if grammar.terminals[name] != nil {
                if grammar.nonTerminals[name] != nil {
                    #Trace("grammar parse error: \(token.image) is both a terminal and a nonTerminal")
                }
                node = GrammarNode(kind: .T, name: name)
            } else {
                node = GrammarNode(kind: .N, name: name)
            }
            cI += 1
        case "literal":
            node = literal()
            
            if token.kind == "~~~" {
                node.first.insert("≋")      // insert a partial-token sentinel, which then gets propagated through FIRST/FOLLOW
                cI += 1
            }
            
        case "epsilon", "empty":
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
            try expect(["identifier", "literal", "epsilon", "empty", "regex", "(", "[", "{", "<"])
            fatalError("\(#function) expect() should have thrown - this line should never be reached")
        }
        
        // check for Schrödinger exclusion annotation: ---("if" "while" ...)
        if token.kind == "---" {
            cI += 1
            try expect(["("])
            cI += 1
            while token.kind == "literal" {
                let excluded = token.stripped
                if !excluded.isEmpty {
                    node.exclude.insert(excluded)
                }
                cI += 1
            }
            try expect([")"])
            cI += 1
        }
        
        return node
    }
    
    func expect(_ expectedTokens : Set<String>) throws {
        var error = "expect \"\(token.kind)\" to be in \(expectedTokens)\n"
        if !expectedTokens.contains(token.kind) {
            error += "parse error: found \"\(token.kind)\" but expected one of \(expectedTokens)\n"
            error += "\(token.image), \(token.image.endIndex > scanner.input.endIndex)\n"
            let lineRange = scanner.input.lineRange(for: token.image.startIndex ..< token.image.endIndex)
            error += "\(scanner.input[lineRange])"
            let before = lineRange.lowerBound ..< token.image.startIndex
            for _ in 0 ..< scanner.input[before].count {
                error += "~"
            }
            for _ in 0 ..< token.image.count {
                error += "^"
            }
            Logger.grammar.error("\(error, privacy: .public)")
            throw ApusParserError.unexpectedToken(explanation: "Failed to parse grammar from symbol \(grammar.startSymbol)")
        }
    }
}
