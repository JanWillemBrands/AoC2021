//
//  ApusParser.swift
//  Advent
//
//  Created by Johannes Brands on 23/12/2024.
//

import OSLog
import Foundation
import RegexBuilder
//import AdventMacros

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
                trace("Successfully read input file with \(encoding)")
                break
            } catch {
                trace("Failed reading input file with \(encoding): \(error)")
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
        trace("terminals: \(grammar.terminals.count)")
        for (name, tokenPattern) in grammar.terminals {
            trace("\t", name, "\t", tokenPattern.source)
        }
        trace("nonTerminals:")
        for (name, node) in grammar.nonTerminals {
            trace("\t", name, "\t", node.kind)
        }
        
        // TODO: can we really remove this?
//        let conflictSet = Set(grammar.terminals.keys).intersection(Set(grammar.nonTerminals.keys))
//        if !conflictSet.isEmpty {
//            trace("grammar parser error: the following symbols have been defined as both terminal and nontermimal:", conflictSet)
//            throw ApusParserError.terminalNonterminalConflict(symbols: conflictSet)
//        }
        
        guard let root = grammar.nonTerminals[grammar.startSymbol] else {
            throw ApusParserError.startSymbolNotFound(name: grammar.startSymbol)
        }
        grammar.root = root
        
        for (name, node) in grammar.nonTerminals.sorted(by: { $0.key > $1.key }) {      // a fixed ordering with 'S' appearing first in small test grammars
            trace("Processing END nodes for:", name)
            node.resolveGrammarNodeLinks(parent: node, alternate: node.alt)
        }
        
        grammar.root.follow.insert("○")
        grammar.finalizeSymbolTable()
        grammar.assignNameIDs()
        trace = false
        trace("start symbol '\(grammar.startSymbol)' first:", grammar.root.first, "follow:", grammar.root.follow)
        
        var oldSize = 0
        var newSize = 0
        repeat {
            oldSize = newSize
            newSize = 0
            for (_, node) in grammar.nonTerminals {
                trace("nonterminalcount", grammar.nonTerminals.count)
                GrammarNode.sizeofSets = 0
                try grammar.populateFirstFollowSets(for: node)
                newSize += GrammarNode.sizeofSets
            }
            trace("first & follow", newSize)
        } while newSize != oldSize
        // store the cumulative set size
        GrammarNode.sizeofSets = newSize
        
        // this is to a give GrammarNodes access to their own grammar
        GrammarNode.grammar = grammar
        
        var isLL1 = true
        for (name, node) in grammar.nonTerminals {
            trace("Detecting ambiguity for:", name)
            if !node.verifyLL1() { isLL1 = false }
            node.detectSchrödingerConflict()
        }
        grammar.isLL1 = isLL1
        grammar.propagateExcludeSets()
        grammar.populateBitSets()
        
        try grammar.resolveUnlessTargets()

        return grammar
    }
    
    private var skip = false
    private var terminalAlias: String?
    private var literalAliases: [String: String] = [:]
    
    func parseApusGrammar() throws {
        trace("parseApusGrammar", token)
        
        // Collect preamble actions (before first production)
        grammar.preamble = collectActions(at: 0)
        
        try expect(["identifier", "pragma"])
        repeat {
            try production()
        } while token.kind == "identifier" || token.kind == "pragma"
        
        // Collect epilogue actions (after last production, before messages/$)
        grammar.epilogue = collectActions(at: cI)
        
        try expect(["message", "○"])
        while token.kind == "message" {
            message()
        }
        
        try expect(["○"])
    }
    
    func production() throws {
        trace("production", token)
        var disambiguationAnnotation: Disambiguation?
        if token.kind == "pragma", let d = Disambiguation(rawValue: token.stripped) {
            disambiguationAnnotation = d
            cI += 1
        }
        // `@lexicalClass` — marks a regex terminal as a lexical class for the
        // maximal-munch (longest-across) default. See TODO #0.
        var isLexicalClassAnnotation = false
        if token.kind == "pragma", token.stripped == "lexicalClass" {
            isLexicalClassAnnotation = true
            cI += 1
        }
        // `@splitBefore("c")` — regex terminal also offers prefixes ending before
        // each internal `c` (ports swift-syntax's operator regex-split). See TODO #0.
        var splitBeforeChar: Character? = nil
        if token.kind == "pragma", token.stripped == "splitBefore" {
            cI += 1
            try expect(["("]); cI += 1
            try expect(["literal"])
            splitBeforeChar = token.stripped.escapesRemoved.first
            cI += 1
            try expect([")"]); cI += 1
        }
        try expect(["identifier"])
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
                if isLexicalClassAnnotation { grammar.terminals[nonTerminalName]?.isLexicalClass = true }
                if let sc = splitBeforeChar { grammar.terminals[nonTerminalName]?.splitBefore = sc }
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
            
            // Gated-transition annotation (=== "gate" [<<<] [>>> "push"]) retired
            // in the scanner-retirement commit. Scanner mode-stack and
            // `TokenPattern.transitions` are gone; LCNP per-terminal lex
            // makes mode gating unnecessary.

            // handle parser-side lookbehind: ++N(...) / --N(...)
            // Each line is a comma-separated chain of rules (AND); polarity must be uniform within a line.
            // Multiple lines on the same terminal accumulate (OR).
            let lookbehindHeads: Set<String> = ["++1", "++2", "--1", "--2"]
            while lookbehindHeads.contains(token.kind) {
                var rules: [LookbehindRule] = []
                var linePolarity: LookbehindPolarity?
                repeat {
                    let head = token.kind
                    let polarity: LookbehindPolarity = head.hasPrefix("+") ? .positive : .negative
                    let distance = head.hasSuffix("1") ? 1 : 2
                    if let lp = linePolarity, lp != polarity {
                        Logger.parse.error("lookbehind line mixes polarities: \(head, privacy: .public) cannot follow opposite polarity in the same comma chain")
                        throw ApusParserError.unexpectedToken(explanation: "mixed-polarity lookbehind chain")
                    }
                    linePolarity = polarity
                    cI += 1
                    try expect(["("])
                    cI += 1
                    var kinds: [String] = []
                    while token.kind == "literal" || token.kind == "identifier" {
                        // Operand must resolve to a Token.kind value (matched against tokens at scan time).
                        //   quoted "X"     → kind is the full quoted form `"X"` (matches literal terminals)
                        //   alias name     → look up in literalAliases (already quoted form)
                        //   bare identifier (regex terminal name) → use as-is
                        let kind: String
                        if token.kind == "literal" {
                            kind = String(token.image)
                        } else {
                            let id = token.stripped
                            kind = literalAliases[id] ?? id
                        }
                        kinds.append(kind)
                        cI += 1
                    }
                    try expect([")"])
                    cI += 1
                    rules.append(LookbehindRule(polarity: polarity, distance: distance, kinds: kinds))
                    if token.kind == "," {
                        cI += 1
                    } else {
                        break
                    }
                } while lookbehindHeads.contains(token.kind)

                guard grammar.terminals[terminal.name] != nil else {
                    Logger.parse.warning("WARNING: terminal \(terminal.name, privacy: .public) not found when parsing lookbehind")
                    continue
                }
                let line = LookbehindLine(rules: rules)
                if linePolarity == .positive {
                    grammar.terminals[terminal.name]?.lookbehind.positiveLines.append(line)
                } else {
                    grammar.terminals[terminal.name]?.lookbehind.negativeLines.append(line)
                }
            }

        } else {
            // production rule — `=` for emit, `=:` for trivia (Phase E Step 2),
            // `=|` for a lexical nonterminal (body recognized by a GLL sub-parse, emitted
            // as one token; references to it resolve to a terminal — see GrammarNode.isLexicalToken).
            try expect(["=", "=:", "=|"])
            let isTrivia = token.kind == "=:"
            let isLexical = token.kind == "=|"
            // Collect signature actions (between nonterminal name and `=`/`=:`)
            let signatureActions = collectActions(at: cI)
            cI += 1
            // Actions between operator and body naturally land on the first ALT
            // node via sequence()'s collectActions(at: cI) — no separate locals
            // collection needed.
            if !isTrivia, !isLexical, grammar.startSymbol == "" {
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
            if isTrivia {
                lhsNode.isTrivia = true
            }
            if isLexical {
                lhsNode.isLexicalToken = true
                // Register the name as a terminal so references in other productions resolve to
                // `.T` (a single token) rather than expanding the body inline. The TokenPattern is
                // a marker only — its match is computed by a GLL sub-parse (lexicalTokenRecognisers).
                if grammar.terminals[nonTerminalName] == nil {
                    var pat = TokenPattern(nonTerminalName, Regex { nonTerminalName }, false, false)
                    pat.isLexicalToken = true
                    grammar.terminals[nonTerminalName] = pat
                    _ = grammar.registerTerminal(nonTerminalName)
                }
            }
            if let sig = signatureActions.first {
                lhsNode.signature = sig
            }
            if let d = disambiguationAnnotation {
                lhsNode.disambiguation = d
            }
            try expect(["."])
            cI += 1

            // Trailing @unless(X) annotation on this alternate.
            // Attached to the `.ALT` node returned by `selection()` for this production line.
            // Resolved to a GrammarNode pointer by Grammar.resolveUnlessTargets().
            if token.kind == "pragma" && token.stripped == "unless" {
                cI += 1
                try expect(["("])
                cI += 1
                try expect(["identifier"])
                node.unlessTargetName = String(token.image)
                cI += 1
                try expect([")"])
                cI += 1
            }
        }
    }
    
    func message() {
        trace("message", token)
        grammar.messages.append(token.stripped)
        cI += 1
    }
    
    func selection() throws -> GrammarNode {
        trace("selection", token)
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
        // sequence = < layout | factor [ "?" | "*" | "+" ] > .
        // Actions are collected from skippedTokens at each position.
        trace("sequence", token)
        let startOfSequence = GrammarNode(kind: .ALT, name: "")
        var termNode = startOfSequence

        // `@prefer` prefix: marks this alternate as higher-priority than its
        // siblings (Oracle prunes non-preferred siblings where this one yields).
        // Placed at the alternate's start — right after `=` or `|`.
        if token.kind == "pragma" && token.stripped == "prefer" {
            startOfSequence.isPreferred = true
            cI += 1
        }

        // leading actions (before first factor)
        termNode.actions = collectActions(at: cI)
        
        repeat {
            switch token.kind {
            case "<n>", "<s>", ">>|", ">n<", ">s<", "|<<":
                let layoutNode = layout()
                termNode.seq = layoutNode
                termNode = layoutNode
                termNode.actions = collectActions(at: cI)
            case "(", "<", "[", "epsilon", "empty", "identifier", "literal", "regex", "{":
                var factorNode = try factor()
                switch token.kind {
                case "?", "*", "+":
                    let miniSeq = GrammarNode(kind: .ALT, name: "")
                    miniSeq.seq = factorNode
                    miniSeq.seq?.seq = GrammarNode(kind: .END, name: "")

                    switch token.kind {
                    case "?":
                        factorNode = GrammarNode(kind: .OPT, name: "", alt: miniSeq)
                    case "*":
                        factorNode = GrammarNode(kind: .KLN, name: "", alt: miniSeq)
                    case "+":
                        factorNode = GrammarNode(kind: .POS, name: "", alt: miniSeq)
                    default:
                        break
                    }
                    factorNode.alt = miniSeq
                    cI += 1
                default:
                    break
                }

                termNode.seq = factorNode
                termNode = factorNode
                termNode.actions = collectActions(at: cI)
            default:
                try expect(["(", "<", "<n>", "<s>", ">>|", ">n<", ">s<", "[", "identifier", "literal", "regex", "epsilon", "empty", "{", "|<<"])
            }
            
        } while ["(", "<", "<n>", "<s>", ">>|", ">n<", ">s<", "[", "epsilon", "empty", "identifier", "literal", "regex", "{", "|<<"].contains(token.kind)
        
        termNode.seq = GrammarNode(kind: .END, name: "")
        // the .alt and .seq links of an END node are set in resolveEndNodeLinks()
        return startOfSequence
    }
    
//    func sequence() throws -> GrammarNode {
//        // sequence = < layout | factor [ "?" | "*" | "+" ] > .
//        // Actions are collected from skippedTokens at each position.
//        trace("sequence", token)
//        let startOfSequence = GrammarNode(kind: .ALT, name: "")
//        var termNode = startOfSequence
//        
//        // leading actions (before first factor)
//        termNode.actions = collectActions(at: cI)
//        var sawFactor = false
//        while true {
//            // Allow layout operators before a factor.
//            while let layoutNode = try layout() {
//                termNode.seq = layoutNode
//                termNode = layoutNode
//                termNode.actions = collectActions(at: cI)
//            }
//            
//            guard ["literal", "identifier", "epsilon", "empty", "regex", "(", "[", "{", "<"].contains(token.kind) else {
//                if !sawFactor {
//                    try expect(["identifier", "literal", "epsilon", "empty", "regex", "(", "[", "{", "<"])
//                }
//                break
//            }
//            
//            sawFactor = true
//            var itemNode = try factor()
//            
//            switch token.kind {
//            case "?", "*", "+":
//                let miniSeq = GrammarNode(kind: .ALT, name: "")
//                miniSeq.seq = itemNode
//                miniSeq.seq?.seq = GrammarNode(kind: .END, name: "")
//                
//                switch token.kind {
//                case "?":
//                    itemNode = GrammarNode(kind: .OPT, name: "", alt: miniSeq)
//                case "*":
//                    itemNode = GrammarNode(kind: .KLN, name: "", alt: miniSeq)
//                case "+":
//                    itemNode = GrammarNode(kind: .POS, name: "", alt: miniSeq)
//                default:
//                    break
//                }
//                itemNode.alt = miniSeq
//                cI += 1
//            default:
//                break
//            }
//            
//            termNode.seq = itemNode
//            termNode = itemNode
//            termNode.actions = collectActions(at: cI)
//        }
//        
//        termNode.seq = GrammarNode(kind: .END, name: "")
//        // the .alt and .seq links of an END node are set in resolveEndNodeLinks()
//        return startOfSequence
//    }
    
    func layout() -> GrammarNode {
        let name = token.kind
        grammar.registerTerminal(name)
        cI += 1
        if ["<n>", "<s>", ">n<", ">s<"].contains(name) {
            return GrammarNode(kind: .B, name: name)
        } else {    // ">>|", "|<<"
            grammar.usesInjectedLayoutTokens = true
            return GrammarNode(kind: .T, name: name)
        }
    }
    
//    func layout() throws -> GrammarNode? {
//        switch token.kind {
//        case ">>|", "|<<":
//            let name = token.kind
//            grammar.usesInjectedLayoutTokens = true
//            grammar.registerTerminal(name)
//            cI += 1
//            return GrammarNode(kind: .T, name: name)
//        case "<n>", "<s>", ">n<", ">s<":
//            let name = token.kind
//            grammar.registerTerminal(name)
//            cI += 1
//            return GrammarNode(kind: .B, name: name)
//        default:
//            return nil
//        }
//    }

    func regex() throws -> GrammarNode {
        trace("regex", token)
        // the name of the regex is either the LHS identifier of the production rule, or the lineposition
        let name = terminalAlias ?? scanner.input.linePosition(of: token.image.startIndex)
        
        if let definition = grammar.terminals[name] {
            if definition.isSkip != skip {
                Logger.parse.warning("redefinition of \(name, privacy: .public) as \(self.skip ? "skipped" : "not skipped", privacy: .public)")
            }
        }
        do {
            // the token is a regex definition, try to initialize a Regex with it
            // Construct as AnyRegexOutput so regexes that include capturing groups (e.g. backreferences like `(#+)…\1`) don't fail the type check.
            // We only ever need the whole-match boundary in the hot path; captures are not consulted by the lexer.
            let regex = try Regex(String(token.stripped))
            grammar.terminals[name] = TokenPattern(String(token.image), regex, false, skip)
            grammar.registerTerminal(name)
            trace("regex name:", name, "image:", token.image)
        } catch {
            Logger.parse.error("grammar parse error: \(self.token.image, privacy: .public) is not a valid literal Regex \(error, privacy: .public)")
            throw ApusParserError.invalidRegex(image: String(token.image), error: error)
        }
        
        cI += 1
        return GrammarNode(kind: .T, name: name)
    }
    
    func literal() -> GrammarNode {
        trace("literal", token, token.stripped)

        // Token.kind for a user-grammar literal terminal is the FULL QUOTED FORM (e.g. `"operator"`),
        // not the stripped content. This keeps the literal-kind namespace disjoint from the
        // identifier-kind namespace (nonterminals and named regex terminals), so an unquoted
        // reference like `operator` in a production body can never collide with the literal `"operator"`.
        let name = String(token.image)
        // The unescaped literal CONTENT — what the scanner matches against input characters.
        let source = token.stripped.escapesRemoved

        if let definition = grammar.terminals[name] {
            if definition.isSkip != skip {
                trace("parse warning: redefinition of \(name) as \(skip ? "skipped" : "not skipped")")
            }
        } else {
            let regex = Regex { source }
            grammar.terminals[name] = TokenPattern(source, regex, true, skip)
            grammar.registerTerminal(name)
        }

        cI += 1
        return GrammarNode(kind: .T, name: name)
    }
    
    func epsilon() -> GrammarNode {
        trace("epsilon", token, token.stripped)
        cI += 1
        return GrammarNode(kind: .EPS, name: "ε")
    }
    
    /// `@avoid` as the first token inside a bracket (`[ @avoid X ]`, `{ @avoid X }`,
    /// `< @avoid X >`): marks the optional/repetition as a fallback. Consumes the
    /// pragma and returns true when present. See `AvoidOptionalRule` in Oracle.swift.
    func consumeAvoid() -> Bool {
        if token.kind == "pragma" && token.stripped == "avoid" {
            cI += 1
            return true
        }
        return false
    }

    func factor() throws -> GrammarNode {
        trace("factor", token)
        let node: GrammarNode
        switch token.kind {
        case "identifier":
            let name = token.stripped
            if let literalName = literalAliases[name] {
                node = GrammarNode(kind: .T, name: literalName)
            } else if grammar.terminals[name] != nil {
                if grammar.nonTerminals[name] != nil {
                    trace("grammar parse error: \(token.image) is both a terminal and a nonTerminal")
                }
                node = GrammarNode(kind: .T, name: name)
            } else {
                node = GrammarNode(kind: .N, name: name)
            }
            cI += 1
        case "literal":
            node = literal()
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
            let avoid = consumeAvoid()
            node = GrammarNode(kind: .OPT, name: "", alt: try selection())
            node.isAvoided = avoid
            try expect(["]"])
            cI += 1
        case "{":
            cI += 1
            let avoid = consumeAvoid()
            node = GrammarNode(kind: .KLN, name: "", alt: try selection())
            node.isAvoided = avoid
            try expect(["}"])
            cI += 1
        case "<":
            cI += 1
            let avoid = consumeAvoid()
            node = GrammarNode(kind: .POS, name: "", alt: try selection())
            node.isAvoided = avoid
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
                // Exclusion entries must match Token.kind values in the symbol table.
                // User-grammar literal terminals are now keyed by their full quoted form
                // (see literal()), so we record the same form here.
                let excluded = String(token.image)
                if !token.stripped.isEmpty {
                    node.exclude.insert(excluded)
                }
                cI += 1
            }
            try expect([")"])
            cI += 1
        }

        // check for positive forward lookahead annotation: >>1("(" ")" ...)
        // Mirrors `---` shape but checks the NEXT token at parse time, not duals.
        // EOS sentinel ("○") is treated as approved automatically — matches Swift's
        // canParseAsGenericArgumentList rule where EOF closes the generic clause.
        if token.kind == ">>1" {
            cI += 1
            try expect(["("])
            cI += 1
            while token.kind == "literal" {
                let approved = String(token.image)
                if !token.stripped.isEmpty {
                    node.followAhead.insert(approved)
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
