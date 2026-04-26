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
            Logger.scan.error("Failed to create scanner for input string '\(inputString.prefix(100))'")
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
            Logger.scan.info("Failed to create scanner for input file: \(inputFileURL)")
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
        
        GrammarNode.isLL1 = true
        for (name, node) in grammar.nonTerminals {
            #Trace("Detecting ambiguity for:", name)
            node.detectAmbiguity()
            node.detectSchrödingerConflict()
        }
        grammar.isLL1 = GrammarNode.isLL1
        grammar.propagateExcludeSets()
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
                // do NOT assign the name of the production to the regex, instead use the literal image as the name
                //                terminalAlias = nonTerminalName
                terminal = literal()
            default:
                try expect(["regex", "literal"])
            }
            
            // reset
            terminalAlias = nil
            skip = false
            
            try expect(["."])
            cI += 1
            
            // handle scanner mode annotations
            if token.kind == "===" {
                cI += 1
                try expect(["literal"])
                let modeLiteral = literal()
                grammar.terminals[terminal.name]?.mode.modeName = modeLiteral.name
                grammar.terminals[terminal.name]?.mode.isCheck = true
            } else if token.kind == ">>>" {
                cI += 1
                try expect(["literal"])
                let modeLiteral = literal()
                if grammar.terminals[terminal.name] != nil {
                    grammar.terminals[terminal.name]?.mode.modeName = modeLiteral.name
                    grammar.terminals[terminal.name]?.mode.isPush = true
                } else {
                    Logger.parse.warning("WARNING: terminal \(terminal.name) not found when parsing >>> mode")
                }
            } else if token.kind == "<<<" {
                cI += 1
                try expect(["literal"])
                let modeLiteral = literal()
                grammar.terminals[terminal.name]?.mode.modeName = modeLiteral.name
                grammar.terminals[terminal.name]?.mode.isPop = true
            }
//            print("terminal: \(terminal.name) mode: \(String(describing: grammar.terminals[terminal.name]?.mode))")
            
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
        // the name of the regex is either the LHS identifier of the production rule, or the lineposition
        let name = terminalAlias ?? scanner.input.linePosition(of: token.image.startIndex)
        
        if let definition = grammar.terminals[name] {
            if definition.isSkip != skip {
                Logger.parse.warning("redefinition of \(name) as \(self.skip ? "skipped" : "not skipped")")
            }
        }
        do {
            // the token is a regex definition, try to initialize a Regex with it
            let regex = try Regex<Substring>(String(token.stripped))
            grammar.terminals[name] = (String(token.image), regex, false, skip, Mode())
            grammar.registerTerminal(name)
            #Trace("regex name:", name, "image:", token.image)
        } catch {
            Logger.parse.error("grammar parse error: \(self.token.image) is not a valid literal Regex \(error)")
            throw ApusParserError.invalidRegex(image: String(token.image), error: error)
        }
        
        cI += 1
        return GrammarNode(kind: .T, name: name)
    }
    
    func literal() -> GrammarNode {
        #Trace("literal", token, token.stripped)
        
        // epsilon has two representations in apus grammars, either the greek letter ε, or the empty string literal ""
        if token.stripped == "" {
            #Trace("epsilon", token, token.stripped)
            cI += 1
            return GrammarNode(kind: .EPS, name: "ε")
        }
        
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
            let regex = Regex { token.stripped.escapesRemoved }
            grammar.terminals[name] = (String(token.image), regex, true, skip, Mode())
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
            // the identifier can be a terminal or nonTerminal but not both
            if grammar.terminals[String(token.image)] != nil {
                if grammar.nonTerminals[String(token.image)] != nil {
                    #Trace("grammar parse error: \(token.image) is both a terminal and a nonTerminal")
                }
                // this string was defined previously as a terminal
                // TODO: currently all terminals must be defined BEFORE they are used
                node = GrammarNode(kind: .T, name: token.stripped)
            } else {
                // this string is assumed to be
                // nonTerminals may be used before they are defined, and are resolved later
                node = GrammarNode(kind: .N, name: token.stripped)
            }
            cI += 1
        case "literal":
            node = literal()
            
            if token.kind == "=>>" {
                node.first.insert("≋")      // insert a partial-token sentinel, which then gets propagated through FIRST/FOLLOW
                cI += 1
            }
            
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
            fatalError("\(#function) expect() should have thrown - this line should never be reached")
        }
        
        // check for Schrödinger exclusion annotation: ---("if" "let" ...)
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
            Logger.grammar.error("\(error)")
            throw ApusParserError.unexpectedToken(explanation: "Failed to parse grammar from symbol \(grammar.startSymbol)")
        }
    }
}

//
//  ApusTerminals.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.11.
//

import OSLog
import RegexBuilder

//typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool, mode: Mode)

let apusTerminals: [String:TokenPattern] = [
    "whitespace":   (#"\s+"#,                   /\s+/,                              false, true, Mode()),
    "linecomment":  (#"//.*"#,                  /\/\/.*/,                           false, true, Mode()),
    "blockcomment": (#"/\*(?s).*?\*/"#,         /\/\*(?s).*?\*\//,                  false, true, Mode()),
    "identifier":   (#"\p{XID_Start}\p{XID_Continue}*"#, /\p{XID_Start}\p{XID_Continue}*/,   false, false, Mode()),
    "literal":      (#""(?:[^"\\]|\\.)*""#,     /\"(?:[^\"\\]|\\.)*\"/,             false, false, Mode()),
    "regex":        (#"/(?!\*)(?:[^\/\\]|\\.)+/"#,    /\/(?!\*)(?:[^\/\\]|\\.)+\//,             false, false, Mode()),
    "action":       (#"@(?:[^@\\]|\\.)*@"#,     /@(?:[^@\\]|\\.)*@/,                false, true, Mode()),
    "message":      (#"\^\^\^(?:(?s).*?)(?=\^\^\^|$)"#,
                                                /\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,    false, false, Mode()),
    "epsilon":      (#"[εϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄]"#,        /[εϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄]/,                    true,  false, Mode()),
    ".":            (".",                       Regex { "." },                      true,  false, Mode()),
    ":":            (":",                       Regex { ":" },                      true,  false, Mode()),
    "=":            ("=",                       Regex { "=" },                      true,  false, Mode()),
    "-":            ("-",                       Regex { "-" },                      true,  false, Mode()),
    "|":            ("|",                       Regex { "|" },                      true,  false, Mode()),
    "(":            ("(",                       Regex { "(" },                      true,  false, Mode()),
    ")":            (")",                       Regex { ")" },                      true,  false, Mode()),
    "[":            ("[",                       Regex { "[" },                      true,  false, Mode()),
    "]":            ("]",                       Regex { "]" },                      true,  false, Mode()),
    "{":            ("{",                       Regex { "{" },                      true,  false, Mode()),
    "}":            ("}",                       Regex { "}" },                      true,  false, Mode()),
    "<":            ("<",                       Regex { "<" },                      true,  false, Mode()),
    ">":            (">",                       Regex { ">" },                      true,  false, Mode()),
    "?":            ("?",                       Regex { "?" },                      true,  false, Mode()),
    "*":            ("*",                       Regex { "*" },                      true,  false, Mode()),
    "+":            ("+",                       Regex { "+" },                      true,  false, Mode()),
    "===":          ("===",                     Regex { "===" },                    true,  false, Mode()),
    ">>>":          (">>>",                     Regex { ">>>" },                    true,  false, Mode()),
    "<<<":          ("<<<",                     Regex { "<<<" },                    true,  false, Mode()),
    "=>>":          ("=>>",                     Regex { "=>>" },                    true,  false, Mode()),
    "---":          ("---",                     Regex { "---" },                    true,  false, Mode()),
//    "nonASCII":     (#"[^\p{ASCII}]"#,          /[^\p{ASCII}]/,                     false,  false),
//    ")?":           (")?",                      Regex { ")?" },                     true,  false),
//    ")*":           (")*",                      Regex { ")*" },                     true,  false),
//    ")+":           (")+",                      Regex { ")+" },                     true,  false),
]





// alternative definitions using RegexBuilder
let whitespaceRegex = Regex {
    OneOrMore {
        .whitespace
    }
}
let linecommentRegex = Regex {
    "//"
    ZeroOrMore {
        .anyNonNewline
    }
}
let blockcommentRegex = Regex {
    "/*"
    ZeroOrMore(.reluctant) {
        .any
    }
    "*/"
}
// recommended identifier syntax following https://unicode.org/reports/tr31/
let identifierRegex = Regex {
    /\p{XID_Start}/
    ZeroOrMore {
        /\p{XID_Continue}/
    }
}
let literalRegex = Regex {
    "\""
    ZeroOrMore {
        ChoiceOf {
            // any character that is not a '"' or a backward slash '\'
            CharacterClass(.anyOf("\"\\").inverted)
            // a backward slash '\' followed by single character, to escape '"' or '\', but catches more than legal escapes
            /\\./
        }
    }
    "\""
}
let regexRegex = Regex {
    "/"
    ZeroOrMore {
        ChoiceOf {
            // any character that is not a forward slash '/' or a backward slash '\'
            CharacterClass(.anyOf("/\\").inverted)
            // a backward slash '\' followed by single character, to escape '/' or '\', but catches more than legal escapes
            /\\./
        }
    }
    "/"
}
let actionRegex = Regex {
    "@"
    ZeroOrMore {
        ChoiceOf {
            // any character that is not a '@' or a backward slash '\'
            CharacterClass(.anyOf("@\\").inverted)
            // a backward slash '\' followed by single character, to escape '@' or '\', but catches more than legal escapes
            /\\./
        }
    }
    "@"
}
let messageRegex = Regex {
    /\^\^\^/
    ZeroOrMore(.reluctant) {
        .any
    }
    Lookahead {
        ChoiceOf {
            /\^\^\^/
            Anchor.endOfSubject
        }
    }
}

enum TokenType: String, CustomStringConvertible, CaseIterable {
    case endOfString            = "○"    // BLACK CIRCLE U+25CF
    case epsilon                = "ε"
    case fullStop               = "."
    case colon                  = ":"
    case equalsSign             = "="
    case verticalLine           = "|"
    case leftParenthesis        = "("
    case rightParenthesis       = ")"
    case leftSquareBracket      = "["
    case rightSquareBracket     = "]"
    case leftCurlyBracket       = "{"
    case rightCurlyBracket      = "}"
    case lessThanSign           = "<"
    case greaterThanSign        = ">"
    case questionMark           = "?"
    case asterisk               = "*"
    case plusSign               = "+"
    case whitespace             = "whitespace"
    case linecomment            = "linecomment"
    case blockcomment           = "blockcomment"
    case identifier             = "identifier"
    case literal                = "literal"
    case regex                  = "regex"
    case action                 = "action"
    case message                = "message"
    
    var description: String {self.rawValue}
}

typealias TokenRegex = (kind: TokenType, regex: Regex<Substring>)

let tokenRegexes: [TokenRegex] = [
    (.epsilon,                      /[εϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄]/ ),
    (.fullStop,                     Regex { "." } ),
    (.colon,                        Regex { ":" } ),
    (.equalsSign,                   Regex { "=" } ),
    (.verticalLine,                 Regex { "|" } ),
    (.leftParenthesis,              Regex { "(" } ),
    (.rightParenthesis,             Regex { ")" } ),
    (.leftSquareBracket,            Regex { "[" } ),
    (.rightSquareBracket,           Regex { "]" } ),
    (.leftCurlyBracket,             Regex { "{" } ),
    (.rightCurlyBracket,            Regex { "}" } ),
    (.lessThanSign,                 Regex { "<" } ),
    (.greaterThanSign,              Regex { ">" } ),
    (.questionMark,                 Regex { "?" } ),
    (.asterisk,                     Regex { "*" } ),
    (.plusSign,                     Regex { "+" } ),
    (.whitespace,                   whitespaceRegex ),
    (.linecomment,                  linecommentRegex ),
    (.blockcomment,                 blockcommentRegex ),
    (.identifier,                   identifierRegex ),
    (.literal,                      literalRegex ),
    (.regex,                        regexRegex ),
    (.action,                       actionRegex ),
    (.message,                      messageRegex ),
]
//
//  BinarySubtreeRepresentation.swift
//  Advent
//
//  Created by Johannes Brands on 27/04/2025.
//

//import Foundation
import OSLog
import AdventMacros

struct BSR: Hashable, CustomStringConvertible {
    let slot: GrammarNode
    let i: TokenPosition  // left extent
    let k: TokenPosition  // pivot
    let j: TokenPosition  // right extent
    var description: String { "\(slot.ebnfDot()) \(i):\(k):\(j)" }
}

struct BinarySpan: Hashable, Comparable, CustomStringConvertible {
    let i: TokenPosition  // left extent
    let k: TokenPosition  // pivot
    let j: TokenPosition  // right extent
    var description: String { "\(i):\(k):\(j)" }

    static func < (lhs: BinarySpan, rhs: BinarySpan) -> Bool {
        (lhs.i, lhs.k, lhs.j) < (rhs.i, rhs.k, rhs.j)
    }
}

// MARK: - MessageParser BSR Operations

extension MessageParser {

    // Paper: bsrAdd(X ::= α·β, i, k, j) — add BSR element to the yield
    func addYield(L: GrammarNode, i: TokenPosition, k: TokenPosition, j: TokenPosition) {
        let triple = BinarySpan(i: i, k: k, j: j)
        if L.yield.insert(triple).inserted {
            yieldCount += 1
        }
    }
}
//
//  CallReturnForest.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

// "Derivation representation using binary subtree sets"
// https://pure.royalholloway.ac.uk/ws/portalfiles/portal/33174042/Accepted_Manuscript.pdf

// Paper: CRF = Call Return Forest
// Paper: P = contingent return set (pops)
// Paper: cL = current grammar slot, cI = current input index, cU = current cluster index

import OSLog
import Foundation


// Lightweight value type for CRF dictionary keys and return edges.
// Matches the paper's crfNode (L, i).
struct ParsePosition: Hashable, Comparable, CustomStringConvertible {
    let slot: GrammarNode
    let index: TokenPosition

    var description: String { "\(slot).\(index)" }
    var ebnfDot: String { "\(slot.ebnfDot()),\(index)" }

    static func < (lhs: ParsePosition, rhs: ParsePosition) -> Bool {
        lhs.description < rhs.description
    }
}

// Cluster node in the CRF. Mutable, identity-based.
// Represents clusterNode (X, k) from the paper.
final class ParseCluster: CustomStringConvertible {
    let slot: GrammarNode           // the LHS nonterminal (X)
    let index: TokenPosition        // input position (k)

    var returns: Set<ParsePosition> = []
    var pops: Set<TokenPosition> = []   // Paper: P — contingent returns

    init(slot: GrammarNode, index: TokenPosition) {
        self.slot = slot
        self.index = index
    }

    var description: String { "\(slot).\(index)" }
    var ebnfDot: String { "\(slot.ebnfDot()),\(index)" }
}


// MARK: - MessageParser CRF Operations

extension MessageParser {

    // Paper: ntAdd(X, j) — add descriptors for all alternates of a bracket/nonterminal
    func addDecscriptorsForAlternates(X: GrammarNode, k: TokenPosition, i: TokenPosition) {
        assert([.N, .DO, .OPT, .ALT, .KLN, .POS].contains(X.kind), "Called \(#function) on a GrammarNode \(X) which is not a bracket")
        // For LL(1) nonterminals without Schrödinger duals or Frankenstein tokens,
        // at most one alternate can match — stop after finding it.
        let canEarlyTerminate = X.isLocallyLL1
            && tokens[i.tokenIndex].dual == nil
            && i.charOffset == 0
            && !X.firstBS.contains(grammar.frankensteinID)
        var current = X.alt
        while let alt = current {
            if testSelect(slot: alt, bracket: X) {
                addDescriptor(L: alt.seq!, k: k, i: i)
                if canEarlyTerminate { return }
            }
            current = alt.alt
        }
    }
    
    // Paper: call(L, i, j) — enter a nonterminal
    func call() {
        // cL points to the RHS nonterminal node
        // cL.alt points to the LHS nonterminal node

        // Create the return edge: (L=cL, i=cU)
        let returnEdge = ParsePosition(slot: cL, index: cU)

        // Find or create the cluster node for (X=cL.alt!, k=cI)
        let clusterKey = ParsePosition(slot: cL.alt!, index: cI)

        if let existingCluster = crf[clusterKey] {
            if existingCluster.returns.insert(returnEdge).inserted {
                for pop in existingCluster.pops {
                    if continuationViable(continuation: cL.seq!, at: pop) {
                        addDescriptor(L: cL.seq!, k: cU, i: pop)
                        addYield(L: cL, i: cU, k: cI, j: pop)
                    } else {
                        suppressedDescriptorCount += 1
                    }
                }
            }
        } else {
            let newCluster = ParseCluster(slot: cL.alt!, index: cI)
            crf[clusterKey] = newCluster
            newCluster.returns.insert(returnEdge)
            addDecscriptorsForAlternates(X: cL.alt!, k: cI, i: cI)
        }
    }
    
    // Paper: rtn(X, k, j) — return from a nonterminal
    func rtn(X: GrammarNode) {
        let clusterKey = ParsePosition(slot: X, index: cU)
        guard let cluster = crf[clusterKey] else { return }

        if cluster.pops.insert(cI).inserted {
            for rtn in cluster.returns {
                if continuationViable(continuation: rtn.slot.seq!, at: cI) {
                    addDescriptor(L: rtn.slot.seq!, k: rtn.index, i: cI)
                    addYield(L: rtn.slot, i: rtn.index, k: cU, j: cI)
                } else {
                    suppressedDescriptorCount += 1
                }
            }
        }
    }
    
    // bracketCall — enter a bracket (DO, OPT, KLN, POS)
    // Similar to call() but the bracket node IS the "nonterminal" — no indirection through .alt
    func bracketCall(bracket: GrammarNode) {
        let returnEdge = ParsePosition(slot: bracket, index: cU)
        let clusterKey = ParsePosition(slot: bracket, index: cI)

        if let existingCluster = crf[clusterKey] {
            if existingCluster.returns.insert(returnEdge).inserted {
                for pop in existingCluster.pops {
                    if continuationViable(continuation: bracket.seq!, at: pop) {
                        addDescriptor(L: bracket.seq!, k: cU, i: pop)
                        addYield(L: bracket, i: cU, k: cI, j: pop)
                    } else {
                        suppressedDescriptorCount += 1
                    }
                }
            }
        } else {
            let newCluster = ParseCluster(slot: bracket, index: cI)
            crf[clusterKey] = newCluster
            newCluster.returns.insert(returnEdge)
            addDecscriptorsForAlternates(X: bracket, k: cI, i: cI)
        }
    }
    
    // bracketRtn — return from a bracket
    // Similar to rtn() but also handles KLN/POS re-entry
    func bracketRtn(bracket: GrammarNode) {
        let clusterKey = ParsePosition(slot: bracket, index: cU)
        guard let cluster = crf[clusterKey] else { return }

        if cluster.pops.insert(cI).inserted {
            for rtn in cluster.returns {
                if continuationViable(continuation: rtn.slot.seq!, at: cI) {
                    addYield(L: rtn.slot, i: rtn.index, k: cU, j: cI)
                    addDescriptor(L: rtn.slot.seq!, k: rtn.index, i: cI)
                } else {
                    suppressedDescriptorCount += 1
                }
            }

            if bracket.kind.isClosure {
                let nextKey = ParsePosition(slot: bracket, index: cI)

                if let existingCluster = crf[nextKey] {
                    for returnEdge in cluster.returns {
                        if existingCluster.returns.insert(returnEdge).inserted {
                            for pop in existingCluster.pops {
                                if continuationViable(continuation: returnEdge.slot.seq!, at: pop) {
                                    addYield(L: returnEdge.slot, i: returnEdge.index, k: cI, j: pop)
                                    addDescriptor(L: returnEdge.slot.seq!, k: returnEdge.index, i: pop)
                                } else {
                                    suppressedDescriptorCount += 1
                                }
                            }
                        }
                    }
                } else {
                    let newCluster = ParseCluster(slot: bracket, index: cI)
                    crf[nextKey] = newCluster
                    newCluster.returns = cluster.returns
                    addDecscriptorsForAlternates(X: bracket, k: cI, i: cI)
                }
            }
        }
    }
}

//
//  Descriptor.swift
//  Advent
//
//  Created by Johannes Brands on 29/04/2025.
//

// Paper: descriptor = (L, k, i) — grammar slot, cluster index, input index
import OSLog

/// Packed token position: upper bits = token array index, lower bits = character offset within token.
/// Character offset 0 = normal position. Character offset > 0 = Frankenstein sub-position
/// (mid-token split, e.g. ">>" being consumed as two separate ">").
struct TokenPosition: Hashable, Comparable, CustomStringConvertible {
    private static let shift = 4
    private static let mask: Int32  = 0xF

    var bits: Int32

    var tokenIndex: Int         { Int(bits) >> Self.shift }
    var charOffset: Int         { Int(bits & Self.mask) }

    init(token: Int, charOffset: Int = 0) {
        self.bits = Int32(token << Self.shift | charOffset)
    }

    private init(bits: Int32) { self.bits = bits }

    func nextToken() -> TokenPosition { TokenPosition(token: tokenIndex + 1) }
    func at(charOffset: Int) -> TokenPosition { TokenPosition(token: tokenIndex, charOffset: charOffset) }

    static let zero = TokenPosition(bits: 0)
    static let unused = TokenPosition(bits: -1)

    static func < (lhs: TokenPosition, rhs: TokenPosition) -> Bool { lhs.bits < rhs.bits }

    var description: String {
        charOffset == 0 ? "\(tokenIndex)" : "\(tokenIndex).\(charOffset)"
    }
}

struct Descriptor: Hashable {
    let L: GrammarNode          // grammar slot
    let k: TokenPosition        // cluster index
    let i: TokenPosition        // input index
    // MemoryLayout<Descriptor>.size = 16 bytes (8 + 4 + 4)
}

// MARK: - MessageParser Descriptor Operations

extension MessageParser {

    // Paper: dscAdd(L, k, i)
    func addDescriptor(L: GrammarNode, k: TokenPosition, i: TokenPosition) {
        let d = Descriptor(L: L, k: k, i: i)
        if unique.insert(d).inserted {
            remaining.append(d)
            descriptorCount += 1
        } else {
            duplicateDescriptorCount += 1
        }
    }

    // Paper: get next descriptor from R
    func getDescriptor() -> Bool {
        if remaining.isEmpty {
            return false
        } else {
            let d = remaining.removeLast()
            cL = d.L
            cU = d.k
            cI = d.i
            return true
        }
    }
}
//
//  GenerateDerivationDiagram.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.22.
//

import Foundation

// MARK: - Parse Tree Node

class ParseTreeNode {
    let name: String
    let token: Token?             // non-nil for terminal leaves
    let from: TokenPosition
    let to: TokenPosition
    var children: [ParseTreeNode] = []
    var isTerminal: Bool { token != nil }

    init(name: String, from: TokenPosition, to: TokenPosition, token: Token? = nil) {
        self.name = name
        self.from = from
        self.to = to
        self.token = token
    }
}

// MARK: - Derivation Builder

/// Builds concrete parse trees directly from the BSR (Binary Subtree Representation)
/// yield set produced by the GLL parser. Each GrammarNode carries its own yield
/// (a set of BinarySpan(i,k,j) triples recording which spans it matched).
///
/// The algorithm works by recursive descent over the grammar structure:
///   1. Start from the root nonterminal spanning the full input.
///   2. For each nonterminal, try each alternate's body symbols.
///   3. Tile the body symbols left-to-right over the span using `endPositions`
///      to find valid split points from the BSR evidence.
///   4. Terminals become leaf nodes; nonterminals recurse; EBNF brackets
///      (groups, options, closures) are transparent — their iteration content
///      is inlined as direct children of the enclosing nonterminal.
///
/// For ambiguous grammars, multiple trees are returned (up to `limit`).

class DerivationBuilder {
    let grammar: Grammar
    let tokens: [Token]
    
    /// Tracks active nonterminal expansions on the current call path to break cycles.
    private var activeExpansions: Set<ExpansionKey> = []
    
    private struct ExpansionKey: Hashable {
        let node: ObjectIdentifier
        let from: TokenPosition
        let to: TokenPosition
    }
    
    init(grammar: Grammar, tokens: [Token]) {
        self.grammar = grammar
        self.tokens = tokens
    }
    
    /// Entry point: build all parse trees rooted at the grammar's start symbol.
    func buildAllTrees(limit: Int = 10) -> [ParseTreeNode] {
        let n = TokenPosition(token: tokens.count - 1)
        guard grammar.root.yield.contains(where: { $0.i == .zero && $0.j == n }) else { return [] }
        return buildNonterminalTrees(grammar.root, from: .zero, to: n, limit: limit)
    }
    
    // MARK: - Tree Construction
    
    /// Build all parse trees for a nonterminal over [from, to].
    /// Each tree is a ParseTreeNode whose children come from expanding one alternate.
    private func buildNonterminalTrees(_ nt: GrammarNode, from: TokenPosition, to: TokenPosition, limit: Int) -> [ParseTreeNode] {
        let key = ExpansionKey(node: ObjectIdentifier(nt), from: from, to: to)
        guard activeExpansions.insert(key).inserted else { return [] }
        defer { activeExpansions.remove(key) }
        
        return expandAlternates(nt, from: from, to: to, limit: limit).map { children in
            let node = ParseTreeNode(name: nt.name, from: from, to: to)
            node.children = children
            return node
        }
    }
    
    /// Walk the alternate chain of a grammar node (nonterminal or bracket),
    /// expanding each alternate's body over [from, to].
    /// Returns child lists — each list is one valid way to fill the span.
    private func expandAlternates(_ node: GrammarNode, from: TokenPosition, to: TokenPosition, limit: Int) -> [[ParseTreeNode]] {
        var results: [[ParseTreeNode]] = []
        var altNode = node.alt
        while let alt = altNode {
            defer { altNode = alt.alt }
            guard results.count < limit else { break }
            let symbols = alt.bodySymbols.filter { $0.kind != .EPS }
            if symbols.isEmpty {
                if from == to { results.append([]) }
                continue
            }
            results.append(contentsOf: expandBody(symbols, from: from, to: to, limit: limit - results.count))
        }
        return results
    }
    
    /// Expand a sequence of body symbols over [from, to] by scanning left-to-right.
    /// For each symbol, `endPositions` provides the valid split points from BSR evidence.
    /// The cross-product of all symbol positions is computed inline through recursion.
    private func expandBody(_ symbols: [GrammarNode], from: TokenPosition, to: TokenPosition, limit: Int) -> [[ParseTreeNode]] {
        guard let first = symbols.first else {
            return from == to ? [[]] : []
        }
        let rest = Array(symbols.dropFirst())
        var results: [[ParseTreeNode]] = []
        for mid in endPositions(first, from: from) where mid <= to {
            guard results.count < limit else { break }
            for children in buildSymbolChildren(first, from: from, to: mid, limit: limit) {
                guard results.count < limit else { break }
                for restChildren in expandBody(rest, from: mid, to: to, limit: limit - results.count) {
                    guard results.count < limit else { break }
                    results.append(children + restChildren)
                }
            }
        }
        return results
    }
    
    /// Build child nodes for a single grammar symbol over [from, to].
    /// Returns options of sibling-lists:
    ///   - Terminal: one option with one leaf node
    ///   - Nonterminal: one option per ambiguous parse, each containing one subtree
    ///   - Bracket: one option per interpretation, each a flat list of inlined children
    ///   - EPS: one option with zero children
    private func buildSymbolChildren(_ sym: GrammarNode, from: TokenPosition, to: TokenPosition, limit: Int) -> [[ParseTreeNode]] {
        switch sym.kind {
        case .T, .TI, .C, .B:
            return [[ParseTreeNode(name: sym.name, from: from, to: to, token: tokens[from.tokenIndex])]]
        case .N:
            guard let lhs = sym.alt else { return [] }
            return buildNonterminalTrees(lhs, from: from, to: to, limit: limit).map { [$0] }
        case .DO, .OPT, .KLN, .POS:
            let lists = expandIterations(sym, from: from, to: to, limit: limit)
            return lists.isEmpty && (sym.kind == .KLN || sym.kind == .OPT) ? [[]] : lists
        case .EPS:
            return [[]]
        default:
            return [[]]
        }
    }
    
    /// Chain bracket iterations over [from, to], returning flat child lists.
    /// EBNF brackets are transparent in the parse tree — no bracket node appears.
    /// Instead, each iteration's body symbols are expanded and concatenated as siblings.
    /// For closures (KLN/POS), iterations chain forward: [from,k₁] + [k₁,k₂] + ... + [kₙ,to].
    private func expandIterations(_ bracket: GrammarNode, from: TokenPosition, to: TokenPosition, limit: Int) -> [[ParseTreeNode]] {
        if from == to { return [[]] }
        var results: [[ParseTreeNode]] = []
        // Each BSR span (i, k=iterStart, j=iterEnd) in the bracket's yield
        // records one iteration boundary.
        for span in bracket.yield where span.k == from && span.j <= to {
            guard results.count < limit else { break }
            let iterContent = expandAlternates(bracket, from: from, to: span.j, limit: limit - results.count)
            if span.j == to {
                // Last (or only) iteration reaches the target — done.
                results.append(contentsOf: iterContent)
            } else if bracket.kind.isClosure {
                // More iterations follow — recurse for the tail [span.j, to].
                for head in iterContent {
                    guard results.count < limit else { break }
                    for tail in expandIterations(bracket, from: span.j, to: to, limit: limit - results.count) {
                        guard results.count < limit else { break }
                        results.append(head + tail)
                    }
                }
            }
        }
        return results
    }
    
    // MARK: - BSR Helpers
    
    /// All valid end positions for a symbol starting at `from`, derived from BSR evidence.
    /// This is the key function that connects the grammar structure to the parse evidence:
    ///   - Terminals: span exactly one token (from → from+1) if the token kind matches.
    ///   - Nonterminals: the LHS node's yield gives all spans starting at `from`.
    ///   - Brackets: follow the iteration chain (k→j) through the bracket's yield.
    ///     For closures (KLN/POS), chain through multiple iterations via BFS.
    ///     Nullable brackets (KLN/OPT) also include `from` itself (empty match).
    ///   - Epsilon: matches only at `from` (empty span).
    private func endPositions(_ symbol: GrammarNode, from: TokenPosition) -> Set<TokenPosition> {
        switch symbol.kind {
        case .T, .TI, .C, .B:
            var positions: Set<TokenPosition> = []
            for span in symbol.yield where span.k == from { positions.insert(span.j) }
            return positions
        case .N:
            guard let lhs = symbol.alt else { return [] }
            var positions: Set<TokenPosition> = []
            for span in lhs.yield where span.i == from { positions.insert(span.j) }
            return positions
        case .DO, .OPT, .KLN, .POS:
            var positions: Set<TokenPosition> = []
            if symbol.kind == .KLN || symbol.kind == .OPT { positions.insert(from) }
            var visited: Set<TokenPosition> = []
            var queue = [from]
            while !queue.isEmpty {
                let pos = queue.removeFirst()
                guard visited.insert(pos).inserted else { continue }
                for span in symbol.yield where span.k == pos {
                    positions.insert(span.j)
                    if symbol.kind.isClosure { queue.append(span.j) }
                }
            }
            return positions
        case .EPS:
            return [from]
        default:
            return []
        }
    }
}

// MARK: - Graphviz Rendering

/// Generate a Graphviz dot file visualizing parse trees as a classic syntax tree diagram.
/// Nonterminals are drawn as ellipses, terminals as boxes with the token text.
/// For ambiguous grammars, each derivation is shown in a separate subgraph cluster.
func generateDerivationDiagram(outputFile file: URL, grammar: Grammar, tokens: [Token]) throws {
    let trees = DerivationBuilder(grammar: grammar, tokens: tokens).buildAllTrees()
    guard !trees.isEmpty else { return }
    
    var dot = """
    digraph Derivations {
      fontname = Menlo
      fontsize = 10
      node [fontname = Menlo, fontsize = 10]
      edge [arrowsize = 0.5]
      rankdir = TB
      ordering = out
      labelloc = t
      label = <\(grammar.root.ebnf().graphvizHTML)>
    
    """
    
    if trees.count > 1 {
        for (i, tree) in trees.enumerated() {
            dot += "  subgraph cluster_\(i) {\n"
            dot += "    label = \"Derivation \(i + 1)\"\n"
            dot += "    style = dashed\n"
            dot += renderTreeBody(tree, prefix: "d\(i)_")
            dot += "  }\n\n"
        }
    } else {
        dot += renderTreeBody(trees[0], prefix: "")
    }
    
    dot += "}\n"
    try dot.write(to: file, atomically: true, encoding: .utf8)
}

/// Render a single parse tree as Graphviz node/edge declarations.
/// Terminal leaves are forced to the same rank at the bottom with invisible
/// ordering edges to maintain left-to-right reading order.
private func renderTreeBody(_ tree: ParseTreeNode, prefix: String) -> String {
    var dot = ""
    var n = 0
    var terminals: [(id: String, pos: TokenPosition)] = []
    
    func emit(_ node: ParseTreeNode) -> String {
        let id = "\(prefix)n\(n)"; n += 1
        if node.isTerminal {
            dot += "  \(id) [shape = box, width=0.0, height=0.0, label = <\(String(node.token!.image).graphvizHTML)>]\n"
            terminals.append((id, node.from))
        } else {
            dot += "  \(id) [shape = ellipse, width=0.0, height=0.0, label = <\(node.name.graphvizHTML)>]\n"
        }
        for child in node.children {
            dot += "  \(id) -> \(emit(child))\n"
        }
        return id
    }
    
    _ = emit(tree)
    
    let sorted = terminals.sorted { $0.pos < $1.pos }
    if sorted.count > 1 {
        dot += "  { rank = same; \(sorted.map(\.id).joined(separator: "; ")) }\n"
        for i in 0..<(sorted.count - 1) {
            dot += "  \(sorted[i].id) -> \(sorted[i + 1].id) [style = invis]\n"
        }
    }
    return dot
}
//
//  GenerateDiagrams.swift
//  Advent
//
//  Created by Johannes Brands on 03/10/2024.
//

// https://graphviz.org

import OSLog
import Foundation

struct Cell: Hashable, CustomStringConvertible {
    let name: String
    let r, c: Int
    var description: String { "\(name)R\(r)C\(c)" }
}

class ASTDiagramGenerator {
    
    let diagramFile: URL
    let grammar: Grammar
    let messageParser: MessageParser?
    
    init(outputFile: URL, grammar: Grammar, messageParser: MessageParser? = nil) {
        self.diagramFile = outputFile
        self.grammar = grammar
        self.messageParser = messageParser
    }

    var content = #"""
        digraph G {
          fontname = Menlo
          fontsize = 10
          node [fontname = Menlo, fontsize = 10, color = gray, height = 0, width = 0, margin= 0.04]
          edge [fontname = Menlo, fontsize = 10, color = gray, arrowsize = 0.3]
          graph [ranksep = 0.1]
          rankdir = "TB"
        """#
//    graph [ordering = out, ranksep = 0.2]

    var endSeqLinks: [(from: GrammarNode, to: GrammarNode)] = []
    var endAltLinks: [(from: GrammarNode, to: GrammarNode)] = []
    var ntrAltLinks: [(from: GrammarNode, to: GrammarNode)] = []
    
    // The Graphviz grammar node grid is stored in a dictionary with the position as key.
    // A Bool value indicates if the node at that position is a true GrammarNode or a skipped node.
    // Absent nodes are absent from the Dictionary.
    var grid: [Cell:Bool] = [:]
    var maxRow = 0
    var maxCol = 0

    // Draw a regular grid of GrammarNodes with arrows for .seq down and .alt to the right.
    func generate() throws {
        
        // MARK: - generate CRF graph
        content.append("\n  subgraph CallReturnForest {")
        content.append("\n    cluster = true")
        
        var shortMessage = grammar.messages[0]
        if shortMessage.count > 20 {
            shortMessage = String(shortMessage.prefix(17))
            shortMessage.append("...")
        }

        content.append("\n    label = <\(shortMessage.whitespaceMadeVisible.graphvizHTML)> \((messageParser?.successfullParses ?? 0) > 0 ? "fontcolor = green" : "fontcolor = red" )")
        content.append("\n    labeljust = l")
        content.append("\n    node [shape = box, style = rounded, height = 0]")
        
        // generate the call return forest
        // Collect all return positions so we can render them as labeled nodes
        var returnPositions: Set<ParsePosition> = []
        for (key, cluster) in (messageParser?.crf ?? [:]).sorted(by: { $0.key < $1.key }) {
            let poppedIndexes = cluster.pops.sorted().description.dropFirst().dropLast()
            content.append("\n    \(key) [label = <\(cluster.slot.ebnfDot().graphvizHTML),\(cluster.index)<br/><font color=\"gray\" point-size=\"8.0\"> \(poppedIndexes)</font>>]")
            for edge in cluster.returns {
                let edgePos = ParsePosition(slot: edge.slot, index: edge.index)
                content.append("\n    \(key) -> \(edgePos)")
                returnPositions.insert(edgePos)
            }
        }
        // render return nodes with dotted EBNF labels
        for rtn in returnPositions.sorted() {
            content.append("\n    \(rtn) [label = <\(rtn.slot.ebnfDot().graphvizHTML),\(rtn.index)>]")
        }
        content.append("\n  }")

        // MARK: - generate the Abstract Syntaxt Tree of GrammarNodes
        // generate syntax graph for each non-terminal
        for (name, node) in grammar.nonTerminals {
            content.append("\n  subgraph cluster\(name) {")
            //        d.append("\n    cluster = true")
            content.append("\n    node [shape = box]")
            content.append("\n    label = <\(node.ebnf().graphvizHTML)>")
            content.append("\n    labeljust = l")
            
            maxRow = 0
            maxCol = 0
            grid = [:]
            
            draw(name: name, node: node, row: 0, col: 0)
            
            addScaffolding(name: name)
            
            content.append("\n  }")
        }
        
//        for (from, to) in endSeqLinks {
//            content.append("\n  \(from.cell):s -> \(to.cell):s [style = solid, color = red, constraint = false]")
//        }
//        for (from, to) in endAltLinks {
//            content.append("\n  \(from.cell):e -> \(to.cell) [style = dotted, color = green, constraint = false]")
//        }
//        for (from, to) in ntrAltLinks {
//            content.append("\n  \(from.cell):e -> \(to.cell) [style = dotted, color = blue, constraint = false]")
//        }
        
        content.append("\n}")
        
        try content.write(to: diagramFile, atomically: true, encoding: .utf8)
    }

    // Draw a pretty picture of a GrammarNode with alt and seq links
    func draw(name: String, node: GrammarNode, row: Int, col: Int) {
        var str = node.name
        if node.kind == .T {
            str = "\"" + str + "\""
        }
        
        node.cell = Cell(name: name, r: row, c: col)
        grid[node.cell] = true
        
        content.append("\n    \(node.cell) [label = <\(node)<br/>\(node.kind) \(str.graphvizHTML)<br/>fi [\(node.first.sorted().joined(separator: ", ").graphvizHTML)]<br/>fo [\(node.follow.sorted().joined(separator: ", ").graphvizHTML)]<br/>\(node.yield.sorted().description.graphvizHTML)>]")
//        content.append("\n    \(node.cell) [label = <\(node)<br/>\(node.kind) \(str.graphvizHTML)<br/>fi [\(node.first.sorted().joined(separator: ", ").graphvizHTML)]<br/>fo [\(node.follow.sorted().joined(separator: ", ").graphvizHTML)]<br/>am [\(node.ambiguous.sorted().joined(separator: ", ").graphvizHTML)]<br/>\(node.actions.joined(separator: "<br/>"))>]")
//        content.append("\n    \(node.cell) [label = <\(node)<br/>\(node.kind) \(str.graphvizHTML)>]")

        if let seq = node.seq {
            if node.kind == .END {
                endSeqLinks.append((from: node, to: seq))
            } else {
                maxRow = max(maxRow, row+1)
                draw(name: name, node: seq, row: row+1, col: col)
//                content.append("\n    \(node.cell):s -> \(seq.cell) [weight=100000000]")
                content.append("\n    \(node.cell) -> \(seq.cell) [weight=100000000]")
            }
        }
        
        if let alt = node.alt {
            // .alt can only point to an ALT node
            if node.kind == .END {
                endAltLinks.append((from: node, to: alt))
            } else if node.kind == .N && node.seq != nil { // rhs nonterminal
                ntrAltLinks.append((from: node, to: alt))
            } else {
                maxCol = max(maxCol+1, col+1)
                
                // fill the row with empty nodes that should not be drawn or connected
                for c in col+1 ..< maxCol {
                    let c = Cell(name: name, r: row, c: c)
                    grid[c] = false
                }
                
                draw(name: name, node: alt, row: row, col: maxCol)
                content.append("\n    rank = same {\(node.cell) -> \(alt.cell)}")
                
            }
        }
    }
    
    // add dummy cells and edges to fool Graphviz into maintaining a rectangular grid
    func addScaffolding(name: String) {
//        d.append("\n    node [color = red]")
//        d.append("\n    edge [color = red]")
        content.append("\n    node [style = invis]")
        content.append("\n    edge [style = invis]")

        // draw the dummy cells and the arrows that go into them
        for r in 0...maxRow {
            for c in 0...maxCol {
                let cell = Cell(name: name, r: r, c: c)
                
                // draw arrows into dummy cell from real cells or dummy cells
                if grid[cell] == nil {
                    if r > 0 {
                        let above = Cell(name: name, r: r-1, c: c)
                        if grid[above] != false {
                            content.append("\n    \(above) -> \(cell) [weight=100000000]")
                        }
                    }
                    if c > 0 {
                        let left = Cell(name: name, r: r, c: c-1)
                        if grid[left] != false {
                            content.append("\n    rank = same {\(left) -> \(cell)}")
                        }
                    }
                    
                // draw arrows into real nodes from dummy cells
                } else if grid[cell] == true {
                    if r > 0 {
                        let above = Cell(name: name, r: r-1, c: c)
                        if grid[above] == nil {
                            content.append("\n    \(above) -> \(cell) [weight=100000000]")
                        }
                    }
                    if c > 0 {
                        let left = Cell(name: name, r: r, c: c-1)
                        if grid[left] == nil {
                            content.append("\n    rank = same {\(left) -> \(cell)}")
                        }
                    }

                }
            }
        }
    }
}
//
//  GenerateParser.swift
//  Advent
//
//  Created by Johannes Brands on 26/12/2024.
//

import OSLog
import Foundation

class ParserGenerator {
    
    let parserFile: URL
    let grammar: Grammar
    
    init(outputFile: URL, grammar: Grammar) {
        self.parserFile = outputFile
        self.grammar = grammar
    }
    
    var content = #"""
        
        // MARK: - start of template code
        import Foundation
        import RegexBuilder
        
        var tokens: [Token] = []
        var cI = 0
        var token: Token { tokens[cI] }
        
        func expect(_ expected: String...) {
            if !expected.contains(token.kind) {
                let position = token.image.base.linePosition(of: token.image.startIndex)
                fatalError("\(position): expected \(expected) but found \"\(token.kind)\"")
            }
        }
        
        // MARK: - start of generated code
        
        """#
    
    func generate() throws {
        
        // Emit preamble actions (global code before everything)
        emit(actions: grammar.preamble)
        
        // TODO: check escapes etc.
        emit(dent: .NR, "let tokenPatterns: [String:TokenPattern] = [")
        for (kind, pattern) in grammar.terminals.sorted(by: { !$0.value.isKeyword && $1.value.isKeyword } ) {
            if pattern.isKeyword {
                emit("\"", kind, "\":\t(", pattern.source, ",\tRegex { ", pattern.source, " },\t", pattern.isKeyword, ",\t", pattern.isSkip, "),")
            } else {
                emit("\"", kind, "\":\t(\"", pattern.source.escapesAdded, "\",\t", pattern.source, ",\t", pattern.isKeyword, ",\t", pattern.isSkip, "),")
            }
        }
        emit(dent: .LN, "]")
        
        for (name, node) in grammar.nonTerminals.sorted(by: { $0.key < $1.key }) {
            if let sig = node.signature {
                emit(dent: .NR, "func ", name, "() ", sig, " {")
            } else {
                emit(dent: .NR, "func ", name, "() throws {")
            }
            // Actions between "=" and body land on the first ALT node
            // and are emitted naturally by emitAlternatives.
            emitAlternatives(firstAlt: node.alt!)
            emit(dent: .LN, "}")
        }
        
        emit(dent: .NR, "func parse() throws {")
        emit("try \(grammar.startSymbol)()")
        emit("expect(\"$\")")
        emit(dent: .LN, "}")
        
        // Emit epilogue actions (global code after everything)
        emit(actions: grammar.epilogue)

        try content.write(to: parserFile, atomically: true, encoding: .utf8)
    }
    
    // Emits dispatch over an ALT chain.
    // Single alternate: emits directly.
    // Two or more: emits switch/case.
    private func emitAlternatives(firstAlt: GrammarNode, dispatched: Set<String>? = nil, defaultBreak: Bool = false) {
        // Collect all ALT nodes
        var alts: [GrammarNode] = []
        var current: GrammarNode? = firstAlt
        while let alt = current {
            alts.append(alt)
            current = alt.alt
        }
        
        if alts.count == 1 {
            // Single alternate: emit directly
            let prefix = emitActionsExtractingPrefix(alts[0].actions)
            emitSequence(alts[0].seq!, dispatched: dispatched, pendingPrefix: prefix)
        } else {
            // Multiple alternates: switch on token kind (grammar is LL(1))
            emit(dent: .NR, "switch token.kind {")
            var allTokens: Set<String> = []
            for alt in alts {
                let tokens = alt.first.subtracting([""])
                if tokens.isEmpty {
                    // Epsilon-only alternate: becomes default case
                    emit(dent: .LR, "default:")
                } else {
                    allTokens.formUnion(tokens)
                    emit(dent: .LR, "case \(commaList(tokens)):")
                }
                let prefix = emitActionsExtractingPrefix(alt.actions)
                emitSequence(alt.seq!, dispatched: tokens, pendingPrefix: prefix)
            }
            if !alts.contains(where: { $0.first.subtracting([""]).isEmpty }) {
                emit(dent: .LR, "default:")
                if defaultBreak {
                    emit("break")
                } else {
                    emit("expect(\(commaList(allTokens)))")
                }
            }
            emit(dent: .LN, "}")
        }
    }
    
    /// Walks a sequence via .seq links, emitting code for each node until END.
    /// When `dispatched` is non-nil, the first terminal in the sequence that matches
    /// a dispatched token emits `next()` instead of `expect()`, since the dispatch
    /// already confirmed the token kind.
    /// Supports prefix actions: if the last action before a symbol ends with `=`,
    /// it is combined with the symbol's generated code on one line.
    private func emitSequence(_ node: GrammarNode, dispatched: Set<String>? = nil, pendingPrefix: String? = nil) {
        var current: GrammarNode? = node
        var dispatched = dispatched
        var pendingPrefix = pendingPrefix
        while let n = current {
            switch n.kind {
            case .T, .TI, .C, .B:
                if let tokens = dispatched, tokens.contains(n.name) {
                    dispatched = nil
                } else {
                    emit("expect(\"\(n.name.escapesAdded)\")")
                }
                if let prefix = pendingPrefix {
                    emit(prefix, " token")
                    pendingPrefix = nil
                }
                emit("cI += 1")
            case .EPS:
                dispatched = nil
                pendingPrefix = nil
            case .N:
                dispatched = nil
                if let prefix = pendingPrefix {
                    emit(prefix, " try \(n.name)()")
                    pendingPrefix = nil
                } else {
                    emit("try \(n.name)()")
                }
            case .DO:
                dispatched = nil
                pendingPrefix = nil
                emitAlternatives(firstAlt: n.alt!)
            case .OPT:
                dispatched = nil
                pendingPrefix = nil
                let tokens = innerFirst(of: n)
                if altCount(from: n.alt!) > 1 {
                    emitAlternatives(firstAlt: n.alt!, defaultBreak: true)
                } else {
                    emit(dent: .NR, "if [\(commaList(tokens))].contains(token.kind) {")
                    emitAlternatives(firstAlt: n.alt!, dispatched: tokens)
                    emit(dent: .LN, "}")
                }
            case .KLN:
                dispatched = nil
                pendingPrefix = nil
                let tokens = innerFirst(of: n)
                emit(dent: .NR, "while [\(commaList(tokens))].contains(token.kind) {")
                emitAlternatives(firstAlt: n.alt!, dispatched: tokens)
                emit(dent: .LN, "}")
            case .POS:
                dispatched = nil
                pendingPrefix = nil
                let tokens = innerFirst(of: n)
                emit(dent: .NR, "repeat {")
                emitAlternatives(firstAlt: n.alt!)
                emit(dent: .LN, "} while [\(commaList(tokens))].contains(token.kind)")
            case .END:
                pendingPrefix = emitActionsExtractingPrefix(n.actions)
               return
            case .ALT:
                fatalError("ALT node encountered in \(#function)")
            case .EOS:
                return
            }
            pendingPrefix = emitActionsExtractingPrefix(n.actions)
            current = n.seq
        }
    }
    
    // MARK: - Prefix Action Helpers
    
    /// Detects whether an action string is a prefix action (ends with `=` but not `==`, `!=`, etc.)
    private func isPrefixAction(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix("=") else { return false }
        for op in ["==", "!=", ">=", "<=", "+=", "-=", "*=", "/="] {
            if trimmed.hasSuffix(op) { return false }
        }
        return true
    }
    
    /// Emits all actions, but if the last one is a prefix action, returns it as pending.
    /// The caller is responsible for combining the pending prefix with the next symbol's code.
    private func emitActionsExtractingPrefix(_ actions: [String]) -> String? {
        guard !actions.isEmpty else { return nil }
        if isPrefixAction(actions.last!) {
            emit(actions: Array(actions.dropLast()))
            return actions.last!
        }
        emit(actions: actions)
        return nil
    }
    
    // MARK: - Helpers
    
    private func commaList(_ set: Set<String>) -> String {
        let escapedSet = set.sorted().map { "\"\($0.escapesAdded)\"" }
        return escapedSet.joined(separator: ", ")
    }
    
    private func altCount(from firstAlt: GrammarNode) -> Int {
        var count = 0
        var current: GrammarNode? = firstAlt
        while let alt = current {
            count += 1
            current = alt.alt
        }
        return count
    }
    
    /// Collects the FIRST tokens of a bracket's inner ALT chain,
    /// excluding epsilon. This avoids using the bracket node's own .first
    /// which has continuation tokens folded in.
    private func innerFirst(of bracket: GrammarNode) -> Set<String> {
        var result: Set<String> = []
        var current = bracket.alt
        while let alt = current {
            result.formUnion(alt.first.subtracting([""])) 
            current = alt.alt
        }
        return result
    }

    // IndentMode specifies the increase or decrease of indentation before and after emitting the items
    enum IndentMode { case NN, LN, NR, LR, RL }

    var indentation = 0
    
    func emit(dent: IndentMode = .NN, _ items: Any..., terminator: String = "\n") {
        switch dent {
        case .NN: break
        case .LN: indentation -= 1
        case .NR: break
        case .LR: indentation -= 1
        case .RL: indentation += 1
        }
        
        for _ in 0 ..< indentation {
            content.append("\t")
        }
        for item in items {
            content.append("\(item)")
        }
        content.append(terminator)
        
        switch dent {
        case .NN: break
        case .LN: break
        case .NR: indentation += 1
        case .LR: indentation += 1
        case .RL: indentation -= 1
        }
    }
    
    func emit(actions: [String]) {
        for action in actions {
            // 1. Split the action string into an array of lines,
            // preserving empty lines between text.
            var lines = action.components(separatedBy: "\n")
            guard !lines.isEmpty else { continue }

            // 2. Check if the FIRST line is only whitespace.
            // If so, remove it from the array.
            if let firstLine = lines.first, firstLine.allSatisfy({ $0.isWhitespace }) {
                lines.removeFirst()
            }

            // 3. Re-verify the array isn't empty after potential first-line removal,
            // then identify the last line to determine the stripping rule.
            guard let lastLine = lines.last else { continue }
            
            // 4. Rule Discovery: If the last line is pure whitespace (upto the trailing @, which was removed from the action),
            // its length is our limit. Otherwise, we strip ALL leading whitespace.
            let isOnlyWhitespace = !lastLine.isEmpty && lastLine.allSatisfy { $0.isWhitespace }
            let maxStripCount = isOnlyWhitespace ? lastLine.count : Int.max
            
            // 5. Select which lines to process.
            // If the last line was just whitespace (used for the count), exclude it from output.
            let linesToProcess = isOnlyWhitespace ? lines.dropLast() : ArraySlice(lines)
            
            for line in linesToProcess {
                var currentLine = line
                var removed = 0
                
                // 6. Strip leading whitespace character-by-character.
                // This stops if we hit a non-whitespace character OR reach the maxStripCount.
                while removed < maxStripCount, let first = currentLine.first, first.isWhitespace {
                    currentLine.removeFirst()
                    removed += 1
                }
                
                // 7. Send the processed line to the final output.
                emit(currentLine)
            }
        }
    }

}
//
//  Grammar.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.13.
//

import OSLog
import AdventMacros
import BitCollections

// Internal sentinel strings for FIRST/FOLLOW sets and the symbol table:
//   end-of-input:  "○" (WHITE CIRCLE U+25CB)
//   epsilon:       ""  (empty string), displayed as "ε"
//   partial-token: "≋" (TRIPLE TILDE U+224B) a.k.a. Frankenstein


// Result of parsing an APUS grammar file.
// Holds all grammar artifacts needed by downstream consumers.
class Grammar {
    var startSymbol: String = ""
    var terminals: [String: TokenPattern] = [:]
    var nonTerminals: [String: GrammarNode] = [:]
    var messages: [String] = []
    var preamble: [String] = []
    var epilogue: [String] = []
    var root: GrammarNode = GrammarNode(kind: .EOS, name: "○")
    var isLL1: Bool = true
    
    // MARK: - Integer Symbol Table
    //
    // The parsing hot path (testSelect, tokenMatch) originally compared strings:
    //   slot.first.contains(token.kind)    — hashes a String, probes a Set<String>
    //   cL.name == token.kind              — compares two Strings
    //
    // To eliminate string hashing/comparison overhead, we assign each terminal
    // a sequential integer ID following the ART numbering convention:
    //   0        = EOS ($)
    //   1..T     = terminals (assigned during grammar construction)
    //   T+1      = epsilon (ε) — a sentinel in first sets signalling nullability
    //
    // Token.kindID and GrammarNode.nameID mirror the string-based kind/name fields.
    // Set<String> first/follow/ambiguous are mirrored by BitSet firstBS/followBS/ambiguousBS.
    // The hot path then uses integer comparison and BitSet.contains() (O(1) bit test).
    // Strings are retained for diagnostics, error messages, and diagram generation.
    
    // the representation of the BNF empty production are:
    // in apus grammar specifications: the empty string "" or any of the many unicode epsilon character variants "ε" "ϵ" "Ԑ" "ԑ" "𝛆" "𝛜" "𝜀" "𝜖" "𝜺" "𝝐" "𝝴" "𝞊" "𝞮" "𝟄"
    // in canonical ebnf() or ebnfDot() output: 'ε' GREEK SMALL LETTER EPSILON U+03B5
    // internally in FIRST and FOLLOW sets: "" (empty string)

    // the representation of the end-of-input token: "○" (BLACK CIRCLE U+25CF), displayed as "$"

    // the representation of a Frankenstein token: "≋" (TRIPLE TILDE U+224B)
    
    /// Maps terminal name → integer ID. Initialised with "○" → 0 (EOS).
    var symbolToID: [String: Int] = ["○": 0]
    
    /// The integer ID for the partial token sentinel in first/follow BitSets.
    /// Set by `finalizeSymbolTable()` after all terminals are registered.
    var frankensteinID: Int!

    /// The integer ID for the epsilon sentinel in first/follow BitSets.
    /// Set by `finalizeSymbolTable()` after all terminals are registered.
    var epsilonID: Int!
    
    /// Register a terminal kind and return its integer ID. Idempotent.
    /// Called from `regex()` and `literal()` during grammar construction.
    @discardableResult
    func registerTerminal(_ name: String) -> Int {
        if let existing = symbolToID[name] { return existing }
        let id = symbolToID.count
        symbolToID[name] = id
        return id
    }
    
    /// Assign epsilon its ID (T+1). Call after all terminals are registered
    /// but before `assignNameIDs()`.
    func finalizeSymbolTable() {
        frankensteinID = symbolToID.count
        symbolToID["≋"] = frankensteinID
        epsilonID = symbolToID.count
        symbolToID[""] = epsilonID
//        for (name, id) in symbolToID {
//            print("ID", id, "for terminal", name)
//        }
    }
    
    /// Walk all grammar nodes and set `nameID` on terminal-like nodes
    /// (.T, .TI, .C, .B, .EOS, .EPS) by looking up their `str` in `symbolToID`.
    /// Nonterminal nodes keep the default `nameID = -1` since they are never
    /// compared against tokens — only terminal nodes need to match token kinds.
    func assignNameIDs() {
        root.nameID = symbolToID["○"]!
        for (_, node) in nonTerminals {
            assignNameIDsRecursive(node)
        }
    }
    
    private func assignNameIDsRecursive(_ node: GrammarNode) {
        switch node.kind {
        case .EOS:
            node.nameID = symbolToID["○"]!
        case .T, .TI, .C, .B:
            node.nameID = symbolToID[node.name]!
        case .EPS:
            node.nameID = epsilonID
        default:
            break
        }
        // Follow seq/alt links, avoiding cycles:
        // - END.seq points back to its bracket
        // - RHS nonterminal .alt points to the LHS definition (would cause infinite loop)
        // LHS nonterminals (seq == nil) must follow .alt to reach their production alternates.
        if node.kind != .END {
            if let seq = node.seq { assignNameIDsRecursive(seq) }
        }
        if node.kind == .N {
            if node.seq == nil, let alt = node.alt { assignNameIDsRecursive(alt) }
        } else if node.kind != .END {
            if let alt = node.alt { assignNameIDsRecursive(alt) }
        }
    }
    
    // MARK: - Schrödinger Exclusion Set Propagation
    //
    // Background: the scanner produces Schrödinger tokens when multiple patterns
    // match the same input at the same length (e.g. "if" matches both the `if`
    // keyword and `plainIdentifier`). The GLL parser explores ALL duals, which
    // is correct but creates many descriptors that will ultimately fail.
    //
    // The `---` annotation in APUS grammar files declares that certain keywords
    // should never be treated as a specific terminal in that context:
    //
    //   identifier = plainIdentifier ---("if" "let" "var" ...) | escapedIdentifier .
    //
    // This means: when the head token is "if", don't try the plainIdentifier dual
    // for this grammar node. The annotation seeds an `exclude` set on the terminal.
    //
    // Propagation: the exclude set is propagated upward through the grammar so that
    // parent nonterminals can reject Schrödinger duals early in `testSelect`,
    // before creating descriptors that would fail deep inside the grammar.
    //
    // The propagation rules are:
    //   - Terminal with `---`:    seed (already set by ApusParser)
    //   - RHS nonterminal N(X):  inherit from LHS definition of X
    //   - LHS nonterminal:       intersection over alternates that contribute the terminal
    //   - ALT:                   inherit from the first seq-chain symbol that contributes
    //   - Bracket (DO/OPT/KLN/POS): intersection over alternates
    //   - Sequence with nullable prefix: skip nullable nodes whose own content doesn't
    //     contribute, continue to the next symbol in the chain
    //
    // Intersection semantics ensure that if ANY path to the terminal lacks an
    // exclusion, the parent conservatively allows the dual (no false rejections).
    // Alternates with empty exclude (not yet resolved) are skipped to let the
    // fixpoint converge for self-referencing rules.
    //
    // The exclude sets are independent of FIRST/FOLLOW — they are computed in a
    // separate pass after FIRST/FOLLOW have converged, and stored in `exclude`
    // (Set<String>) / `excludeBS` (BitSet) on each GrammarNode.
    //
    // At parse time, `testSelect` and `tokenMatch` check: when walking the
    // Schrödinger dual chain, if the head token's kindID is in `slot.excludeBS`,
    // skip the dual.

    /// Entry point: propagate `exclude` sets from seed terminals upward through the grammar.
    /// Call after FIRST/FOLLOW have converged and before `populateBitSets`.
    func propagateExcludeSets() {
        var excludedTerminals: Set<String> = []
        for (_, nt) in nonTerminals {
            collectExcludedTerminals(nt, into: &excludedTerminals)
        }
        guard !excludedTerminals.isEmpty else { return }

        var changed = true
        while changed {
            changed = false
            for (_, nt) in nonTerminals {
                changed = propagateExcludeRecursive(nt, excludedTerminals: excludedTerminals) || changed
            }
        }
    }

    private func collectExcludedTerminals(_ node: GrammarNode, into result: inout Set<String>) {
        if !node.exclude.isEmpty && node.kind.isTerminal {
            result.insert(node.name)
        }
        walkChildren(node) { collectExcludedTerminals($0, into: &result) }
    }

    private func propagateExcludeRecursive(_ node: GrammarNode, excludedTerminals: Set<String>) -> Bool {
        var changed = false

        guard !node.first.isDisjoint(with: excludedTerminals) else {
            return walkChildrenChanged(node, excludedTerminals: excludedTerminals)
        }

        if !node.kind.isTerminal && node.kind != .EPS {
            let newExclude: Set<String>
            switch node.kind {
            case .N where node.seq != nil:
                newExclude = node.alt?.exclude ?? []
            case .N:
                newExclude = intersectExcludesFromAlts(node, excludedTerminals: excludedTerminals)
            case .ALT:
                newExclude = excludeFromSeqChain(node.seq, excludedTerminals: excludedTerminals)
            case .DO, .OPT, .KLN, .POS:
                newExclude = intersectExcludesFromAlts(node, excludedTerminals: excludedTerminals)
            default:
                newExclude = []
            }
            if !newExclude.isEmpty && !newExclude.isSubset(of: node.exclude) {
                node.exclude.formUnion(newExclude)
                changed = true
            }
        }

        return walkChildrenChanged(node, excludedTerminals: excludedTerminals) || changed
    }

    private func intersectExcludesFromAlts(_ node: GrammarNode, excludedTerminals: Set<String>) -> Set<String> {
        var result: Set<String>? = nil
        var alt = node.alt
        while let a = alt {
            if !a.first.isDisjoint(with: excludedTerminals) && !a.exclude.isEmpty {
                if let current = result {
                    result = current.intersection(a.exclude)
                } else {
                    result = a.exclude
                }
            }
            alt = a.alt
        }
        return result ?? []
    }

    private func excludeFromSeqChain(_ start: GrammarNode?, excludedTerminals: Set<String>) -> Set<String> {
        var node = start
        while let n = node {
            if n.kind == .END { break }
            if ownFirstContains(n, excludedTerminals: excludedTerminals) {
                if n.isNullable {
                    let contExclude = excludeFromSeqChain(n.seq, excludedTerminals: excludedTerminals)
                    return contExclude.isEmpty ? n.exclude : n.exclude.intersection(contExclude)
                }
                return n.exclude
            }
            guard n.isNullable else { break }
            node = n.seq
        }
        return []
    }

    /// Does this node's OWN content (not continuation) contribute an excluded terminal to FIRST?
    private func ownFirstContains(_ node: GrammarNode, excludedTerminals: Set<String>) -> Bool {
        switch node.kind {
        case .T, .TI, .C, .B:
            return excludedTerminals.contains(node.name)
        case .N:
            guard let lhs = node.alt else { return false }
            return !lhs.first.isDisjoint(with: excludedTerminals)
        case .DO, .OPT, .KLN, .POS:
            var alt = node.alt
            while let a = alt {
                if !a.first.isDisjoint(with: excludedTerminals) { return true }
                alt = a.alt
            }
            return false
        default:
            return false
        }
    }

    // MARK: - Grammar Graph Traversal Helpers

    /// Visit children of a grammar node (seq and alt links), avoiding cycles.
    private func walkChildren(_ node: GrammarNode, _ visit: (GrammarNode) -> Void) {
        if node.kind != .END, let seq = node.seq { visit(seq) }
        if node.kind == .N {
            if node.seq == nil, let alt = node.alt { visit(alt) }
        } else if node.kind != .END {
            if let alt = node.alt { visit(alt) }
        }
    }

    /// Recurse into children for exclude propagation, returning whether anything changed.
    private func walkChildrenChanged(_ node: GrammarNode, excludedTerminals: Set<String>) -> Bool {
        var changed = false
        walkChildren(node) {
            changed = propagateExcludeRecursive($0, excludedTerminals: excludedTerminals) || changed
        }
        return changed
    }

    /// Convert each node's string-based first/follow/ambiguous `Set<String>`
    /// into the corresponding `firstBS`/`followBS`/`ambiguousBS` `BitSet`,
    /// using `symbolToID` for the mapping.
    /// Call after the first/follow fixpoint has converged and after `detectAmbiguity`.
    func populateBitSets() {
        for (_, node) in nonTerminals {
            populateBitSetsRecursive(node)
        }
    }
    
    private func populateBitSetsRecursive(_ node: GrammarNode) {
        node.firstBS = BitSet()
        for s in node.first {
            if let id = symbolToID[s] { node.firstBS.insert(id) }
        }
        node.followBS = BitSet()
        for s in node.follow {
            if let id = symbolToID[s] { node.followBS.insert(id) }
        }
        node.ambiguousBS = BitSet()
        for s in node.ambiguous {
            if let id = symbolToID[s] { node.ambiguousBS.insert(id) }
        }
        node.excludeBS = BitSet()
        for s in node.exclude {
            if let id = symbolToID[s] { node.excludeBS.insert(id) }
        }
        if node.kind != .END {
            if let seq = node.seq { populateBitSetsRecursive(seq) }
        }
        // Follow alt links, but avoid cycles:
        // - END.alt points back to its enclosing ALT (handled by .END check above)
        // - RHS nonterminal .alt points to the LHS definition (would cause infinite loop)
        // LHS nonterminals (seq == nil) must follow .alt to reach their production alternates.
        if node.kind == .N {
            if node.seq == nil, let alt = node.alt { populateBitSetsRecursive(alt) }
        } else if node.kind != .END {
            if let alt = node.alt { populateBitSetsRecursive(alt) }
        }
    }
}

extension Grammar {
    func populateFirstFollowSets(for node: GrammarNode) throws {
        switch node.kind {
        case .EPS:
            try populateFirstFollowSets(for: node.seq!)
            node.first = node.seq!.first
            updateFollow(for: node)
        case .EOS, .T, .TI, .C, .B:
            try populateFirstFollowSets(for: node.seq!)
//            node.first = [node.name]
            node.first.insert(node.name)    // there may already be a frankenstein sentinel
            updateFollow(for: node)
        case .N:
            try handleNonTerminal(node)
        case .ALT:
            try populateFirstFollowSets(for: node.seq!)
            node.first = node.seq!.first
            node.follow = node.seq!.follow
        case .DO:
            try handleBracket(node)
        case .OPT:
            node.first.insert("")
            try handleBracket(node)
        case .KLN:
            node.first.insert("")
            try handleBracket(node)
        case .POS:
            try handleBracket(node)
        case .END:
            node.first = [""]
            node.follow = node.seq!.follow
            if node.seq!.kind == .KLN || node.seq!.kind == .POS {
                node.follow.formUnion(node.seq!.first.subtracting([""]))
            }
        }
        GrammarNode.sizeofSets += node.first.count + node.follow.count
    }
    
    private func handleNonTerminal(_ node: GrammarNode) throws {
        if let seq = node.seq {
            try populateFirstFollowSets(for: seq)
            updateFollow(for: node)
            if let production = nonTerminals[node.name] {
                node.alt = production
                node.first = production.first
                if node.first.contains("") {
                    node.first.remove("")
                    node.first.formUnion(seq.first)
                }
                production.follow.formUnion(node.follow)
            } else {
                var error = "grammar parse error: '\(node.name)' was not defined as a grammar rule\n"
//                #Trace("grammar parse error: '\(node.name)' was not defined as a grammar rule")
                let definedAsTerminal = terminals[node.name] != nil
                if definedAsTerminal {
                    error += "instead it was defined as terminal \(terminals[node.name]!.source)\n"
                    error += "if this was intended please define the terminal before using it in the grammar"
                    Logger.grammar.error("\(error)")
//                    #Trace("but it was defined as terminal \(terminals[node.name]!.source) instead, if this was intended please define the terminal before using it in the grammar.")
                }
                throw GrammarNodeError.undefinedNonTerminal(name: node.name, definedAsTerminal: definedAsTerminal)
            }
        } else {
            try populateFirstFromAlts(node)
        }
    }
    
    private func handleBracket(_ node: GrammarNode) throws {
        try populateFirstFromAlts(node)
        try populateFirstFollowSets(for: node.seq!)
        if node.first.contains("") {
            node.first.remove("")
            node.first.formUnion(node.seq!.first)
        }
        updateFollow(for: node)
    }
    
    private func populateFirstFromAlts(_ node: GrammarNode) throws {
        var current = node.alt
        while let altNode = current {
            try populateFirstFollowSets(for: altNode)
            node.first.formUnion(altNode.first)
            current = altNode.alt
        }
    }
    
    private func updateFollow(for node: GrammarNode) {
        node.follow = node.seq!.first
        if node.follow.contains("") {
            node.follow.remove("")
            node.follow.formUnion(node.seq!.follow)
        }
    }
}
//
//  GrammarDiagnostics.swift
//  Advent
//
//  Created by Johannes Brands on 2026.04.12.
//

import OSLog
import AdventMacros

extension GrammarNode {

    func detectAmbiguity() {
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            seq?.detectAmbiguity()
        case .N:
            if let seq { // rhs
                seq.detectAmbiguity()
                // For a RHS nonterminal, check the definition's FIRST (via alt)
                // against this position's FOLLOW. The positional 'first' includes
                // look-through tokens from the continuation, which would cause
                // false conflicts.
                if let production = alt, production.isNullable {
                    let definitionFirst = production.first.subtracting([""])
                    ambiguous = definitionFirst.intersection(follow)
                }
            } else { // lhs
//                Logger.grammar.debug("detectAmbiguity in RULE: \(self.name)")
                handleAlternatesAmbiguity()
            }
        case .ALT:
            seq?.detectAmbiguity()
        case .DO, .POS, .OPT, .KLN:
            seq?.detectAmbiguity()
            handleAlternatesAmbiguity()
        case .END:
            break
        }
        if !ambiguous.isEmpty {
            GrammarNode.isLL1 = false
        }
        let saved = traceIndent
        traceIndent += 2
        #Trace(kind, number)
        traceIndent += 2
        #Trace("first    ", first.sorted())
        #Trace("follow   ", follow.sorted())
        #Trace("ambiguous", ambiguous.sorted())
//        if !ambiguous.isEmpty {
//            if kind == .N, seq == nil {
//                print("Ambiguity in \(name)", ambiguous.sorted())
//            }
//        }
        traceIndent = saved
        
//        identifierKeywordConflict()

    }

    private func handleAlternatesAmbiguity() {
        // ambiguity set of KLN and POS is the intersection of follow(KLN) with the union of the pairwise intersections of all its first(ALT)'s ('duplicates')

        var occurances: [String:Int] = [:]
        // count occurances in firsts
        var current = self.alt
        while let altNode = current {
            current?.detectAmbiguity()
            for element in altNode.first {
                occurances[element, default: 0] += 1
            }
            current = altNode.alt
        }
        // count occurances in follow only when this node can derive ε,
        // because a token in FOLLOW then competes with the alternates' FIRST tokens
        if isNullable {
            for element in follow {
                occurances[element, default: 0] += 1
            }
        }
        // keep only duplicated occurances
        for (element, count) in occurances where count > 1 {
            ambiguous.insert(element)
        }
        if !ambiguous.isEmpty {
            isLocallyLL1 = false
        }
    }
    
}

extension GrammarNode {

    func detectSchrödingerConflict() {
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            seq?.detectSchrödingerConflict()
        case .N:
            if let seq { // rhs
                seq.detectSchrödingerConflict()
            } else { // lhs
//                Logger.grammar.debug("detectSchrödingerConflict in RULE: \(self.name)")
                handleAlternatesSchrödingerConflict()
            }
        case .ALT:
            seq?.detectSchrödingerConflict()
        case .DO, .POS, .OPT, .KLN:
            seq?.detectSchrödingerConflict()
            handleAlternatesSchrödingerConflict()
        case .END:
            break
        }
        identifierKeywordConflict()
    }

    func possibleMatch(of tokenType: String, with: String) -> Bool {
        return true
    }
    
    func possibleIdentifier(_ element: String) -> Bool {
        let startsWithLetter = element.first?.isLetter ?? false
        let isKeyword = GrammarNode.grammar?.terminals[element]?.isKeyword == true
        return startsWithLetter && isKeyword
    }
    
    func identifierKeywordConflict() {
        if first.contains("plainIdentifier") {
            let overlap = Set(first.filter { possibleIdentifier($0) })
            if !overlap.isEmpty {
                print("Schrödinger NODE plainIdentifier ~ \(overlap.sorted())\n  \(self.ebnfDot())")
            }
        }
    }

    private func handleAlternatesSchrödingerConflict() {
        // Schrödinger tokens may match additional branches compared with the pure FIRST and FOLLOW sets.
        // this creates more GLL descriptors and more work.
        // here we check ambiguous overlap between plainIdentifier and keywords
        var schrödingerAlert = false
        var conflicts: Set<String> = []
        
        var current = self.alt
        while let altNode = current {
            current?.detectSchrödingerConflict()
//            Logger.grammar.debug("ALT: \(altNode.first.sorted())")
            if first.contains("plainIdentifier") {
                schrödingerAlert = true
            } else {
                for element in altNode.first {
                    if possibleIdentifier(element) {
                        conflicts.insert(element)
                    }
                }
            }
            current = altNode.alt
        }
        
        // inspect elements in follow only when this node can derive ε,
        // because a token in FOLLOW then competes with the alternates' FIRST tokens
        if isNullable {
            if follow.contains("plainIdentifier") {
                schrödingerAlert = true
            } else {
                for element in follow {
                    if possibleIdentifier(element) {
                        conflicts.insert(element)
                    }
                }
            }
        }
        if schrödingerAlert && !conflicts.isEmpty {
            print("Schrödinger ALTERNATES plainIdentifier ~ \(conflicts.sorted())\n  \(self.ebnfDot())")
        }
    }
    
}
//
//  GrammarNode.swift
//  Advent
//
//  Created by Johannes Brands on 20/05/2024.
//

//enum GKind { case EOS, T, EPS, N, ALT, END }
//enum GKind { case EOS, T, TI, C, B, EPS, N, ALT, END, DO, OPT, POS, KLN }
//enum ApusKind { case EOS, TRM, EPS, NTR, ALT, END, ONE, ZOO, OOM, ZOM }
//enum SwiftKind { case endOfString, terminal, epsilon, nonTerminal, alternate, end, one, zeroOrOne, oneOrMore, zeroOrMore}
/*
 EOS    end of string ("$")
 T      terminal (singleton, case sensitive)
 TI     terminal (singleton, case insensitive)
 C      terminal character
 B      terminal builtin (whitespace, comment, etc)
 EPS    empty string ("#" or "")
 N      nonterminal
 ALT    start of alternate
 END    end of alternate
 DO     group ()
 OPT    optional []
 POS    one or more <>
 KLN    zero or more (Kleene) {}
 
 END.seq references start of production 'N'
 END.alt references start of alternate 'ALT'
 Extends naturally to EBNF brackets if END.alt references the enclosing bracket 'DO', 'OPT', 'POS', or 'KLN'
 */

import OSLog
import Foundation
import AdventMacros
import BitCollections

enum GrammarNodeError: Error {
    case undefinedNonTerminal(name: String, definedAsTerminal: Bool)
}

enum GrammarNodeKind { case EOS, T, TI, C, B, EPS, N, ALT, END, DO, OPT, POS, KLN }

extension GrammarNodeKind {
    var isTerminal: Bool { self == .T || self == .TI || self == .C || self == .B }
    var isBracket:  Bool { self == .DO || self == .OPT || self == .KLN || self == .POS }
    var isLeaf:     Bool { isTerminal || self == .EPS }
    var isClosure:  Bool { self == .KLN || self == .POS }
}

final class GrammarNode {
    
//    var frankensteinMatchAllowed = false    // only relevant for GrammarNodes with kind = "literal"
    
    static var count = 0
    
    // this is to give GrammarNodes access to the grammar
    static weak var grammar: Grammar?
    
    var number = 0
    /// Integer ID from `Grammar.symbolToID`, set by `assignNameIDs()`.
    /// Only meaningful for terminal-like nodes (.T, .TI, .C, .B, .EOS, .EPS);
    /// nonterminals keep the default -1. Used by `tokenMatch()` for O(1) integer comparison.
    var nameID: Int!
    
    let kind: GrammarNodeKind
    let name: String
    
    var alt, seq, prv: GrammarNode?
//    var alt: GrammarNode? {
//        didSet {
//            // alt is overloaded:
//            // - ALT/END nodes: alt points to an .ALT node
//            // - RHS nonterminals (N with seq): alt points to the LHS .N definition
//            if let alt {
//                switch kind {
//                case .N where seq != nil:
//                    assert(alt.kind == .N, "RHS nonterminal alt should point to its LHS .N definition, got \(alt.kind)")
//                default:
//                    assert(alt.kind == .ALT, "alt should always point to a .ALT node, got \(alt.kind)")
//                }
//            }
//        }
//    }
//    var seq: GrammarNode? {
//        didSet {
//            assert(seq?.kind != .ALT, "seq should never point to a .ALT node")
//        }
//    }
    init(kind: GrammarNodeKind, name: String, alt: GrammarNode? = nil, seq: GrammarNode? = nil) {
        self.kind = kind
        self.name = name
        self.alt = alt
        self.seq = seq
    }
    
    var actions: [String] = []  // stores semantic actions
    var signature: String?      // function signature text (params, throws, return) for .N nodes
    var locals: [String] = []   // local declarations for generated function  TODO: can this be removed ???
    
    // first is a positional prediction set: the tokens that can appear at this
    // position in the sequence, including look-through of nullable elements.
    // During FIRST/FOLLOW propagation (Grammar.handleBracket), ε is removed
    // from OPT/KLN and replaced by the continuation's FIRST (concatenation rule).
    // This means first does NOT contain ε for OPT/KLN, even though they are
    // intrinsically nullable. Use isNullable for nullability checks instead.
    var first:      Set<String> = []
    var follow:     Set<String> = []
    var ambiguous:  Set<String> = []

    /// Exclusion set for Schrödinger dual suppression.
    /// When a Schrödinger token's primary (head) kindID is in `excludeBS`,
    /// the parser will not try this node's dual path.
    /// Populated by `---("if" "let" ...)` annotations in APUS grammar rules.
    var exclude:    Set<String> = []

    /// BitSet mirrors of first/follow/ambiguous/exclude, populated by `Grammar.populateBitSets()`.
    /// Used by `testSelect()` and the follow check on the hot path for O(1) membership tests.
    var firstBS:      BitSet = []
    var followBS:     BitSet = []
    var ambiguousBS:  BitSet = []
    var excludeBS:    BitSet = []
    
    static var sizeofSets = 0
    static var isLL1 = true
    
    /// Per-node LL(1) flag: true when this nonterminal or bracket has disjoint
    /// prediction sets across its alternates. Used to enable early termination
    /// in addDecscriptorsForAlternates(). Default true, set to false during detectAmbiguity().
    var isLocallyLL1 = true
    
    // Whether this node is intrinsically nullable (can derive ε).
    // Per Definition 6 of "GLL syntax analysers for EBNF grammars":
    // FIRST([ψ]) = FIRST(ψ) ∪ {ε} and FIRST({ψ}) = FIRST(ψ) ∪ {ε}
    // OPT and KLN are always nullable by definition.
    var isNullable: Bool {
        switch kind {
        case .OPT, .KLN: return true
        default: return first.contains("")
        }
    }
    
    var yield: Set<BinarySpan> = []
    
    var cell = Cell(name: "", r: 0, c: 0)
}

extension GrammarNode {
    func isExpecting(_ token: Token) -> Bool {
        if first.contains(token.kind) {
            return true
        } else if first.contains("") && follow.contains(token.kind) {
            return true
        } else {
            var expectedTokens = first
            if first.contains("") {
                expectedTokens.formUnion(follow)
            }
            #Trace("expected \"\(token.kind)\" to be in", expectedTokens)
            return false
        }
    }
}

extension GrammarNode {
    /// LHS nonterminal: defines a production rule (has .alt chain, no .seq)
    var isLHS: Bool { kind == .N && seq == nil }
    
    /// RHS nonterminal: reference inside a sequence (has .seq, .alt → LHS definition)
    var isRHS: Bool { kind == .N && seq != nil }
    
    /// Collect the symbols of an alternate's body: walk .seq chain until .END.
    /// Call on an ALT node.
    var bodySymbols: [GrammarNode] {
        var symbols: [GrammarNode] = []
        var s = seq
        while let n = s {
            if n.kind == .END { break }
            symbols.append(n)
            s = n.seq
        }
        return symbols
    }
    
    /// Find the END node inside a bracket's first alternate body.
    var bracketEndNode: GrammarNode? {
        guard kind.isBracket else { return nil }
        var node = alt?.seq
        while let n = node {
            if n.kind == .END { return n }
            node = n.seq
        }
        return nil
    }
}

extension GrammarNode: Hashable {
    static func == (lhs: GrammarNode, rhs: GrammarNode) -> Bool {
        lhs.number == rhs.number
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}

extension GrammarNode: CustomStringConvertible {
    
    var description: String { number.description }
    
    // generate labels like A, B, C, ... AA, AB, AC, ...
    var _description: String {
        if kind == .EOS { return "00" }
        let latin = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        func toLatin(_ n: Int) -> String {
            let letter = String(latin[n % 26])
            if n < 26 {
                return letter
            } else {
                return toLatin(n / 26 - 1) + letter
            }
        }
        return toLatin(self.number).graphvizHTML
    }
    
    var __description: String {
        let greek = Array("αβγδεζηθικλμνξοπρστυφχωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ")
        func toGreek(_ n: Int) -> String {
            let letter = String(greek[n % 24])
            if n < 24 {
                return letter
            } else {
                return toGreek(n / 24 - 1) + letter
            }
        }
        return toGreek(self.number)
    }
    
    var kindName: String {
        "." + String(describing: self.kind).prefix(3)
    }
}

extension GrammarNode {
    // sets the .seq and .alt links for END nodes
    // sets the .prv links for all nodes (except LHS nonTerminals that have neither valid .seq nor .prv)
    func resolveGrammarNodeLinks(parent: GrammarNode?, alternate: GrammarNode?) {
        number = GrammarNode.count
        GrammarNode.count += 1
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            seq?.resolveGrammarNodeLinks(parent: parent, alternate: alternate)
            seq?.prv = self
        case .N:
            if isRHS {
                seq?.resolveGrammarNodeLinks(parent: parent, alternate: alternate)
                seq?.prv = self
            } else {
                alt?.resolveGrammarNodeLinks(parent: self, alternate: alternate)
            }
        case .ALT:
            seq?.resolveGrammarNodeLinks(parent: parent, alternate: self)
            seq?.prv = self
            alt?.resolveGrammarNodeLinks(parent: parent, alternate: alternate)
            prv = parent
        case .DO, .POS, .OPT, .KLN:
            alt?.resolveGrammarNodeLinks(parent: self, alternate: alternate)
            seq?.resolveGrammarNodeLinks(parent: parent, alternate: alternate)
            seq?.prv = self
        case .END:
            seq = parent
            alt = alternate
        }
    }
}

extension GrammarNode {
    func clearNodes() {
        yield = []
        // recursively clear child nodes but avoid loops from END node .seq and .alt links
        if kind != .END {
//            alt?.clearNodes()
            seq?.clearNodes()
        }
        // TODO: check if this treatment of .N is correct
        if kind != .END && kind != .N {
            alt?.clearNodes()
        }
    }
}

extension GrammarNode {
    /// Label for a bracket node showing only its own content, not the continuation.
    /// e.g. `{ "a" }` instead of `{ "a" } { "a" }`.
    func bracketLabel() -> String {
        switch kind {
        case .DO:  return "(\((alt?.ebnf() ?? "").trimmingCharacters(in: .whitespaces)))"
        case .OPT: return "[\((alt?.ebnf() ?? "").trimmingCharacters(in: .whitespaces))]"
        case .POS: return "<\((alt?.ebnf() ?? "").trimmingCharacters(in: .whitespaces))>"
        case .KLN: return "{\((alt?.ebnf() ?? "").trimmingCharacters(in: .whitespaces))}"
        default:   return name
        }
    }
    
    // when called on a lhs nonterminal GrammarNode this generates its full EBNF grammar
    func ebnf() -> String {
        var s = ""
        switch kind {
        case .EOS, .EPS:
            s += name + " "
            if let seq { s += seq.ebnf() }
        case .T, .TI, .C, .B:
            s += "\"" + name + "\" "
            if let seq { s += seq.ebnf() }
        case .N:
            if let seq { // rhs
                s += name + " " + seq.ebnf()
            } else { // lhs
                if let alt {
                    s += name + " = " + alt.ebnf() + "."
                }
            }
        case .ALT:
            if let seq { s += seq.ebnf() }
            if let alt { s +=  "| " + alt.ebnf() }
        case .END:
            break
        case .DO:
            if let alt { s += "( " + alt.ebnf() + ") " }
            if let seq { s += seq.ebnf() }
        case .OPT:
            if let alt { s += "[ " + alt.ebnf() + "] " }
            if let seq { s += seq.ebnf() }
        case .POS:
            if let alt { s += "< " + alt.ebnf() + "> " }
            if let seq { s += seq.ebnf() }
        case .KLN:
            if let alt { s += "{ " + alt.ebnf() + "} " }
            if let seq { s += seq.ebnf() }
        }
        return s
    }
}


extension GrammarNode {
    static var containingNonterminal: GrammarNode?          // will be set to the containing N (lhs) node
    static var toplevelAlternate: GrammarNode?              // will be set to the toplevel ALT node
    static var dottedSlot: GrammarNode?                     // will be set to the dotted GrammarNode slot
    static var dottedEBNF = ""                              // will be set to the dotted EBNF production
    enum Exit: Error { case endOfToplevel }
    
    func emit() throws {
        let middleDot = "\u{00B7}"
        switch kind {
        case .EOS, .T, .TI, .C, .B, .EPS:
            GrammarNode.dottedEBNF += name
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if let seq { try seq.emit() }
        case .N:
            if let seq { // rhs
                GrammarNode.dottedEBNF += name
                if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
                try seq.emit()
            } else { // lhs
                GrammarNode.dottedEBNF += name
            }
        case .ALT:
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if let seq { try seq.emit() }
            if let alt {
                GrammarNode.dottedEBNF +=  "|"
                try alt.emit()
            }
        case .END:
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if seq?.kind == .N {
                // this is the end of the top level alternate
                GrammarNode.containingNonterminal = seq
                GrammarNode.toplevelAlternate = alt
                throw Exit.endOfToplevel
            }
        case .DO:
            if let alt {
                GrammarNode.dottedEBNF += "("
                try alt.emit()
                GrammarNode.dottedEBNF += ")"
            }
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if let seq { try seq.emit() }
        case .OPT:
            if let alt {
                GrammarNode.dottedEBNF += "["
                try alt.emit()
                GrammarNode.dottedEBNF += "]"
            }
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if let seq { try seq.emit() }
        case .POS:
            if let alt {
                GrammarNode.dottedEBNF += "<"
                try alt.emit()
                GrammarNode.dottedEBNF += ">"
            }
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if let seq { try seq.emit() }
        case .KLN:
            if let alt {
                GrammarNode.dottedEBNF += "{"
                try alt.emit()
                GrammarNode.dottedEBNF += "}"
            }
            if self == GrammarNode.dottedSlot { GrammarNode.dottedEBNF += middleDot }
            if let seq { try seq.emit() }
        }
    }
    
    func toplevels() -> (GrammarNode?, GrammarNode?) {
        // returns the the highest level alternate and the containing nonterminal
        var node = self
        while node.seq != nil {
            if node.kind == .END && node.seq?.kind == .N {
                return (node.alt, node.seq)
            }
            else {
                node = node.seq!
            }
        }
        return (nil, nil)
    }
    
    // generates the dotted ebnf for the toplevel containing alternate of the containing nonterminal
    // the dot is placed after the dottedSlot node:
    //   terminal/nonterminal: dot after the symbol  e.g. S="a"·{"a"}
    //   bracket (KLN etc):    dot after closing }   e.g. S="a"{"a"}·
    //   ALT:                  dot at start of body  e.g. S="a"{·"a"}
    //   END:                  dot at end of body    e.g. S="a"{"a"·}
    func ebnfDot() -> String {
        if kind == .N && seq == nil {
            // a lhs nonterminal
            return name
        } else {
            // construct the ebnf for the toplevel alternate production containing the dot
            GrammarNode.dottedEBNF = ""
            GrammarNode.dottedSlot = self
            (GrammarNode.toplevelAlternate, GrammarNode.containingNonterminal) = toplevels()
            if let tla = GrammarNode.toplevelAlternate, let cnt = GrammarNode.containingNonterminal {
                try? tla.emit()
                return cnt.name + "=" + GrammarNode.dottedEBNF
            } else {
                return GrammarNode.dottedEBNF
            }
        }
    }
}
//
//  Loggers.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.29.
//

import OSLog

extension Logger {
    /// Use your bundle ID for the subsystem to ensure unique logs
    /// (not available in macOS console apps)
    private static var subsystem = "com.magenta.apusParser"

    /// Categories help you filter logs in the Xcode console
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let scan = Logger(subsystem: subsystem, category: "scan")
    static let parse = Logger(subsystem: subsystem, category: "parse")
    static let grammar = Logger(subsystem: subsystem, category: "grammar")
    static let generate = Logger(subsystem: subsystem, category: "generate")
}
//
//  main.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

import OSLog
import Foundation

//import RegexBuilder
//import AdventMacros

//import ArgumentParser
//@main
//struct Repeat: ParsableCommand {
//  @Argument(help: "The phrase to repeat.")
//  var phrase: String
//
//  @Option(help: "The number of times to repeat 'phrase'.")
//  var count: Int? = nil
//
//  mutating func run() throws {
//    let repeatCount = count ?? .max
//
//    for i in 1...repeatCount {
//      print(phrase)
//    }
//  }
//}

//func run() {

trace = false

// transform the APUS EBNF grammar from the input file into a grammar tree (Abstract Syntax Tree)
// by using grammarParser, which is a hand-built recursive descent parser
// then use the grammar tree as an interpretor to parse a message.
// then generate a stand-alone parser

let grammarFileURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("apus")
//    .appendingPathComponent("ScanModeTest")
//    .appendingPathComponent("Swift")
//    .appendingPathComponent("CommentTest")
//    .appendingPathComponent("attributeHunt")
//    .appendingPathComponent("AfroozehHunt")
//    .appendingPathComponent("apusWithAction")
//    .appendingPathComponent("TortureSyntax")
//    .appendingPathComponent("test")
//    .appendingPathComponent("silent")
//    .appendingPathComponent("tortureART")
//    .appendingPathComponent("tortureEBNF")
//    .appendingPathComponent("apusAmbiguous")
    .appendingPathExtension("apus")

let grammar: Grammar
do {
    let apusParser = try ApusParser(fromFile: grammarFileURL)
    do {
        grammar = try apusParser.parse(explicitStartSymbol: "")
    } catch {
        Logger.ui.error("failed to parse grammar: \(grammarFileURL), error: \(error)")
        exit(1)
    }
} catch {
    Logger.ui.error("failed to scan grammar: \(grammarFileURL), error: \(error)")
    exit(1)
}

let messageParser = MessageParser(grammar: grammar)

print("grammar: \(grammarFileURL.lastPathComponent), messages: \(grammar.messages.count)")
if grammar.messages.isEmpty {
    print("no messages found (^^^ blocks). nothing to parse")
}

for message in grammar.messages {
    let messageScanner: Scanner
    do {
        if message.hasPrefix("#") {
            let fileName = message.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            let messageFileURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent(fileName)
            let fileMessage = try String(contentsOf: messageFileURL, encoding: .utf8)
            messageScanner = try Scanner(fromString: fileMessage, patterns: grammar.terminals)
        } else {
            messageScanner = try Scanner(fromString: message, patterns: grammar.terminals)
        }
    } catch {
        Logger.ui.error("failed to scan message: \(message.prefix(100))...")
        continue
    }

    // use the AST to parse the message
    let start = clock()

    for _ in 0..<1 {
        messageParser.parse(tokens: messageScanner.tokens)
    }

    let end = clock()
    let cpuTime = Double(end - start) / Double(CLOCKS_PER_SEC)
    var stats = "cpuTime, descriptorCount, crf.count, sizeOfSets, yieldCount\n"
    stats += "\(cpuTime), \(messageParser.descriptorCount), \(messageParser.crf.count), \(GrammarNode.sizeofSets), \(messageParser.yieldCount)\n"
    stats += "descriptor size: \(MemoryLayout<Descriptor>.size) bytes"
    Logger.ui.info("\(stats)")
//    print("all tokens:")
//    for t in messageScanner.tokens.indices {
//        for s in messageScanner.skippedTokens[t] {
//            print(s)
//        }
//        print(messageScanner.tokens[t])
//    }
//    print("tokensPatterns:")
//    for tp in grammar.terminals {
//        print(tp.key, tp.value.source)
//    }

//    do {
//        var keywords: [String] = []
//        var macro: [String] = []
//        var punctuation: [String] = []
//        for (key, value) in grammar.terminals {
//            if value.isKeyword {
//                if let first = key.first, first.isLetter {
//                    keywords.append(key)
//                } else if let first = key.first, first == "#" {
//                    macro.append(key)
//                } else{
//                    punctuation.append(key)
//                }
//            }
//        }
//        for k in keywords.sorted() {
//            print("\"\(k)\" ", terminator: "")
//        }
//        print()
//        for m in macro.sorted() {
//            print("\"\(m)\" ", terminator: "")
//        }
//        print()
//        for p in punctuation.sorted() {
//            print("\"\(p)\" ", terminator: "")
//        }
//    }
//    print(cpuTime, messageParser.descriptorCount, messageParser.crf.count)

    // Sort elements (if BSR is Comparable) then join
    //    // Global BSR set removed; to inspect yields, iterate per grammar node.
    //    // Example: print total distributed-yield cardinality used by stats.
    //    // Logger.parse.debug("yieldCount = \(messageParser.yieldCount)")



#if DEBUG
    trace = false
    var info = ""

    if grammar.nonTerminals.count < 1000 && messageParser.crf.count < 1000 {    // to avoid huge diagrams and parsers

        // MARK: - Generate New Parser

        let parserFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("GeneratedParser")
            .appendingPathComponent(grammar.startSymbol + "_parser")
            .appendingPathExtension("swift")
        info += "LL1 is \(grammar.isLL1)\n"
        if grammar.isLL1 {
            let parserGenerator = ParserGenerator(outputFile: parserFile, grammar: grammar)
            try parserGenerator.generate()
            info += "LL1 recursive descent parser written to \(parserFile.lastPathComponent)\n"
        }

        // MARK: - Generate CRF and AST diagrams

        let diagramFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("ART")
            .appendingPathExtension("gv")
        let diagramGenerator = ASTDiagramGenerator(outputFile: diagramFile, grammar: grammar, messageParser: messageParser)
        try diagramGenerator.generate()
        info += "AST diagram written to \(diagramFile.lastPathComponent)\n"
//    }

        // MARK: - Generate SPPF Diagram
        let sppfExtractor = SPPFExtractor(grammar: grammar, tokens: messageScanner.tokens)

        if let sppfRoot = sppfExtractor.extractSPPF() {
            let sppfFile = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("SPPF")
                .appendingPathExtension("gv")
            try generateSPPFDiagram(outputFile: sppfFile, root: sppfRoot)
            info += "SPPF diagram written to \(sppfFile.lastPathComponent)\n"
        } else {
            Logger.ui.warning( "SPPF: no parse tree to extract")
        }

        // MARK: - Generate Derivation Diagram
        let derivFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Derivations")
            .appendingPathExtension("gv")
        try generateDerivationDiagram(outputFile: derivFile, grammar: grammar, tokens: messageScanner.tokens)
        info += "Derivation diagram written to \(derivFile.lastPathComponent)\n"

        Logger.ui.info("\(info)")
    }
#endif

//    Logger.ui.debug("first/follow set size: \(GrammarNode.sizeofSets) terminals.count: \(grammar.terminals.count) nonTerminals.count: \(grammar.nonTerminals.count)")

}
//}

//
//  MessageParser.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.15.
//

// GLL message parser encapsulating all parsing state.
// Paper: cL = current grammar slot
// Paper: cI — current input position (the current active token)
// Paper: cU — current cluster index (identifies a CRF cluster node together with the nonterminal; its value is the input position where the nonterminal was called)
// Paper: R = pending descriptors, U = processed descriptors
// Paper: dscAdd/dscGet = descriptor operations, ntAdd = nonterminal alternates
// Paper: call = enter nonterminal, rtn = return from nonterminal
// Paper: bsrAdd = add BSR element

import OSLog
import Foundation
import AdventMacros

class MessageParser {

    // MARK: - Per-construction (immutable after init)
    let grammar: Grammar

    // MARK: - Per-parse input
    var tokens: [Token] = []

    // MARK: - GLL algorithm state (paper variables)
    var currentParseRoot: GrammarNode!
    var cL: GrammarNode!                    // current grammar slot
    var cI: TokenPosition = .zero           // current input position
    var cU: TokenPosition = .zero           // current cluster index

    // MARK: - Descriptor management (Paper: R, U)
    var remaining: [Descriptor] = []
    var unique: Set<Descriptor> = []

    // MARK: - Parse statistics
    var failedParses = 0
    var successfullParses = 0
    var descriptorCount = 0
    var duplicateDescriptorCount = 0
    var suppressedDescriptorCount = 0

    // MARK: - Call Return Forest (Paper: CRF)
    var crf: [ParsePosition: ParseCluster] = [:]

    // MARK: - Binary Subtree Representation (Paper: Υ)
    var yieldCount = 0

    // MARK: - Error reporting, captures the furthest the parse has progressed before a mismatch occurred
    var furthestMismatchIndex: TokenPosition = .zero
    var furthestMismatchSlot: GrammarNode!
    var furthestMismatchExpected: Set<String> = []

    // MARK: - Initialization

    init(grammar: Grammar) {
        self.grammar = grammar
    }

    // MARK: - Parse API

    func parse(tokens: [Token]) {
        // Reset all per-parse state
        self.tokens = tokens
        // Map each token's string kind to its integer kindID from the symbol table.
        // This includes Schrödinger duals (linked via token.dual) which represent
        // ambiguous scanner matches of equal length.
        for token in tokens {
            var t: Token? = token
            while let current = t {
                current.kindID = grammar.symbolToID[current.kind]!
                t = current.dual
            }
        }
        currentParseRoot = grammar.root
        cL = nil; cI = .zero; cU = .zero
        unique = []; remaining = []
        failedParses = 0; successfullParses = 0
        descriptorCount = 0; duplicateDescriptorCount = 0; suppressedDescriptorCount = 0
        crf = [:]; yieldCount = 0
        furthestMismatchIndex = .zero
        furthestMismatchSlot = currentParseRoot
        furthestMismatchExpected = []

        // Set up root cluster
        let rootCluster = ParseCluster(slot: grammar.root, index: .zero)
        crf[ParsePosition(slot: grammar.root, index: .zero)] = rootCluster
        grammar.root.clearNodes()

        // Seed initial descriptors (Paper: ntAdd for start symbol)
        addDecscriptorsForAlternates(X: grammar.root, k: .zero, i: .zero)

        // Run GLL algorithm
        var progressCounter = 0
        let progressInterval = 10_000
        let totalTokens = tokens.count
        nextDescriptor: while getDescriptor() {
            progressCounter += 1
            if progressCounter % progressInterval == 0 {
                print("  progress: \(progressCounter) descriptors processed, token \(cI.tokenIndex)/\(totalTokens), pending \(remaining.count), crf \(crf.count)")
            }

            while true {

                trace = false
                #Trace("slot: \(String(format: "%2d", cL.number)) \(cL.ebnfDot()) first \(cL.first) follow \(cL.follow) token: \(tokens[cI.tokenIndex].kind) \(tokens[cI.tokenIndex].image)")

                switch cL.kind {
                case .EPS:
                    addYield(L: cL, i: cU, k: cI, j: cI)
                    cL = cL.seq!
                case .T, .TI, .C, .B:
                    if let next = tokenMatch() {
                        addYield(L: cL, i: cU, k: cI, j: next)
                        cI = next
                        cL = cL.seq!
                    } else {
                        failedParses += 1
                        if cI > furthestMismatchIndex {
                            furthestMismatchIndex = cI
                            furthestMismatchSlot = cL
                            furthestMismatchExpected = [cL.name]
                        } else if cI == furthestMismatchIndex {
                            furthestMismatchExpected.insert(cL.name)
                        }
                        continue nextDescriptor
                    }
                case .N:
                    call()
                    continue nextDescriptor
                case .ALT:
                    #Trace("ERROR: Unexpected .ALT node in cL")
                    #Trace("  cL.number: \(cL.number)")
                    #Trace("  cL.name: '\(cL.name)'")
                    #Trace("  cL.seq: \(String(describing: cL.seq))")
                    #Trace("  cL.alt: \(String(describing: cL.alt))")
                    fatalError(#function + ": ALT should not happen here")
                case .DO, .POS:
                    bracketCall(bracket: cL)
                    continue nextDescriptor
                case .OPT, .KLN:
                    // OPT/KLN: also offer skip-past-bracket path (they're nullable)
                    if testSelect(slot: cL.seq!, bracket: cL) {
                        addDescriptor(L: cL.seq!, k: cU, i: cI)
                        addYield(L: cL, i: cU, k: cI, j: cI)  // empty bracket BSR
                    }
                    bracketCall(bracket: cL)
                    continue nextDescriptor
                case .END:
                    // the seq link of an END node always points back to a starting bracket node (N, DO, OPT, POS, KLN)
                    let bracket = cL.seq!

                    switch bracket.kind {
                    case .N:
                        if let seq = bracket.seq {
                            // the bracket is a RHS nonterminal
                            cL = seq
                        } else {
                            // the bracket is a LHS nonterminal
                            if followCheck(bracket: bracket) {
                                addYield(L: bracket, i: cU, k: cU, j: cI)
                                rtn(X: bracket)
                            } else {
                                failedParses += 1
                                if cI > furthestMismatchIndex {
                                    furthestMismatchIndex = cI
                                    furthestMismatchSlot = cL
                                    furthestMismatchExpected = bracket.follow
                                } else if cI == furthestMismatchIndex {
                                    furthestMismatchExpected.formUnion(bracket.follow)
                                }
                            }
                            continue nextDescriptor
                        }
                    case .DO, .OPT, .KLN, .POS:
                        bracketRtn(bracket: bracket)
                        continue nextDescriptor
                   default:
                        fatalError("\(#function) unexpected bracket kind at END seq link \(bracket.kind)")
                    }
                case .EOS:
                    break
                }
            }
        }

        let eosPosition = TokenPosition(token: tokens.count - 1)
        successfullParses = currentParseRoot.yield.filter { y in y.i == .zero && y.j == eosPosition }.count
        trace = false
        print(
            "\nmatched:", successfullParses,
            "  failed:", failedParses,
            "  crf size:", crf.count,
            "  descriptors:", descriptorCount,
            "  duplicateDescriptors:", duplicateDescriptorCount,
            "  suppressedDescriptors:", suppressedDescriptorCount
        )
        if successfullParses == 0 {
            let mismatchToken = tokens[furthestMismatchIndex.tokenIndex]
            let position = mismatchToken.image.base.linePosition(of: mismatchToken.image.startIndex)
            let expected = furthestMismatchExpected.sorted().joined(separator: ", ")
            print("""
                no parse found at \(position)
                found token image: '\(mismatchToken.image)' kind: '\(mismatchToken.kind)'
                grammar context: \(furthestMismatchSlot.ebnfDot())
                expected: \(expected)
                """)
        }
    }

    // MARK: - Internal helpers

    // TODO:  why is this no longer used?
    func testRepeat() -> Bool {
        let d = Descriptor(L: cL, k: cU, i: cI)
        return !unique.insert(d).inserted
    }

    /// Test whether the current token is in the selection set for a grammar slot.
    /// Returns true if any Schrödinger dual of `tokens[cI]` satisfies:
    ///   token ∈ FIRST(slot)  ∨  (ε ∈ FIRST(slot) ∧ token ∈ FOLLOW(bracket))
    /// Uses BitSet membership (O(1) bit test) instead of Set<String>.contains().
    /// At Frankenstein sub-positions, conservatively returns true (rare path).
    func testSelect(slot: GrammarNode, bracket: GrammarNode) -> Bool {

        let headToken = tokens[cI.tokenIndex]
        let headID = headToken.kindID!
        var current = headToken
        while true {
            let cID = current.kindID!
            // Skip this dual if it's excluded by the slot's ---(...) annotation.
            // The head token (primary match) is the keyword/literal; if it's in
            // the exclusion set, this dual path should not be taken.
            if current !== headToken && slot.excludeBS.contains(headID) {
                // This is a dual being tested, and the primary token is excluded
            } else if slot.firstBS.contains(cID)
                || slot.firstBS.contains(grammar.epsilonID) && bracket.followBS.contains(cID) {
                return true
            }
            if let next = current.dual {
                current = next
            } else {
                if slot.firstBS.contains(grammar.frankensteinID)
                    || slot.firstBS.contains(grammar.epsilonID) && bracket.followBS.contains(grammar.frankensteinID) {
                    return true
                }
                return false
            }
        }
    }

    /// Match the current terminal against the token at cI. Returns the next position on success.
    /// Fast path: integer kindID comparison + Schrödinger duals.
    /// Frankenstein path: prefix-match against the token image when cI has a charOffset,
    /// or when the grammar slot allows Frankenstein splitting.
    func tokenMatch() -> TokenPosition? {
        let tokenIdx = cI.tokenIndex
        let charOff  = cI.charOffset

        if charOff != 0 {
            // RARE: Frankenstein sub-position — match against remainder of token image
            let image = tokens[tokenIdx].stripped
            let remainder = image.dropFirst(charOff)
//            Logger.parse.debug("frankenstein remainder \(remainder) index \(self.cI) image \(image)")
            if remainder.hasPrefix(cL.name) {
                let newOff = charOff + cL.name.count
                if newOff >= image.count {
                    return cI.nextToken()           // token fully consumed
                }
                return cI.at(charOffset: newOff)    // more remainder
            }
            return nil
        }

        // FAST PATH: exact match + Schrödinger duals
        let headToken = tokens[tokenIdx]
        var current = headToken
        while true {
            // Skip duals excluded by ---(...) annotation on the grammar slot
            if current !== headToken && cL.excludeBS.contains(headToken.kindID) {
                // This dual is suppressed; the primary token is in the exclusion set
            } else if cL.nameID == current.kindID {
                return cI.nextToken()
            }
            guard let next = current.dual else { break }
            current = next
        }

        
        // RARE: Frankenstein prefix split
        if cL.firstBS.contains(grammar.frankensteinID) {
            let image = tokens[tokenIdx].stripped
//            Logger.parse.debug("frankenstein allowed \(self.cL.name) at \(self.cL.ebnfDot()) prefix matching image \(image)")
            if image.hasPrefix(cL.name) && image.count > cL.name.count {
                return cI.at(charOffset: cL.name.count)
            }
        }
        return nil
    }

    /// Test whether the current token is in the follow set of a bracket (LHS nonterminal).
    /// Handles Schrödinger tokens by checking all duals.
    /// At Frankenstein sub-positions, conservatively returns true (rare path).
    func followCheck(bracket: GrammarNode) -> Bool {
        var current = tokens[cI.tokenIndex]
        while true {
            if bracket.followBS.contains(current.kindID) { return true }
            guard let next = current.dual else {
                if bracket.followBS.contains(grammar.frankensteinID) { return true }
                return false
            }
            current = next
        }
    }

    /// Test whether a continuation grammar slot can proceed with the token at a given position.
    /// Used to suppress descriptors in rtn/bracketRtn/pop replay when the continuation
    /// cannot match the current token. Conservative: returns true for nullable, END, EPS,
    /// and Frankenstein sub-positions to avoid false rejections.
    func continuationViable(continuation: GrammarNode, at position: TokenPosition) -> Bool {
        // Structural nodes that don't consume input are always viable
        if continuation.kind == .END || continuation.kind == .EPS { return true }
        // Nullable continuation: can't determine without enclosing FOLLOW context
        if continuation.firstBS.contains(grammar.epsilonID) { return true }
        // Frankenstein sub-position: conservatively viable (rare path)
        if position.charOffset != 0 { return true }
        // Check token (and Schrödinger duals) against FIRST(continuation)
        var current = tokens[position.tokenIndex]
        while true {
            if continuation.firstBS.contains(current.kindID) { return true }
            guard let next = current.dual else {
                return continuation.firstBS.contains(grammar.frankensteinID)
            }
            current = next
        }
    }

}
//
//  OutputTools.swift
//  Advent
//
//  Created by Johannes Brands on 25/12/2024.
//

import OSLog
import Foundation
import AdventMacros

var trace = false
var traceIndent = 0

/// Called by the #Trace macro expansion.
/// The closure defers argument evaluation until the trace flag is checked.
/// In release builds the body is empty; @inline(__always) ensures the optimizer eliminates everything.
@inline(__always)
func _traceImpl(_ items: () -> [Any], terminator factor: String = "") {
#if DEBUG
    if trace {
        for _ in 0..<traceIndent { print(" ", terminator: "") }
        for item in items() { print("\(item)", terminator: " ") }
        print(factor)
    }
#endif
}
//
//  Scanner.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

// TODO: explicit matching rules e.g. -\- any, regex101 not preceed or follow <<!  !>>, or exclude "\" not preceded "-/-" not followed "-\-"

import OSLog
import Foundation
import AdventMacros

enum ScannerFailure: Error {
    case charactersDoNotMatchAnySymbol(position: String.Index, input: String)
    case couldNotReadFile
}

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool, mode: Mode)

struct Mode: CustomStringConvertible {
    var modeName = ""   // only scan this tokenpattern when scannerMode == modeName
    var isPush = false
    var isCheck = false
    var isPop = false
    
    var isActive: Bool {
        isPush || isCheck || isPop
    }
    
    var description: String {
        var d = ""
        if isPush {
            d += ">>> \(modeName)"
        }
        if isCheck {
            d += "=== \(modeName)"
        }
        if isPop {
            d += "<<< \(modeName)"
        }
        return d
    }
}

final class Token: CustomStringConvertible {
    var image: Substring
    var kind: String
    /// Integer ID from `Grammar.symbolToID`, assigned by `MessageParser.parse(tokens:)`
    /// before the GLL algorithm runs. Enables O(1) integer comparison in `tokenMatch()`
    /// and O(1) BitSet membership tests in `testSelect()`.
    var kindID: Int!
    var dual: Token?                            // multiple regex matches of equal length create a 'Schrödinger' token linked list
    
    init(image: Substring, kind: String) {
        self.image = image
        self.kind = kind
    }
    
    var stripped: String {
        switch kind {
        case "literal":
            return String(image.dropFirst().dropLast())
        case "regex":
            return String(image.dropFirst().dropLast())
        case "action":
            return image.dropFirst().dropLast()
                .replacingOccurrences(of: "\\@", with: "@")
        case "message":
            return String(image.dropFirst(3))
        default:
            return String(image)
        }
    }
    
    var description: String {
        let idStr = kindID.map(String.init) ?? "?"
        if let dual {
            return "'" + kind + "':" + idStr + " ~ " + dual.description
        }
        return "'" + kind + "':" + idStr
    }
}

private struct Pattern {
    let kind: String
    let regex: Regex<Substring>
    let isKeyword: Bool
    let isSkip: Bool
    let mode: Mode
}

/// Scanner takes an input string and token patterns, and produces a token array.
/// One instance per scan — no shared mutable state.
/// Literal keywords are matched via hasPrefix; only true regex patterns use the regex engine.
final class Scanner {
    
    let input: String
    var tokens: [Token] = []                // normal, visible tokens that can be referenced in the grammar production rules
    var trivia: [[Token]] = [[]]            // skipped tokens are stored as lists in an array indexed by the visible token following them
    
    private var modeStack: [String] = []    // tracks state to allow e.g. nested token construction
    private var scannerMode: String {       // isolated to the scanner, not driven by the parser
        return modeStack.last ?? ""
    }
    
    private var literalPatterns: [Pattern] = []
    private var regexPatterns: [Pattern] = []
    
    init(fromString inputString: String, patterns: [String: TokenPattern]) throws {
        self.input = inputString
        
        // Partition: literal keywords use fast hasPrefix, the rest use regex engine.
        // A keyword is a true literal if the image string matches exactly the kind string.
        for (kind, pattern) in patterns {
            if pattern.isKeyword && kind == pattern.source {
                literalPatterns.append(Pattern(kind: kind, regex: pattern.regex, isKeyword: pattern.isKeyword, isSkip: pattern.isSkip, mode: pattern.mode))
            } else {
                regexPatterns.append(Pattern(kind: kind, regex: pattern.regex, isKeyword: pattern.isKeyword, isSkip: pattern.isSkip, mode: pattern.mode))
            }
        }
        
        try scanAllTokens()
    }
    
    private struct Candidate {
        let token: Token
        let pattern: Pattern
    }
    
    private func scanAllTokens() throws {
        var matchStart = input.startIndex
        var charsScanned = 0
        let inputSize = input.utf8.count
        let scanInterval = 10_000
        let scanByteLimit = 0
        var patternTime: [String: Double] = [:]
        var patternCalls: [String: Int] = [:]

        while matchStart != input.endIndex {
            var matchEnd = matchStart
            var candidates: [Candidate] = []
            let remaining = input[matchStart...]

            // Phase 1: literal keywords via hasPrefix (fast string comparison)
            for lp in literalPatterns {
                guard lp.mode.modeName == "" || lp.mode.modeName == scannerMode || lp.mode.isPush else { continue }

                if remaining.hasPrefix(lp.kind) {
                    let literalEnd = input.index(matchStart, offsetBy: lp.kind.count)
                    if literalEnd > matchEnd {
                        matchEnd = literalEnd
                        candidates.removeAll()
                    }
                    if literalEnd == matchEnd {
                        candidates.append(Candidate(
                            token: Token(image: input[matchStart..<literalEnd], kind: lp.kind),
                            pattern: lp))
                    }
                }
            }

            // Phase 2: regex patterns via prefixMatch (regex engine)
            for rp in regexPatterns {
                guard rp.mode.modeName == "" || rp.mode.modeName == scannerMode  || rp.mode.isPush else { continue }

                let t0 = CFAbsoluteTimeGetCurrent()
                let match = remaining.prefixMatch(of: rp.regex)
                let elapsed = CFAbsoluteTimeGetCurrent() - t0
                patternTime[rp.kind, default: 0] += elapsed
                patternCalls[rp.kind, default: 0] += 1
                if elapsed > 1.0 {
                    print("  SLOW REGEX: '\(rp.kind)' took \(String(format: "%.1f", elapsed))s at byte \(charsScanned)/\(inputSize)")
                }

                if let match {
                    if match.0.endIndex > matchEnd {
                        matchEnd = match.0.endIndex
                        candidates.removeAll()
                    }
                    if match.0.endIndex == matchEnd {
                        candidates.append(Candidate(
                            token: Token(image: match.0, kind: rp.kind),
                            pattern: rp))
                    }
                }
            }
            
            // Phase 3: resolve candidates — mode-active patterns suppress Schrödinger duals
            guard !candidates.isEmpty else {
                try scanError(position: matchStart)
            }
            
            let modeActive = candidates.filter { $0.pattern.mode.isActive }
            
            let headMatch: Token
            let headPattern: Pattern
            
            if let winner = modeActive.first {
                // Mode-active pattern wins, no Schrödinger duals
                if modeActive.count > 1 {
                    Logger.scan.warning("multiple mode-active patterns match: \(modeActive.map(\.pattern.kind))")
                }
                headMatch = winner.token
                headPattern = winner.pattern
            } else {
                // No mode-active patterns — build Schrödinger chain
                // Keywords/non-skip go to front, skip/non-keyword go to back
                let front = candidates.filter { $0.pattern.isKeyword && !$0.pattern.isSkip }
                let back = candidates.filter { !($0.pattern.isKeyword && !$0.pattern.isSkip) }
                let ordered = front + back
                
                headMatch = ordered[0].token
                headPattern = ordered[0].pattern
                var tail = headMatch
                for candidate in ordered.dropFirst() {
                    tail.dual = candidate.token
                    tail = candidate.token
                }
            }
            
            if headPattern.isSkip {
                trivia[tokens.count].append(headMatch)
            } else {
                tokens.append(headMatch)
                trivia.append([])
            }
            matchStart = matchEnd
            charsScanned += headMatch.image.utf8.count
            if charsScanned % scanInterval < headMatch.image.utf8.count {
                print("  scan: \(charsScanned)/\(inputSize) bytes, \(tokens.count) tokens")
            }
            if scanByteLimit > 0 && charsScanned >= scanByteLimit {
                print("  scan stopped at byte limit \(scanByteLimit)")
                break
            }

            // manage the scanner mode
            if headPattern.mode.isPush {
                modeStack.append(headPattern.mode.modeName)
//                Logger.scan.debug("pushed new scan mode: \(self.scannerMode) match: \(headMatch.image) pattern: \(headPattern.kind)")
            } else if headPattern.mode.isPop {
                if let _ = modeStack.popLast() {
//                    Logger.scan.debug("popped into previous scan mode: \(self.scannerMode)")
                } else {
                    fatalError("\(#function) too many pops from scanner mode stack!")
                }
            }
        }
        
        tokens.append(Token(image: "$", kind: "○"))  // append EndOfString token

        let sortedByTime = patternTime.sorted { $0.value > $1.value }
        print("  scan complete: \(inputSize) bytes, \(tokens.count) tokens")
        print("  regex pattern timing (top 10):")
        for (kind, time) in sortedByTime.prefix(10) {
            let calls = patternCalls[kind, default: 0]
            let avg = calls > 0 ? time / Double(calls) : 0
            print("    \(String(format: "%8.3f", time * 1000))ms total, \(String(format: "%6d", calls)) calls, \(String(format: "%.3f", avg * 1000))ms avg — \(kind)")
        }
    }
    
    
    // TODO: use https://developer.apple.com/documentation/foundation/nsregularexpression/1408386-escapedpattern
    
    private func scanError(position: String.Index) throws -> Never {
        var error = "scan error: input characters at position \(input.linePosition(of: position)) do not match any symbol in the grammar\n"
        let lineRange = input.lineRange(for: position ..< input.index(after: position))
        error += input[lineRange]
        let before = lineRange.lowerBound ..< position
        for _ in 0 ..< input[before].count {
            error += " "
        }
        error += "^~~~~~~~"
        //        for rp in regexPatterns {
        //            error += "\n\(rp.kind)"
        //        }
        Logger.scan.error("\(error)")
        throw ScannerFailure.charactersDoNotMatchAnySymbol(position: position, input: input)
    }
}
//
//  SimpleMessageParser.swift
//  Advent
//
//  Created by Johannes Brands on 2026.04.23.
//

// GLL message parser encapsulating all parsing state.
// Paper: cL = current grammar slot
// Paper: cI — current input position (the current active token)
// Paper: cU — current cluster index (identifies a CRF cluster node together with the nonterminal; its value is the input position where the nonterminal was called)
// Paper: R = pending descriptors, U = processed descriptors
// Paper: dscAdd/dscGet = descriptor operations, ntAdd = nonterminal alternates
// Paper: call = enter nonterminal, rtn = return from nonterminal
// Paper: bsrAdd = add BSR element

import OSLog
import Foundation
import AdventMacros

class SimpleMessageParser {

    // MARK: - Per-construction (immutable after init)
    let grammar: Grammar

    // MARK: - Per-parse input
    var tokens: [Token] = []

    // MARK: - GLL algorithm state (paper variables)
    var currentParseRoot: GrammarNode!
    var cL: GrammarNode!                    // current grammar slot
    var cI: TokenPosition = .zero           // current input position
    var cU: TokenPosition = .zero           // current cluster index

    // MARK: - Descriptor management (Paper: R, U)
    var remaining: [Descriptor] = []
    var unique: Set<Descriptor> = []

    // MARK: - Parse statistics
    var failedParses = 0
    var successfullParses = 0
    var descriptorCount = 0
    var duplicateDescriptorCount = 0
//    var suppressedDescriptorCount = 0

    // MARK: - Call Return Forest (Paper: CRF)
    var crf: [ParsePosition: ParseCluster] = [:]

    // MARK: - Binary Subtree Representation (Paper: Υ)
    var yieldCount = 0

    // MARK: - Error reporting, captures the furthest the parse has progressed before a mismatch occurred
    var furthestMismatchIndex: TokenPosition = .zero
    var furthestMismatchSlot: GrammarNode!
    var furthestMismatchExpected: Set<String> = []

    // MARK: - Initialization

    init(grammar: Grammar) {
        self.grammar = grammar
    }

    // MARK: - Parse API

    func parse(tokens: [Token]) {
        // Reset all per-parse state
        self.tokens = tokens
        // Map each token's string kind to its integer kindID from the symbol table.
        // This includes Schrödinger duals (linked via token.dual) which represent
        // ambiguous scanner matches of equal length.
        for token in tokens {
            var t: Token? = token
            while let current = t {
                current.kindID = grammar.symbolToID[current.kind]!
                t = current.dual
            }
        }
        currentParseRoot = grammar.root
        cL = nil; cI = .zero; cU = .zero
        unique = []; remaining = []
        failedParses = 0; successfullParses = 0
        descriptorCount = 0; duplicateDescriptorCount = 0//; suppressedDescriptorCount = 0
        crf = [:]; yieldCount = 0
        furthestMismatchIndex = .zero
        furthestMismatchSlot = currentParseRoot
        furthestMismatchExpected = []

        // Set up root cluster
        let rootCluster = ParseCluster(slot: grammar.root, index: .zero)
        crf[ParsePosition(slot: grammar.root, index: .zero)] = rootCluster
        grammar.root.clearNodes()

        // Seed initial descriptors (Paper: ntAdd for start symbol)
        addDecscriptorsForAlternates(X: grammar.root, k: .zero, i: .zero)

        // Run GLL algorithm
        nextDescriptor: while getDescriptor() {

            while true {

                trace = false
                #Trace("slot: \(String(format: "%2d", cL.number)) \(cL.ebnfDot()) first \(cL.first) follow \(cL.follow) token: \(tokens[cI.tokenIndex].kind) \(tokens[cI.tokenIndex].image)")

                switch cL.kind {
                case .EPS:
                    addYield(L: cL, i: cU, k: cI, j: cI)
                    cL = cL.seq!
                case .T, .TI, .C, .B:
                    if let next = tokenMatch() {
                        addYield(L: cL, i: cU, k: cI, j: next)
                        cI = next
                        cL = cL.seq!
                    } else {
                        failedParses += 1
                        if cI > furthestMismatchIndex {
                            furthestMismatchIndex = cI
                            furthestMismatchSlot = cL
                            furthestMismatchExpected = [cL.name]
                        } else if cI == furthestMismatchIndex {
                            furthestMismatchExpected.insert(cL.name)
                        }
                        continue nextDescriptor
                    }
                case .N:
                    call()
                    continue nextDescriptor
                case .ALT:
                    fatalError(#function + ": ALT should not happen here")
                case .DO, .POS:
                    bracketCall(bracket: cL)
                    continue nextDescriptor
                case .OPT, .KLN:
                    // OPT/KLN: also offer skip-past-bracket path (they're nullable)
                    if testSelect(slot: cL.seq!, bracket: cL) {
                        addDescriptor(L: cL.seq!, k: cU, i: cI)
                        addYield(L: cL, i: cU, k: cI, j: cI)  // empty bracket BSR
                    }
                    bracketCall(bracket: cL)
                    continue nextDescriptor
                case .END:
                    // the seq link of an END node always points back to a starting bracket node (N, DO, OPT, POS, KLN)
                    let bracket = cL.seq!

                    switch bracket.kind {
                    case .N:
                        if let seq = bracket.seq {
                            // the bracket is a RHS nonterminal
                            cL = seq
                        } else {
                            // the bracket is a LHS nonterminal
                            if followCheck(bracket: bracket) {
                                addYield(L: bracket, i: cU, k: cU, j: cI)
                                rtn(X: bracket)
                            } else {
                                failedParses += 1
                                if cI > furthestMismatchIndex {
                                    furthestMismatchIndex = cI
                                    furthestMismatchSlot = cL
                                    furthestMismatchExpected = bracket.follow
                                } else if cI == furthestMismatchIndex {
                                    furthestMismatchExpected.formUnion(bracket.follow)
                                }
                            }
                            continue nextDescriptor
                        }
                    case .DO, .OPT, .KLN, .POS:
                        bracketRtn(bracket: bracket)
                        continue nextDescriptor
                   default:
                        fatalError("\(#function) unexpected bracket kind at END seq link \(bracket.kind)")
                    }
                case .EOS:
                    break
                }
            }
        }

        let eosPosition = TokenPosition(token: tokens.count - 1)
        successfullParses = currentParseRoot.yield.filter { y in y.i == .zero && y.j == eosPosition }.count
        trace = false
        print(
            "\nmatched:", successfullParses,
            "  failed:", failedParses,
            "  crf size:", crf.count,
            "  descriptors:", descriptorCount,
            "  duplicateDescriptors:", duplicateDescriptorCount,
//            "  suppressedDescriptors:", suppressedDescriptorCount
        )
        if successfullParses == 0 {
            let mismatchToken = tokens[furthestMismatchIndex.tokenIndex]
            let position = mismatchToken.image.base.linePosition(of: mismatchToken.image.startIndex)
            let expected = furthestMismatchExpected.sorted().joined(separator: ", ")
            print("""
                no parse found at \(position)
                found token image: '\(mismatchToken.image)' kind: '\(mismatchToken.kind)'
                grammar context: \(furthestMismatchSlot.ebnfDot())
                expected: \(expected)
                """)
        }
    }

    // MARK: - Internal helpers

    // TODO:  why is this no longer used?
    func testRepeat() -> Bool {
        let d = Descriptor(L: cL, k: cU, i: cI)
        return !unique.insert(d).inserted
    }

    /// Test whether the current token is in the selection set for a grammar slot.
    /// Returns true if any Schrödinger dual of `tokens[cI]` satisfies:
    ///   token ∈ FIRST(slot)  ∨  (ε ∈ FIRST(slot) ∧ token ∈ FOLLOW(bracket))
    /// Uses BitSet membership (O(1) bit test) instead of Set<String>.contains().
    /// At Frankenstein sub-positions, conservatively returns true (rare path).
    func testSelect(slot: GrammarNode, bracket: GrammarNode) -> Bool {
        
        return true     // Simple

        let headToken = tokens[cI.tokenIndex]
        let headID = headToken.kindID!
        var current = headToken
        while true {
            let cID = current.kindID!
            // Skip this dual if it's excluded by the slot's ---(...) annotation.
            // The head token (primary match) is the keyword/literal; if it's in
            // the exclusion set, this dual path should not be taken.
            if current !== headToken && slot.excludeBS.contains(headID) {
                // This is a dual being tested, and the primary token is excluded
            } else if slot.firstBS.contains(cID)
                || slot.firstBS.contains(grammar.epsilonID) && bracket.followBS.contains(cID) {
                return true
            }
            if let next = current.dual {
                current = next
            } else {
                if slot.firstBS.contains(grammar.frankensteinID)
                    || slot.firstBS.contains(grammar.epsilonID) && bracket.followBS.contains(grammar.frankensteinID) {
                    return true
                }
                return false
            }
        }
    }

    /// Match the current terminal against the token at cI. Returns the next position on success.
    /// Fast path: integer kindID comparison + Schrödinger duals.
    /// Frankenstein path: prefix-match against the token image when cI has a charOffset,
    /// or when the grammar slot allows Frankenstein splitting.
    func tokenMatch() -> TokenPosition? {
        let tokenIdx = cI.tokenIndex
        let charOff  = cI.charOffset

        if charOff != 0 {
            // RARE: Frankenstein sub-position — match against remainder of token image
            let image = tokens[tokenIdx].stripped
            let remainder = image.dropFirst(charOff)
//            Logger.parse.debug("frankenstein remainder \(remainder) index \(self.cI) image \(image)")
            if remainder.hasPrefix(cL.name) {
                let newOff = charOff + cL.name.count
                if newOff >= image.count {
                    return cI.nextToken()           // token fully consumed
                }
                return cI.at(charOffset: newOff)    // more remainder
            }
            return nil
        }

        // FAST PATH: exact match + Schrödinger duals
        let headToken = tokens[tokenIdx]
        var current = headToken
        while true {
            // Skip duals excluded by ---(...) annotation on the grammar slot
            if current !== headToken && cL.excludeBS.contains(headToken.kindID) {
                // This dual is suppressed; the primary token is in the exclusion set
            } else if cL.nameID == current.kindID {
                return cI.nextToken()
            }
            guard let next = current.dual else { break }
            current = next
        }

        
        // RARE: Frankenstein prefix split
        if cL.firstBS.contains(grammar.frankensteinID) {
            let image = tokens[tokenIdx].stripped
//            Logger.parse.debug("frankenstein allowed \(self.cL.name) at \(self.cL.ebnfDot()) prefix matching image \(image)")
            if image.hasPrefix(cL.name) && image.count > cL.name.count {
                return cI.at(charOffset: cL.name.count)
            }
        }
        return nil
    }

    /// Test whether the current token is in the follow set of a bracket (LHS nonterminal).
    /// Handles Schrödinger tokens by checking all duals.
    /// At Frankenstein sub-positions, conservatively returns true (rare path).
    func followCheck(bracket: GrammarNode) -> Bool {
        
        return true     // Simple
        
        var current = tokens[cI.tokenIndex]
        while true {
            if bracket.followBS.contains(current.kindID) { return true }
            guard let next = current.dual else {
                if bracket.followBS.contains(grammar.frankensteinID) { return true }
                return false
            }
            current = next
        }
    }

    /// Test whether a continuation grammar slot can proceed with the token at a given position.
    /// Used to suppress descriptors in rtn/bracketRtn/pop replay when the continuation
    /// cannot match the current token. Conservative: returns true for nullable, END, EPS,
    /// and Frankenstein sub-positions to avoid false rejections.
    func continuationViable(continuation: GrammarNode, at position: TokenPosition) -> Bool {
        
        return true         // Simple
        
        // Structural nodes that don't consume input are always viable
        if continuation.kind == .END || continuation.kind == .EPS { return true }
        // Nullable continuation: can't determine without enclosing FOLLOW context
        if continuation.firstBS.contains(grammar.epsilonID) { return true }
        // Frankenstein sub-position: conservatively viable (rare path)
        if position.charOffset != 0 { return true }
        // Check token (and Schrödinger duals) against FIRST(continuation)
        var current = tokens[position.tokenIndex]
        while true {
            if continuation.firstBS.contains(current.kindID) { return true }
            guard let next = current.dual else {
                return continuation.firstBS.contains(grammar.frankensteinID)
            }
            current = next
        }
    }

}


// MARK: - SimpleMessageParser CRF Operations

extension SimpleMessageParser {

    // Paper: ntAdd(X, j) — add descriptors for all alternates of a bracket/nonterminal
    func addDecscriptorsForAlternates(X: GrammarNode, k: TokenPosition, i: TokenPosition) {
        assert([.N, .DO, .OPT, .ALT, .KLN, .POS].contains(X.kind), "Called \(#function) on a GrammarNode \(X) which is not a bracket")
        // For LL(1) nonterminals without Schrödinger duals or Frankenstein tokens,
        // at most one alternate can match — stop after finding it.
        
        let canEarlyTerminate = false       // Simple
        
//        let canEarlyTerminate = X.isLocallyLL1
//            && tokens[i.tokenIndex].dual == nil
//            && i.charOffset == 0
//            && !X.firstBS.contains(grammar.frankensteinID)
        var current = X.alt
        while let alt = current {
            if testSelect(slot: alt, bracket: X) {
                addDescriptor(L: alt.seq!, k: k, i: i)
                if canEarlyTerminate { return }
            }
            current = alt.alt
        }
    }
    
    // Paper: call(L, i, j) — enter a nonterminal
    func call() {
        // cL points to the RHS nonterminal node
        // cL.alt points to the LHS nonterminal node

        // Create the return edge: (L=cL, i=cU)
        let returnEdge = ParsePosition(slot: cL, index: cU)

        // Find or create the cluster node for (X=cL.alt!, k=cI)
        let clusterKey = ParsePosition(slot: cL.alt!, index: cI)

        if let existingCluster = crf[clusterKey] {
            if existingCluster.returns.insert(returnEdge).inserted {
                for pop in existingCluster.pops {
//                    if continuationViable(continuation: cL.seq!, at: pop) {
                        addDescriptor(L: cL.seq!, k: cU, i: pop)
                        addYield(L: cL, i: cU, k: cI, j: pop)
//                    } else {
//                        suppressedDescriptorCount += 1
//                    }
                }
            }
        } else {
            let newCluster = ParseCluster(slot: cL.alt!, index: cI)
            crf[clusterKey] = newCluster
            newCluster.returns.insert(returnEdge)
            addDecscriptorsForAlternates(X: cL.alt!, k: cI, i: cI)
        }
    }
    
    // Paper: rtn(X, k, j) — return from a nonterminal
    func rtn(X: GrammarNode) {
        let clusterKey = ParsePosition(slot: X, index: cU)
        guard let cluster = crf[clusterKey] else { return }

        if cluster.pops.insert(cI).inserted {
            for rtn in cluster.returns {
//                if continuationViable(continuation: rtn.slot.seq!, at: cI) {
                    addDescriptor(L: rtn.slot.seq!, k: rtn.index, i: cI)
                    addYield(L: rtn.slot, i: rtn.index, k: cU, j: cI)
//                } else {
//                    suppressedDescriptorCount += 1
//                }
            }
        }
    }
    
    // bracketCall — enter a bracket (DO, OPT, KLN, POS)
    // Similar to call() but the bracket node IS the "nonterminal" — no indirection through .alt
    func bracketCall(bracket: GrammarNode) {
        let returnEdge = ParsePosition(slot: bracket, index: cU)
        let clusterKey = ParsePosition(slot: bracket, index: cI)

        if let existingCluster = crf[clusterKey] {
            if existingCluster.returns.insert(returnEdge).inserted {
                for pop in existingCluster.pops {
//                    if continuationViable(continuation: bracket.seq!, at: pop) {
                        addDescriptor(L: bracket.seq!, k: cU, i: pop)
                        addYield(L: bracket, i: cU, k: cI, j: pop)
//                    } else {
//                        suppressedDescriptorCount += 1
//                    }
                }
            }
        } else {
            let newCluster = ParseCluster(slot: bracket, index: cI)
            crf[clusterKey] = newCluster
            newCluster.returns.insert(returnEdge)
            addDecscriptorsForAlternates(X: bracket, k: cI, i: cI)
        }
    }
    
    // bracketRtn — return from a bracket
    // Similar to rtn() but also handles KLN/POS re-entry
    func bracketRtn(bracket: GrammarNode) {
        let clusterKey = ParsePosition(slot: bracket, index: cU)
        guard let cluster = crf[clusterKey] else { return }

        if cluster.pops.insert(cI).inserted {
            for rtn in cluster.returns {
//                if continuationViable(continuation: rtn.slot.seq!, at: cI) {
                    addYield(L: rtn.slot, i: rtn.index, k: cU, j: cI)
                    addDescriptor(L: rtn.slot.seq!, k: rtn.index, i: cI)
//                } else {
//                    suppressedDescriptorCount += 1
//                }
            }

            if bracket.kind.isClosure {
                let nextKey = ParsePosition(slot: bracket, index: cI)

                if let existingCluster = crf[nextKey] {
                    for returnEdge in cluster.returns {
                        if existingCluster.returns.insert(returnEdge).inserted {
                            for pop in existingCluster.pops {
//                                if continuationViable(continuation: returnEdge.slot.seq!, at: pop) {
                                    addYield(L: returnEdge.slot, i: returnEdge.index, k: cI, j: pop)
                                    addDescriptor(L: returnEdge.slot.seq!, k: returnEdge.index, i: pop)
//                                } else {
//                                    suppressedDescriptorCount += 1
//                                }
                            }
                        }
                    }
                } else {
                    let newCluster = ParseCluster(slot: bracket, index: cI)
                    crf[nextKey] = newCluster
                    newCluster.returns = cluster.returns
                    addDecscriptorsForAlternates(X: bracket, k: cI, i: cI)
                }
            }
        }
    }
}


// MARK: - SimpleMessageParser Descriptor Operations

extension SimpleMessageParser {

    // Paper: dscAdd(L, k, i)
    func addDescriptor(L: GrammarNode, k: TokenPosition, i: TokenPosition) {
        let d = Descriptor(L: L, k: k, i: i)
        if unique.insert(d).inserted {
            remaining.append(d)
            descriptorCount += 1
        } else {
            duplicateDescriptorCount += 1
        }
    }

    // Paper: get next descriptor from R
    func getDescriptor() -> Bool {
        if remaining.isEmpty {
            return false
        } else {
            let d = remaining.removeLast()
            cL = d.L
            cU = d.k
            cI = d.i
            return true
        }
    }
}


// MARK: - MessageParser BSR Operations

extension SimpleMessageParser {

    // Paper: bsrAdd(X ::= α·β, i, k, j) — add BSR element to the yield
    func addYield(L: GrammarNode, i: TokenPosition, k: TokenPosition, j: TokenPosition) {
        let triple = BinarySpan(i: i, k: k, j: j)
        if L.yield.insert(triple).inserted {
            yieldCount += 1
        }
    }
}
//
//  SPPF.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.04.
//


// Paper: "Derivation representation using binary subtree sets"

/*
func extractSPPF (Υ, Γ) {
    G := empty graph
    let S be the start symbol of Γ
    let n be the extent of Υ
    if Υ has an element of the form (S ::= α, 0, k, n) {
        create a node labelled (S, 0, n) in G
        while G has an extendable leaf node {
            let w = (μ, i, j) be an extendable leaf node of G
            if (μ is a nonterminal X in Γ) {
                for each (X ::= γ, i, k, j) ∈ Υ {
                    mkPN(X ::= γ·, i, k, j, G)
                }
            } else {
                suppose μ is X ::= α · δ
                if (|α| = 1) {
                    mkPN(X ::= α · δ, i, i, j, G)
                } else {
                    for each (α, i, k, j) ∈ Υ {
                        mkPN(X ::= α · δ, i, k, j, G)
                    }
                }
            }
        }
        return G
    }
    
    func mkPN(X ::= α · δ, i, k, j, G) {
        make a node y in G labelled (X ::= α · δ, k)
        if (α = ε) mkN(ε, i, i, y, G)
            if (α = βx, where |x| = 1) {
            mkN(x, k, j, y, G)
            if (|β| = 1) mkN(β, i, k, y, G)
                if (|β| > 1) mkN(X ::= β · xδ, i, k, y, G)
        }
    }
    
    func mkN(Ω, i, j, y, G) {
        if there is not a node labelled (Ω, i, j) in G make one
            add an edge from y to the node (Ω, i, j)
    }

*/

import OSLog
import Foundation
import AdventMacros

// MARK: - SPPF Node Types

/// The three kinds of SPPF nodes, following the paper's conventions.
enum SPPFNodeKind {
    case symbol         // nonterminal or terminal: drawn as ellipse
    case intermediate   // grammar slot X ::= α · β with |α| > 1: drawn as rectangle
    case packed         // packed node (X ::= α · β, k): drawn as small filled circle
}

/// An SPPF node in the shared packed parse forest.
/// Symbol and intermediate nodes are identified by (slot, i, j).
/// Packed nodes are identified by (slot, k) and are children of symbol/intermediate nodes.
class SPPFNode: CustomStringConvertible {
    let kind: SPPFNodeKind
    let slot: GrammarNode       // the grammar node (nonterminal, terminal, or slot position)
    let i: TokenPosition        // left extent (or pivot k for packed nodes)
    let j: TokenPosition        // right extent (.unused for packed nodes)
    var children: [SPPFNode] = []
    var extended = false        // has this node been extended (expanded) already?

    init(kind: SPPFNodeKind, slot: GrammarNode, i: TokenPosition, j: TokenPosition) {
        self.kind = kind
        self.slot = slot
        self.i = i
        self.j = j
    }
    
    /// Label for display
    var label: String {
        switch kind {
        case .symbol:
            if isNonterminal {
                return "\(slot.name),\(i),\(j)"
            } else if slot.kind == .EPS {
                return "ε,\(i),\(j)"
            } else if slot.kind.isBracket {
                // Bracket symbol node — use bracket's internal END to get {τ·}
                if let end = slot.bracketEndNode {
                    return "\(end.ebnfDot()),\(i),\(j)"
                }
                return "\(slot.ebnfDot()),\(i),\(j)"
            } else {
                // terminal
                return "\"\(slot.name)\",\(i),\(j)"
            }
        case .intermediate:
            // Dot after the slot node: terminals get "a"·, brackets get {"a"}·
            return "\(slot.ebnfDot()),\(i),\(j)"
        case .packed:
            return "\(slot.ebnfDot()),\(i)"  // i is the pivot k for packed nodes
        }
    }
    
    /// Is this a nonterminal symbol node?
    var isNonterminal: Bool {
        slot.isLHS
    }
    
    /// Is this node extendable? (a leaf that is not a terminal, epsilon, or packed)
    var isExtendable: Bool {
        guard children.isEmpty && !extended else { return false }
        if kind == .packed { return false }
        // Only symbol nodes for terminals/epsilon are non-extendable.
        // Intermediate nodes whose slot happens to be a terminal ARE extendable
        // (they represent grammar positions X ::= α · β that need decomposition).
        if kind == .symbol {
            if slot.kind == .EPS { return false }
            if slot.kind.isTerminal { return false }
        }
        return true
    }
    
    var description: String { label }
}

// MARK: - SPPF Node Identity

/// Key for deduplicating symbol and intermediate nodes: (slot, i, j).
struct SPPFNodeKey: Hashable {
    let slot: GrammarNode
    let i: TokenPosition
    let j: TokenPosition
}

// MARK: - SPPF Extractor

/// Extracts an SPPF (Shared Packed Parse Forest) from the BSR yield stored
/// in each GrammarNode. The SPPF is a compact DAG that represents all parse
/// trees simultaneously through node sharing and packed nodes for ambiguity.
///
/// The algorithm follows the paper "Derivation representation using binary
/// subtree sets" (Scott, 2008). It works as a fixpoint iteration:
///   1. Create a root symbol node (S, 0, n) for the start symbol.
///   2. While there are extendable leaf nodes in the graph:
///      a. For nonterminal leaves: find all matching alternates and create
///         packed nodes with binary decomposition (left prefix, right last-symbol).
///      b. For bracket leaves: expand iteration structure (empty/single/multi).
///      c. For intermediate leaves: decompose using BSR pivot evidence.
///   3. Node sharing via findOrCreateNode ensures the forest remains compact.
///
/// The SPPF uses binary decomposition: each packed node has at most two children
/// (left = prefix of symbols, right = last symbol). This is in contrast to the
/// n-ary parse trees produced by DerivationBuilder.
class SPPFExtractor {
    
    // MARK: - Inputs from parser
    let grammar: Grammar
    let tokens: [Token]
    
    // MARK: - SPPF extraction state
    var slotIndex: [GrammarNode: Int] = [:]
    var sppfNodes: [SPPFNodeKey: SPPFNode] = [:]
    var sppfAllNodes: [SPPFNode] = []
    var _sppfNonTerminals: [String: GrammarNode] = [:]
    var syntheticEpsilonNode: GrammarNode?
    
    // MARK: - Initialization
    
    init(grammar: Grammar, tokens: [Token]) {
        self.grammar = grammar
        self.tokens = tokens
        self._sppfNonTerminals = grammar.nonTerminals
        buildSlotIndex(nonTerminals: grammar.nonTerminals)
    }
    
    // MARK: - Slot Index Computation
    
    /// Precomputed mapping from grammar node → number of symbols before (and including) it
    /// in its containing alternate. This gives |α| for the BSR element at that slot.
    ///
    /// For a rule S = "a" B "c":
    ///   ALT.seq → T("a") → N(B) → T("c") → END
    ///   slotIndex:  1        2       3        (END not indexed)
    ///
    /// |α| for a BSR element with node L equals slotIndex[L].
    
    /// Walk all grammar rules and bracket alternates to build the slotIndex dictionary.
    private func buildSlotIndex(nonTerminals: [String: GrammarNode]) {
        slotIndex = [:]
        for (_, nonterminal) in nonTerminals {
            indexAlternates(nonterminal.alt)
        }
    }
    
    /// Index alternates starting from an ALT node chain.
    private func indexAlternates(_ alt: GrammarNode?) {
        var current = alt
        while let altNode = current {
            // Walk the seq chain of this alternate, counting symbols
            var node = altNode.seq
            var index = 0
            while let n = node {
                if n.kind == .END { break }
                
                // Recurse into bracket alternates
                if n.kind.isBracket {
                    indexAlternates(n.alt)
                }
                
                index += 1
                slotIndex[n] = index
                node = n.seq
            }
            current = altNode.alt
        }
    }
    
    /// Get the grammar node that is `steps` positions before `node` in its seq chain.
    /// Returns nil if we can't walk back that far.
    /// Since nodes don't have back-pointers, we find the containing ALT and walk forward.
    func predecessorSlot(of node: GrammarNode, steps: Int) -> GrammarNode? {
        guard let targetIndex = slotIndex[node], targetIndex > steps else { return nil }
        let targetPos = targetIndex - steps
        
        // Find the containing ALT by walking forward through the seq chain to the END node.
        // The END node's alt pointer gives us the ALT node for this alternate.
        var endNode: GrammarNode? = node
        while let n = endNode {
            if n.kind == .END {
                break
            }
            endNode = n.seq
        }
        guard let end = endNode, end.kind == .END, let alt = end.alt else { return nil }
        
        var current = alt.seq
        while let n = current {
            if n.kind == .END { break }
            if slotIndex[n] == targetPos { return n }
            current = n.seq
        }
        return nil
    }
    
    // MARK: - BSR Helpers
    
    /// All valid end positions for a symbol starting at `from`, derived from BSR evidence
    /// stored in each GrammarNode's yield set.
    ///
    /// - Terminals: span exactly one token (from → from+1) if the token kind matches.
    ///   Schrödinger tokens (ambiguous scanner matches) are checked via the dual chain.
    /// - Nonterminals: the LHS node's yield gives all spans starting at `from`.
    /// - Brackets: follow the iteration chain (k→j) through the bracket's yield.
    ///   For closures (KLN/POS), chain through multiple iterations via BFS.
    ///   Nullable brackets (KLN/OPT) also include `from` itself (empty match).
    /// - Epsilon: matches only at `from` (empty span).
    private func endPositions(_ symbol: GrammarNode, from: TokenPosition) -> Set<TokenPosition> {
        switch symbol.kind {
        case .T, .TI, .C, .B:
            var positions: Set<TokenPosition> = []
            for span in symbol.yield where span.k == from { positions.insert(span.j) }
            return positions
        case .N:
            guard let lhs = symbol.alt else { return [] }
            var positions: Set<TokenPosition> = []
            for span in lhs.yield where span.i == from { positions.insert(span.j) }
            return positions
        case .DO, .OPT, .KLN, .POS:
            var positions: Set<TokenPosition> = []
            if symbol.kind == .KLN || symbol.kind == .OPT { positions.insert(from) }
            var visited: Set<TokenPosition> = []
            var queue = [from]
            while !queue.isEmpty {
                let pos = queue.removeFirst()
                guard visited.insert(pos).inserted else { continue }
                for span in symbol.yield where span.k == pos {
                    positions.insert(span.j)
                    if symbol.kind.isClosure { queue.append(span.j) }
                }
            }
            return positions
        case .EPS:
            return [from]
        default:
            return []
        }
    }
    
    /// Chain through a sequence of symbols to find all possible end positions.
    /// Starting from `start`, for each symbol in order, collect where it could end
    /// given all possible start positions from the previous symbol.
    private func chainEndPositions(symbols: [GrammarNode], from start: TokenPosition) -> Set<TokenPosition> {
        var positions: Set<TokenPosition> = [start]
        for symbol in symbols {
            var nextPositions: Set<TokenPosition> = []
            for pos in positions {
                nextPositions.formUnion(endPositions(symbol, from: pos))
            }
            positions = nextPositions
        }
        return positions
    }
    
    // MARK: - SPPF Extraction Algorithm
    
    /// Extract an SPPF from the BSR yield, following the paper's algorithm.
    ///
    /// The algorithm is a fixpoint iteration over a growing graph:
    /// 1. Seed with a root symbol node for the start nonterminal.
    /// 2. Repeatedly find leaf nodes that haven't been extended yet.
    /// 3. Extend each leaf by looking up BSR evidence and creating packed nodes.
    /// 4. Stop when no new extendable leaves remain.
    ///
    /// Returns the root SPPFNode, or nil if no parse exists.
    func extractSPPF() -> SPPFNode? {
        let startSymbol = grammar.root
        let extent = TokenPosition(token: tokens.count - 1)  // exclude EOS

        // Clear previous SPPF
        sppfNodes = [:]
        sppfAllNodes = []

        // Paper: if Υ has an element of the form (S ::= α, 0, k, n)
        guard startSymbol.yield.contains(where: { $0.i == .zero && $0.j == extent }) else {
            #Trace("SPPF: no complete parse found for \(startSymbol.name) spanning 0..\(extent)")
            return nil
        }

        // Paper: create a node labelled (S, 0, n) in G
        let root = findOrCreateNode(kind: .symbol, slot: startSymbol, i: .zero, j: extent)
        
        // Paper: while G has an extendable leaf node
        // Each pass may create new nodes, so we snapshot and repeat until stable.
        var changed = true
        while changed {
            changed = false
            let snapshot = sppfAllNodes
            for node in snapshot {
                if node.isExtendable {
                    node.extended = true
                    changed = true
                    extendNode(node)
                }
            }
        }
        
        return root
    }
    
    /// Extend an extendable leaf node by creating packed nodes based on BSR evidence.
    ///
    /// Three cases:
    ///   1. Nonterminal symbol node: find all matching alternates, decompose each
    ///      into binary form (prefix + last symbol) with pivot positions.
    ///   2. Bracket symbol node: expand iteration structure (empty/single/multi).
    ///   3. Intermediate node: look up BSR pivots for the grammar slot.
    private func extendNode(_ w: SPPFNode) {
        let i = w.i
        let j = w.j
        
        if w.isNonterminal {
            // Paper: μ is a nonterminal X
            // In our parser, the complete-rule BSR (X, i, k, j) always has k == i
            // (it stores cU, the cluster index). So mkPNforCompleteRule searches
            // the intermediate BSRs to find actual split points for each alternate.
            let X = w.slot
            if X.yield.contains(where: { $0.i == i && $0.j == j }) {
                mkPNforCompleteRule(lhs: X, i: i, j: j, parent: w)
            }
        } else if w.kind == .symbol && w.slot.kind.isBracket {
            // Bracket symbol node acting as anonymous nonterminal.
            // Uses bracket-specific expansion that understands iteration structure.
            extendBracketNode(w)
        } else {
            // Paper: μ is X ::= α · δ (an intermediate node)
            let slot = w.slot
            guard let alphaLen = slotIndex[slot] else {
                #Trace("SPPF: no slot index for \(slot) kind=\(slot.kind)")
                return
            }
            
            if alphaLen == 1 {
                // Paper: if (|α| = 1) mkPN(X ::= α · δ, i, i, j, G)
                // Single symbol before the dot — pivot is at left extent.
                mkPN(slot: slot, i: i, k: i, j: j, parent: w)
            } else if slot.kind.isBracket {
                // Bracket as last symbol of a multi-symbol prefix:
                // BSR pivots for brackets represent iteration starts, not the split
                // between predecessor and bracket. Find where the bracket begins
                // by looking at the predecessor symbol's end positions.
                if let prevSymbol = predecessorSlot(of: slot, steps: 1) {
                    for k in endPositions(prevSymbol, from: i) {
                        mkPN(slot: slot, i: i, k: k, j: j, parent: w)
                    }
                }
            } else {
                // Paper: for each (α, i, k, j) ∈ Υ { mkPN(X ::= α · δ, i, k, j, G) }
                // Look up BSR evidence directly from the slot's yield.
                for span in slot.yield where span.i == i && span.j == j {
                    mkPN(slot: slot, i: i, k: span.k, j: j, parent: w)
                }
            }
        }
    }
    
    /// Extend a bracket (DO/OPT/KLN/POS) symbol node.
    ///
    /// Brackets produce per-iteration BSRs: (bracket, outer_cU, iteration_start, iteration_end).
    /// The SPPF is built left-associatively:
    ///   - Empty match (KLN/OPT only): packed node → ε
    ///   - Single iteration (k == i): packed node → alternate content
    ///   - Multiple iterations: packed node → (bracket(i,k), alternate_content(k,j))
    ///     where k is the last iteration start, creating recursive bracket structure.
    private func extendBracketNode(_ w: SPPFNode) {
        let bracket = w.slot
        let bodyEnd = bracket.bracketEndNode!  // END node = {τ·} slot
        let i = w.i
        let j = w.j
        
        if i == j {
            // Empty match (KLN/OPT matching nothing) — create packed node with ε child
            let packedNode = SPPFNode(kind: .packed, slot: bodyEnd, i: i, j: .unused)
            w.children.append(packedNode)
            sppfAllNodes.append(packedNode)
            
            let epsNode = findOrCreateEpsilonSymbolNode(at: i)
            packedNode.children.append(epsNode)
            return
        }
        
        // Find last iteration starts: BSR spans ending at j give us iteration boundaries.
        var lastIterationStarts: Set<TokenPosition> = []
        for span in bracket.yield where span.j == j {
            lastIterationStarts.insert(span.k)
        }
        
        // Filter to starts reachable from i through the bracket's iteration chain.
        let bracketReach = endPositions(bracket, from: i)
        let reachableStarts = lastIterationStarts.filter { k in
            k >= i && k < j && (k == i || bracketReach.contains(k))
        }
        
        for k in reachableStarts {
            if k == i {
                // Single iteration: bracket content matches i→j directly.
                mkBracketIterationContent(bracket: bracket, i: i, j: j, parent: w)
            } else {
                // Multiple iterations: left = bracket(i, k), right = last iteration content(k, j)
                let packedNode = SPPFNode(kind: .packed, slot: bodyEnd, i: k, j: .unused)
                w.children.append(packedNode)
                sppfAllNodes.append(packedNode)
                
                // Right child: content of one iteration spanning (k, j)
                mkBracketIterationContent(bracket: bracket, i: k, j: j, parent: packedNode)
                
                // Left child: bracket itself spanning (i, k) — recursive structure
                let leftChild = findOrCreateNode(kind: .symbol, slot: bracket, i: i, j: k)
                packedNode.children.append(leftChild)
            }
        }
    }
    
    /// Create the SPPF content for one iteration of a bracket spanning (i, j).
    /// Searches the bracket's alternates to find which one matched and decomposes it
    /// into binary form, mirroring mkPNforCompleteRule but for bracket bodies.
    private func mkBracketIterationContent(bracket: GrammarNode, i: TokenPosition, j: TokenPosition, parent: SPPFNode) {
        let bodyEnd = bracket.bracketEndNode!  // END node = {τ·} slot
        
        // Walk the bracket's alternates
        var altNode = bracket.alt
        while let alt = altNode {
            defer { altNode = alt.alt }
            
            let symbols = alt.bodySymbols
            guard !symbols.isEmpty else { continue }
            
            let last = symbols.last!
            
            if symbols.count == 1 {
                // Single-symbol alternate: check for BSR evidence
                let spans = last.yield.filter { $0.i == i && $0.j == j }
                if spans.contains(where: { $0.k == i }) {
                    if parent.kind == .packed {
                        let child = makeSymbolOrIntermediateNode(for: last, i: i, j: j)
                        parent.children.append(child)
                    } else {
                        // Parent is the bracket symbol node (single iteration case)
                        let packedNode = SPPFNode(kind: .packed, slot: bodyEnd, i: i, j: .unused)
                        parent.children.append(packedNode)
                        sppfAllNodes.append(packedNode)
                        
                        let child = makeSymbolOrIntermediateNode(for: last, i: i, j: j)
                        packedNode.children.append(child)
                    }
                }
            } else {
                // Multi-symbol alternate: find pivots and decompose
                let lastSpans = last.yield.filter { $0.i == i && $0.j == j }
                for span in lastSpans {
                    let k = span.k
                    
                    if parent.kind == .packed {
                        // Already inside a packed node (multi-iteration case).
                        // Create an intermediate node for the bracket body.
                        let intermediateChild = findOrCreateNode(kind: .intermediate, slot: last, i: i, j: j)
                        parent.children.append(intermediateChild)
                    } else {
                        // Parent is the bracket symbol node (single iteration case)
                        let packedNode = SPPFNode(kind: .packed, slot: bodyEnd, i: k, j: .unused)
                        parent.children.append(packedNode)
                        sppfAllNodes.append(packedNode)
                        
                        // Right child: last symbol spanning (k, j)
                        let rightChild = makeSymbolOrIntermediateNode(for: last, i: k, j: j)
                        packedNode.children.append(rightChild)
                        
                        if symbols.count == 2 {
                            let leftChild = makeSymbolOrIntermediateNode(for: symbols[0], i: i, j: k)
                            packedNode.children.append(leftChild)
                        } else {
                            let prevSlot = symbols[symbols.count - 2]
                            let leftChild = findOrCreateNode(kind: .intermediate, slot: prevSlot, i: i, j: k)
                            packedNode.children.append(leftChild)
                        }
                    }
                }
            }
        }
    }
    
    /// Find or create an epsilon symbol node at position `pos`.
    private func findOrCreateEpsilonSymbolNode(at pos: TokenPosition) -> SPPFNode {
        // Try to find an existing EPS grammar node in the grammar
        if syntheticEpsilonNode == nil {
            outer: for (_, nt) in _sppfNonTerminals {
                var alt = nt.alt
                while let a = alt {
                    var node = a.seq
                    while let n = node {
                        if n.kind == .EPS {
                            syntheticEpsilonNode = n
                            break outer
                        }
                        if n.kind == .END { break }
                        node = n.seq
                    }
                    alt = a.alt
                }
            }
        }
        
        // If no EPS node exists in the grammar, create a synthetic one
        if syntheticEpsilonNode == nil {
            syntheticEpsilonNode = GrammarNode(kind: .EPS, name: "ε")
        }
        
        let node = findOrCreateNode(kind: .symbol, slot: syntheticEpsilonNode!, i: pos, j: pos)
        node.extended = true
        return node
    }
    
    /// Paper: mkPN(X ::= α · δ, i, k, j, G)
    /// Creates a packed node labelled with the grammar slot and pivot k,
    /// then decomposes α = βx into right child (x, k→j) and left child.
    ///
    /// The binary decomposition:
    ///   - Right child: always the last symbol x of α, spanning (k, j)
    ///   - Left child depends on |β|:
    ///     - |β| = 0: no left child (single symbol, handled elsewhere)
    ///     - |β| = 1: symbol node for β, spanning (i, k)
    ///     - |β| > 1: intermediate node for the slot before x, spanning (i, k)
    private func mkPN(slot: GrammarNode, i: TokenPosition, k: TokenPosition, j: TokenPosition, parent: SPPFNode) {
        // Paper: make a node y in G labelled (X ::= α · δ, k)
        let packedNode = SPPFNode(kind: .packed, slot: slot, i: k, j: .unused)
        parent.children.append(packedNode)
        sppfAllNodes.append(packedNode)
        
        if slot.kind == .EPS {
            // Paper: if (α = ε) mkN(ε, i, i, y, G)
            let epsNode = findOrCreateNode(kind: .symbol, slot: slot, i: i, j: i)
            epsNode.extended = true // epsilon nodes are never extendable
            packedNode.children.append(epsNode)
            
        } else {
            // Intermediate slot: the slot node IS the last symbol of α (or a bracket/nonterminal)
            // |α| = slotIndex[slot]
            mkPNforSlot(slot: slot, i: i, k: k, j: j, packedNode: packedNode)
        }
    }
    
    /// Handle a complete nonterminal: X matched from i to j.
    /// Search through X's alternates to find which ones have BSR evidence for this span,
    /// and create packed nodes with binary decomposition for each valid alternate.
    ///
    /// For single-symbol alternates: check direct BSR evidence at the last symbol.
    /// For multi-symbol alternates: find pivot positions by chaining through prefix
    /// symbols' end positions, then validate the last symbol can reach j.
    private func mkPNforCompleteRule(lhs: GrammarNode, i: TokenPosition, j: TokenPosition, parent: SPPFNode) {
        var altNode = lhs.alt
        while let alt = altNode {
            defer { altNode = alt.alt }
            
            let symbols = alt.bodySymbols
            guard !symbols.isEmpty else { continue }
            
            let last = symbols.last!
            let symbolCount = symbols.count
            
            if symbolCount == 1 {
                // Single-symbol alternate: pivot is i, the only child spans (i, j)
                let spans = last.yield.filter { $0.i == i && $0.j == j }
                let hasDirect = spans.contains { $0.k == i }
                let hasBracket = last.kind.isBracket && !spans.isEmpty
                
                if hasDirect || hasBracket {
                    let packedNode = SPPFNode(kind: .packed, slot: last, i: i, j: .unused)
                    parent.children.append(packedNode)
                    sppfAllNodes.append(packedNode)
                    
                    let child = makeSymbolOrIntermediateNode(for: last, i: i, j: j)
                    packedNode.children.append(child)
                }
            } else {
                // Multi-symbol alternate: find pivot positions where last symbol starts.
                // Chain through prefix symbols to find reachable positions, then validate
                // that the last symbol can actually reach j from that position.
                var pivots = chainEndPositions(symbols: Array(symbols.dropLast()), from: i)
                if last.kind == .KLN || last.kind == .OPT { pivots.insert(j) }
                pivots = pivots.filter { $0 >= i && $0 <= j }
                
                for k in pivots where endPositions(last, from: k).contains(j) {
                    let packedNode = SPPFNode(kind: .packed, slot: last, i: k, j: .unused)
                    parent.children.append(packedNode)
                    sppfAllNodes.append(packedNode)
                    
                    // Right child: last symbol spanning (k, j)
                    let rightChild = makeSymbolOrIntermediateNode(for: last, i: k, j: j)
                    packedNode.children.append(rightChild)
                    
                    if symbolCount == 2 {
                        // Left child: the first symbol spanning (i, k)
                        let leftChild = makeSymbolOrIntermediateNode(for: symbols[0], i: i, j: k)
                        packedNode.children.append(leftChild)
                    } else {
                        // Left child: intermediate node for the second-to-last symbol, spanning (i, k)
                        let prevSlot = symbols[symbolCount - 2]
                        let leftChild = findOrCreateNode(kind: .intermediate, slot: prevSlot, i: i, j: k)
                        packedNode.children.append(leftChild)
                    }
                }
            }
        }
    }
    
    /// Handle mkPN for an intermediate slot BSR.
    /// Decomposes α = βx where x is the slot (last symbol of α):
    ///   - Right child: symbol/intermediate node for x spanning (k, j)
    ///   - Left child: depends on |β| (see mkPN documentation)
    private func mkPNforSlot(slot: GrammarNode, i: TokenPosition, k: TokenPosition, j: TokenPosition, packedNode: SPPFNode) {
        guard let alphaLen = slotIndex[slot] else { return }
        
        // Paper: α = βx where |x| = 1
        let betaLen = alphaLen - 1
        
        // Right child: mkN(x, k, j, y, G)
        let rightChild = makeSymbolOrIntermediateNode(for: slot, i: k, j: j)
        packedNode.children.append(rightChild)
        
        if betaLen == 1 {
            // Paper: if (|β| = 1) mkN(β, i, k, y, G)
            if let prevSymbol = predecessorSlot(of: slot, steps: 1) {
                let leftChild = makeSymbolOrIntermediateNode(for: prevSymbol, i: i, j: k)
                packedNode.children.append(leftChild)
            }
        } else if betaLen > 1 {
            // Paper: if (|β| > 1) mkN(X ::= β · xδ, i, k, y, G)
            if let prevSlot = predecessorSlot(of: slot, steps: 1) {
                let leftChild = findOrCreateNode(kind: .intermediate, slot: prevSlot, i: i, j: k)
                packedNode.children.append(leftChild)
            }
        }
        // if betaLen == 0: no left child (single-symbol case handled in extendNode)
    }
    
    /// Create the appropriate SPPF node for a grammar symbol:
    ///   - RHS nonterminal → symbol node for its LHS definition (enables sharing)
    ///   - Terminal/epsilon → symbol node (marked as non-extendable)
    ///   - Bracket → symbol node (acts like anonymous nonterminal)
    ///   - Other → intermediate node (grammar slot position)
    private func makeSymbolOrIntermediateNode(for node: GrammarNode, i: TokenPosition, j: TokenPosition) -> SPPFNode {
        switch node.kind {
        case .N:
            if node.isLHS {
                return findOrCreateNode(kind: .symbol, slot: node, i: i, j: j)
            } else {
                // RHS nonterminal: redirect to the LHS definition for node sharing
                return findOrCreateNode(kind: .symbol, slot: node.alt!, i: i, j: j)
            }
        case .T, .TI, .C, .B:
            let n = findOrCreateNode(kind: .symbol, slot: node, i: i, j: j)
            n.extended = true // terminals are never extendable
            return n
        case .EPS:
            let n = findOrCreateNode(kind: .symbol, slot: node, i: i, j: j)
            n.extended = true
            return n
        case .DO, .OPT, .KLN, .POS:
            // Brackets act like anonymous nonterminals
            return findOrCreateNode(kind: .symbol, slot: node, i: i, j: j)
        default:
            // Intermediate slot
            return findOrCreateNode(kind: .intermediate, slot: node, i: i, j: j)
        }
    }
    
    /// Paper: mkN(Ω, i, j, y, G) — find or create a node labelled (Ω, i, j).
    /// Node deduplication ensures the SPPF remains a compact DAG rather than a tree.
    private func findOrCreateNode(kind: SPPFNodeKind, slot: GrammarNode, i: TokenPosition, j: TokenPosition) -> SPPFNode {
        let key = SPPFNodeKey(slot: slot, i: i, j: j)
        if let existing = sppfNodes[key] {
            return existing
        }
        let node = SPPFNode(kind: kind, slot: slot, i: i, j: j)
        sppfNodes[key] = node
        sppfAllNodes.append(node)
        return node
    }
}

// MARK: - Graphviz SPPF Diagram Generation

/// Generate a Graphviz dot file for the SPPF.
/// Node shapes follow the paper's conventions:
///   - Symbol nodes (nonterminals, terminals): rounded rectangles
///   - Intermediate nodes (grammar slots): rectangles
///   - Packed nodes: rectangles (labelled with pivot)
func generateSPPFDiagram(outputFile file: URL, root: SPPFNode) throws {
    var dot = """
    digraph SPPF {
      fontname = Menlo
      fontsize = 10
      node [fontname = Menlo, fontsize = 10]
      edge [arrowsize = 0.4]
      rankdir = "TB"
      ordering = out
    
    """
    
    // Assign stable IDs to all nodes
    var nodeIDs: [ObjectIdentifier: String] = [:]
    var nextID = 0
    
    func nodeID(_ node: SPPFNode) -> String {
        let oid = ObjectIdentifier(node)
        if let id = nodeIDs[oid] { return id }
        let id = "n\(nextID)"
        nextID += 1
        nodeIDs[oid] = id
        return id
    }
    
    // Collect all reachable nodes via BFS
    var visited: Set<ObjectIdentifier> = []
    var queue: [SPPFNode] = [root]
    var allReachable: [SPPFNode] = []
    
    while !queue.isEmpty {
        let node = queue.removeFirst()
        let oid = ObjectIdentifier(node)
        guard visited.insert(oid).inserted else { continue }
        allReachable.append(node)
        for child in node.children {
            queue.append(child)
        }
    }
    
    // Emit nodes
    for node in allReachable {
        let id = nodeID(node)
        let escapedLabel = node.label.graphvizHTML
        
        switch node.kind {
        case .symbol:
            if node.slot.kind == .EPS {
                dot += "  \(id) [shape = box, style = \"rounded, dashed\", width=0.0, height=0.0, label = <\(escapedLabel)>]\n"
            } else if node.slot.kind.isBracket {
                // Bracket closure subtree roots display as intermediate nodes (rectangles)
                dot += "  \(id) [shape = rectangle, width=0.0, height=0.0, label = <\(escapedLabel)>]\n"
            } else {
                dot += "  \(id) [shape = box, style = rounded, width=0.0, height=0.0, label = <\(escapedLabel)>]\n"
            }
        case .intermediate:
            dot += "  \(id) [shape = rectangle, width=0.0, height=0.0, label = <\(escapedLabel)>]\n"
        case .packed:
            dot += "  \(id) [shape = rectangle, width=0.0, height=0.0, label = \"\(escapedLabel)\"]\n"
        }
    }
    
    // Emit edges — sort children by left extent so leaves read left-to-right
    for node in allReachable {
        let parentID = nodeID(node)
        let sortedChildren = node.children.sorted { $0.i < $1.i }
        for child in sortedChildren {
            let childID = nodeID(child)
            dot += "  \(parentID) -> \(childID)\n"
        }
    }
    
    dot += "}\n"
    
    try dot.write(to: file, atomically: true, encoding: .utf8)
}
//
//  StringExtensions.swift
//  Advent
//
//  Created by Johannes Brands on 25/01/2021.
//

import OSLog
import Foundation

extension Character {
    // Set of Unicode scalar values for epsilon-related codepoints
    private static let epsilonScalars: [UInt32] = [
        0x03B5,  // ε - GREEK SMALL LETTER EPSILON
        0x03F5,  // ϵ - GREEK LUNATE EPSILON SYMBOL
        0x0510,  // Ԑ - CYRILLIC CAPITAL LETTER REVERSED ZE OR EPSILON
        0x0511,  // ԑ - CYRILLIC SMALL LETTER REVERSED ZE OR EPSILON
        0x1D6C6, // 𝛆 - MATHEMATICAL BOLD CAPITAL EPSILON
        0x1D6DC, // 𝛜 - MATHEMATICAL BOLD SMALL EPSILON
        0x1D700, // 𝜀 - MATHEMATICAL ITALIC CAPITAL EPSILON
        0x1D716, // 𝜖 - MATHEMATICAL ITALIC SMALL EPSILON
        0x1D73A, // 𝜺 - MATHEMATICAL BOLD ITALIC CAPITAL EPSILON
        0x1D750, // 𝝐 - MATHEMATICAL BOLD ITALIC SMALL EPSILON
        0x1D774, // 𝝴 - MATHEMATICAL SANS-SERIF BOLD CAPITAL EPSILON
        0x1D78A, // 𝞊 - MATHEMATICAL SANS-SERIF BOLD SMALL EPSILON
        0x1D7AE, // 𝞮 - MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL EPSILON
        0x1D7C4, // 𝟄 - MATHEMATICAL SANS-SERIF BOLD ITALIC SMALL EPSILON
    ]

    var isEpsilon: Bool {
        // A Character can have multiple scalars (e.g. composed characters),
        // but these epsilons are single scalars, so we check the first one
        guard let scalar = unicodeScalars.first else { return false }
        return Self.epsilonScalars.contains(scalar.value)
    }
}

extension String {
    
    var escapesAdded: String {
        self.unicodeScalars
            .reduce("") { $0 + $1.escaped(asASCII: false)}
    }
    
    var escapesRemoved: String {
        var modified = self
        for entity in ["\0", "\t", "\n", "\r", "\"", "\\"] {
            let escapedCharacter = entity.escapesAdded
            modified = modified.replacingOccurrences(of: escapedCharacter, with: entity)
        }
        return modified
    }
    
    // https://forum.graphviz.org/t/how-do-i-properly-escape-arbitrary-text-for-use-in-labels/1762/5
    var graphvizHTML: String {
        var modified = ""
        for char in self {
            switch char {
            case "&":   modified.append("&amp;")
            case "<":   modified.append("&lt;")
            case ">":   modified.append("&gt;")
            case "\n":  modified.append("<br/>")
            default:    modified.append(char)
            }
        }
        return modified.escapesRemoved
    }

    var whitespaceMadeVisible: String {
        self
            .replacingOccurrences(of: " ", with: "·")
            .replacingOccurrences(of: "\t", with: "→")
            .replacingOccurrences(of: "\n", with: "↵")
    }
}

extension String {
    func linePosition(of index: String.Index) -> String {
        var line = 0
        var lineStart = self.startIndex
        while let match = self[lineStart ..< index].firstIndex(of: "\n") {
            line += 1
            lineStart = self.index(match, offsetBy: 1)
        }
        let position = self.distance(from: lineStart, to: index)
        return "L\(line)P\(position)"
    }
}

extension String {
    var validSwiftIdentifier: String {
        var valid = ""
        for c in self {
            if c.isLetter || c.isNumber {
                valid.append(c)
            } else {
                for s in c.unicodeScalars {
                    if let alias = nameAliases[s] {
                        valid.append(alias)
                    } else if let name = s.properties.name {
                        let cleaned = name.capitalized
                            .replacingOccurrences(of: " ", with: "")
                            .replacingOccurrences(of: "-", with: "")
                        valid.append(cleaned)
                    } else {
                        assertionFailure("String \(self) contains Unicode scalar \\u{\(String(s.value, radix: 16, uppercase: true))} with no name or alias")
                        valid.append("U\(String(s.value, radix: 16, uppercase: true))")
                    }
                }
            }
        }
        if let first = valid.first {
            if first.isNumber {
                valid = "_" + valid
            } else {
                valid = first.lowercased() + valid.dropFirst()
            }
        } else {
            assertionFailure("Empty string cannot be converted to a Swift identifier")
            valid = "_empty"
        }
        return valid
    }
}

// https://www.unicode.org/Public/draft/UCD/ucd/NameAliases.txt
fileprivate let nameAliases: [UnicodeScalar:String] = [
    "\u{0000}" : "NUL",
    "\u{0001}" : "SOH",
    "\u{0002}" : "STX",
    "\u{0003}" : "ETX",
    "\u{0004}" : "EOT",
    "\u{0005}" : "ENQ",
    "\u{0006}" : "ACK",
    "\u{0007}" : "BEL",
    "\u{0008}" : "BS",
    "\u{0009}" : "HT",
    "\u{000A}" : "NL",
    "\u{000B}" : "VT",
    "\u{000C}" : "FF",
    "\u{000D}" : "CR",
    "\u{000E}" : "SO",
    "\u{000F}" : "SI",
    "\u{0010}" : "DLE",
    "\u{0011}" : "DC1",
    "\u{0012}" : "DC2",
    "\u{0013}" : "DC3",
    "\u{0014}" : "DC4",
    "\u{0015}" : "NAK",
    "\u{0016}" : "SYN",
    "\u{0017}" : "ETB",
    "\u{0018}" : "CAN",
    "\u{0019}" : "EOM",
    "\u{001A}" : "SUB",
    "\u{001B}" : "ESC",
    "\u{001C}" : "FS",
    "\u{001D}" : "GS",
    "\u{001E}" : "RS",
    "\u{001F}" : "US",
    "\u{0020}" : "SP",
    
    "\u{007F}" : "DEL",
]

/*
 # https://www.unicode.org/Public/13.0.0/ucd/NameAliases.txt
 
 # NameAliases-13.0.0.txt
 # Date: 2019-09-09, 19:47:00 GMT [KW, LI]
 # © 2019 Unicode®, Inc.
 # For terms of use, see http://www.unicode.org/terms_of_use.html
 #
 # Unicode Character Database
 # For documentation, see http://www.unicode.org/reports/tr44/
 #
 # This file is a normative contributory data file in the
 # Unicode Character Database.
 #
 # This file defines the formal name aliases for Unicode characters.
 #
 # For informative aliases, see NamesList.txt
 #
 # The formal name aliases are divided into five types, each with a distinct label.
 #
 # Type Labels:
 #
 # 1. correction
 #      Corrections for serious problems in the character names
 # 2. control
 #      ISO 6429 names for C0 and C1 control functions, and other
 #      commonly occurring names for control codes
 # 3. alternate
 #      A few widely used alternate names for format characters
 # 4. figment
 #      Several documented labels for C1 control code points which
 #      were never actually approved in any standard
 # 5. abbreviation
 #      Commonly occurring abbreviations (or acronyms) for control codes,
 #      format characters, spaces, and variation selectors
 #
 # The formal name aliases are part of the Unicode character namespace, which
 # includes the character names and the names of named character sequences.
 # The inclusion of ISO 6429 names and other commonly occurring names and
 # abbreviations for control codes and format characters as formal name aliases
 # is to help avoid name collisions between Unicode character names and the
 # labels which commonly appear in text and/or in implementations such as regex, for
 # control codes (which for historical reasons have no Unicode character name)
 # or for format characters.
 #
 # For documentation, see NamesList.html and http://www.unicode.org/reports/tr44/
 #
 # FORMAT
 #
 # Each line has three fields, as described here:
 #
 # First field:  Code point
 # Second field: Alias
 # Third field:  Type
 #
 # The type labels used are defined above. As for property values, comparisons
 # of type labels should ignore case.
 #
 # The type labels can be mapped to other strings for display, if desired.
 #
 # In case multiple aliases are assigned, additional aliases
 # are provided on separate lines. Parsers of this data file should
 # take note that the same code point can (and does) occur more than once.
 #
 # Note that currently the only instances of multiple aliases of the same
 # type for a single code point are either of type "control" or "abbreviation".
 # An alias of type "abbreviation" can, in principle, be added for any code
 # point, although currently aliases of type "correction" do not have
 # any additional aliases of type "abbreviation". Such relationships
 # are not enforced by stability policies.
 #
 #-----------------------------------------------------------------
 
 0000;NULL;control
 0000;NUL;abbreviation
 0001;START OF HEADING;control
 0001;SOH;abbreviation
 0002;START OF TEXT;control
 0002;STX;abbreviation
 0003;END OF TEXT;control
 0003;ETX;abbreviation
 0004;END OF TRANSMISSION;control
 0004;EOT;abbreviation
 0005;ENQUIRY;control
 0005;ENQ;abbreviation
 0006;ACKNOWLEDGE;control
 0006;ACK;abbreviation
 
 # Note that no formal name alias for the ISO 6429 "BELL" is
 # provided for U+0007, because of the existing name collision
 # with U+1F514 BELL.
 
 0007;ALERT;control
 0007;BEL;abbreviation
 
 0008;BACKSPACE;control
 0008;BS;abbreviation
 0009;CHARACTER TABULATION;control
 0009;HORIZONTAL TABULATION;control
 0009;HT;abbreviation
 0009;TAB;abbreviation
 000A;LINE FEED;control
 000A;NEW LINE;control
 000A;END OF LINE;control
 000A;LF;abbreviation
 000A;NL;abbreviation
 000A;EOL;abbreviation
 000B;LINE TABULATION;control
 000B;VERTICAL TABULATION;control
 000B;VT;abbreviation
 000C;FORM FEED;control
 000C;FF;abbreviation
 000D;CARRIAGE RETURN;control
 000D;CR;abbreviation
 000E;SHIFT OUT;control
 000E;LOCKING-SHIFT ONE;control
 000E;SO;abbreviation
 000F;SHIFT IN;control
 000F;LOCKING-SHIFT ZERO;control
 000F;SI;abbreviation
 0010;DATA LINK ESCAPE;control
 0010;DLE;abbreviation
 0011;DEVICE CONTROL ONE;control
 0011;DC1;abbreviation
 0012;DEVICE CONTROL TWO;control
 0012;DC2;abbreviation
 0013;DEVICE CONTROL THREE;control
 0013;DC3;abbreviation
 0014;DEVICE CONTROL FOUR;control
 0014;DC4;abbreviation
 0015;NEGATIVE ACKNOWLEDGE;control
 0015;NAK;abbreviation
 0016;SYNCHRONOUS IDLE;control
 0016;SYN;abbreviation
 0017;END OF TRANSMISSION BLOCK;control
 0017;ETB;abbreviation
 0018;CANCEL;control
 0018;CAN;abbreviation
 0019;END OF MEDIUM;control
 0019;EOM;abbreviation
 001A;SUBSTITUTE;control
 001A;SUB;abbreviation
 001B;ESCAPE;control
 001B;ESC;abbreviation
 001C;INFORMATION SEPARATOR FOUR;control
 001C;FILE SEPARATOR;control
 001C;FS;abbreviation
 001D;INFORMATION SEPARATOR THREE;control
 001D;GROUP SEPARATOR;control
 001D;GS;abbreviation
 001E;INFORMATION SEPARATOR TWO;control
 001E;RECORD SEPARATOR;control
 001E;RS;abbreviation
 001F;INFORMATION SEPARATOR ONE;control
 001F;UNIT SEPARATOR;control
 001F;US;abbreviation
 0020;SP;abbreviation
 007F;DELETE;control
 007F;DEL;abbreviation
 
 # PADDING CHARACTER and HIGH OCTET PRESET represent
 # architectural concepts initially proposed for early
 # drafts of ISO/IEC 10646-1. They were never actually
 # approved or standardized: hence their designation
 # here as the "figment" type. Formal name aliases
 # (and corresponding abbreviations) for these code
 # points are included here because these names leaked
 # out from the draft documents and were published in
 # at least one RFC whose names for code points was
 # implemented in Perl regex expressions.
 
 0080;PADDING CHARACTER;figment
 0080;PAD;abbreviation
 0081;HIGH OCTET PRESET;figment
 0081;HOP;abbreviation
 
 0082;BREAK PERMITTED HERE;control
 0082;BPH;abbreviation
 0083;NO BREAK HERE;control
 0083;NBH;abbreviation
 0084;INDEX;control
 0084;IND;abbreviation
 0085;NEXT LINE;control
 0085;NEL;abbreviation
 0086;START OF SELECTED AREA;control
 0086;SSA;abbreviation
 0087;END OF SELECTED AREA;control
 0087;ESA;abbreviation
 0088;CHARACTER TABULATION SET;control
 0088;HORIZONTAL TABULATION SET;control
 0088;HTS;abbreviation
 0089;CHARACTER TABULATION WITH JUSTIFICATION;control
 0089;HORIZONTAL TABULATION WITH JUSTIFICATION;control
 0089;HTJ;abbreviation
 008A;LINE TABULATION SET;control
 008A;VERTICAL TABULATION SET;control
 008A;VTS;abbreviation
 008B;PARTIAL LINE FORWARD;control
 008B;PARTIAL LINE DOWN;control
 008B;PLD;abbreviation
 008C;PARTIAL LINE BACKWARD;control
 008C;PARTIAL LINE UP;control
 008C;PLU;abbreviation
 008D;REVERSE LINE FEED;control
 008D;REVERSE INDEX;control
 008D;RI;abbreviation
 008E;SINGLE SHIFT TWO;control
 008E;SINGLE-SHIFT-2;control
 008E;SS2;abbreviation
 008F;SINGLE SHIFT THREE;control
 008F;SINGLE-SHIFT-3;control
 008F;SS3;abbreviation
 0090;DEVICE CONTROL STRING;control
 0090;DCS;abbreviation
 0091;PRIVATE USE ONE;control
 0091;PRIVATE USE-1;control
 0091;PU1;abbreviation
 0092;PRIVATE USE TWO;control
 0092;PRIVATE USE-2;control
 0092;PU2;abbreviation
 0093;SET TRANSMIT STATE;control
 0093;STS;abbreviation
 0094;CANCEL CHARACTER;control
 0094;CCH;abbreviation
 0095;MESSAGE WAITING;control
 0095;MW;abbreviation
 0096;START OF GUARDED AREA;control
 0096;START OF PROTECTED AREA;control
 0096;SPA;abbreviation
 0097;END OF GUARDED AREA;control
 0097;END OF PROTECTED AREA;control
 0097;EPA;abbreviation
 0098;START OF STRING;control
 0098;SOS;abbreviation
 
 # SINGLE GRAPHIC CHARACTER INTRODUCER is another
 # architectural concept from early drafts of ISO/IEC 10646-1
 # which was never approved and standardized.
 
 0099;SINGLE GRAPHIC CHARACTER INTRODUCER;figment
 0099;SGC;abbreviation
 
 009A;SINGLE CHARACTER INTRODUCER;control
 009A;SCI;abbreviation
 009B;CONTROL SEQUENCE INTRODUCER;control
 009B;CSI;abbreviation
 009C;STRING TERMINATOR;control
 009C;ST;abbreviation
 009D;OPERATING SYSTEM COMMAND;control
 009D;OSC;abbreviation
 009E;PRIVACY MESSAGE;control
 009E;PM;abbreviation
 009F;APPLICATION PROGRAM COMMAND;control
 009F;APC;abbreviation
 00A0;NBSP;abbreviation
 00AD;SHY;abbreviation
 01A2;LATIN CAPITAL LETTER GHA;correction
 01A3;LATIN SMALL LETTER GHA;correction
 034F;CGJ;abbreviation
 061C;ALM;abbreviation
 0709;SYRIAC SUBLINEAR COLON SKEWED LEFT;correction
 0CDE;KANNADA LETTER LLLA;correction
 0E9D;LAO LETTER FO FON;correction
 0E9F;LAO LETTER FO FAY;correction
 0EA3;LAO LETTER RO;correction
 0EA5;LAO LETTER LO;correction
 0FD0;TIBETAN MARK BKA- SHOG GI MGO RGYAN;correction
 11EC;HANGUL JONGSEONG YESIEUNG-KIYEOK;correction
 11ED;HANGUL JONGSEONG YESIEUNG-SSANGKIYEOK;correction
 11EE;HANGUL JONGSEONG SSANGYESIEUNG;correction
 11EF;HANGUL JONGSEONG YESIEUNG-KHIEUKH;correction
 180B;FVS1;abbreviation
 180C;FVS2;abbreviation
 180D;FVS3;abbreviation
 180E;MVS;abbreviation
 200B;ZWSP;abbreviation
 200C;ZWNJ;abbreviation
 200D;ZWJ;abbreviation
 200E;LRM;abbreviation
 200F;RLM;abbreviation
 202A;LRE;abbreviation
 202B;RLE;abbreviation
 202C;PDF;abbreviation
 202D;LRO;abbreviation
 202E;RLO;abbreviation
 202F;NNBSP;abbreviation
 205F;MMSP;abbreviation
 2060;WJ;abbreviation
 2066;LRI;abbreviation
 2067;RLI;abbreviation
 2068;FSI;abbreviation
 2069;PDI;abbreviation
 2118;WEIERSTRASS ELLIPTIC FUNCTION;correction
 2448;MICR ON US SYMBOL;correction
 2449;MICR DASH SYMBOL;correction
 2B7A;LEFTWARDS TRIANGLE-HEADED ARROW WITH DOUBLE VERTICAL STROKE;correction
 2B7C;RIGHTWARDS TRIANGLE-HEADED ARROW WITH DOUBLE VERTICAL STROKE;correction
 A015;YI SYLLABLE ITERATION MARK;correction
 FE00;VS1;abbreviation
 FE01;VS2;abbreviation
 FE02;VS3;abbreviation
 FE03;VS4;abbreviation
 FE04;VS5;abbreviation
 FE05;VS6;abbreviation
 FE06;VS7;abbreviation
 FE07;VS8;abbreviation
 FE08;VS9;abbreviation
 FE09;VS10;abbreviation
 FE0A;VS11;abbreviation
 FE0B;VS12;abbreviation
 FE0C;VS13;abbreviation
 FE0D;VS14;abbreviation
 FE0E;VS15;abbreviation
 FE0F;VS16;abbreviation
 FE18;PRESENTATION FORM FOR VERTICAL RIGHT WHITE LENTICULAR BRACKET;correction
 FEFF;BYTE ORDER MARK;alternate
 FEFF;BOM;abbreviation
 FEFF;ZWNBSP;abbreviation
 122D4;CUNEIFORM SIGN NU11 TENU;correction
 122D5;CUNEIFORM SIGN NU11 OVER NU11 BUR OVER BUR;correction
 16E56;MEDEFAIDRIN CAPITAL LETTER H;correction
 16E57;MEDEFAIDRIN CAPITAL LETTER NG;correction
 16E76;MEDEFAIDRIN SMALL LETTER H;correction
 16E77;MEDEFAIDRIN SMALL LETTER NG;correction
 1B001;HENTAIGANA LETTER E-1;correction
 1D0C5;BYZANTINE MUSICAL SYMBOL FTHORA SKLIRON CHROMA VASIS;correction
 E0100;VS17;abbreviation
 E0101;VS18;abbreviation
 E0102;VS19;abbreviation
 E0103;VS20;abbreviation
 E0104;VS21;abbreviation
 E0105;VS22;abbreviation
 E0106;VS23;abbreviation
 E0107;VS24;abbreviation
 E0108;VS25;abbreviation
 E0109;VS26;abbreviation
 E010A;VS27;abbreviation
 E010B;VS28;abbreviation
 E010C;VS29;abbreviation
 E010D;VS30;abbreviation
 E010E;VS31;abbreviation
 E010F;VS32;abbreviation
 E0110;VS33;abbreviation
 E0111;VS34;abbreviation
 E0112;VS35;abbreviation
 E0113;VS36;abbreviation
 E0114;VS37;abbreviation
 E0115;VS38;abbreviation
 E0116;VS39;abbreviation
 E0117;VS40;abbreviation
 E0118;VS41;abbreviation
 E0119;VS42;abbreviation
 E011A;VS43;abbreviation
 E011B;VS44;abbreviation
 E011C;VS45;abbreviation
 E011D;VS46;abbreviation
 E011E;VS47;abbreviation
 E011F;VS48;abbreviation
 E0120;VS49;abbreviation
 E0121;VS50;abbreviation
 E0122;VS51;abbreviation
 E0123;VS52;abbreviation
 E0124;VS53;abbreviation
 E0125;VS54;abbreviation
 E0126;VS55;abbreviation
 E0127;VS56;abbreviation
 E0128;VS57;abbreviation
 E0129;VS58;abbreviation
 E012A;VS59;abbreviation
 E012B;VS60;abbreviation
 E012C;VS61;abbreviation
 E012D;VS62;abbreviation
 E012E;VS63;abbreviation
 E012F;VS64;abbreviation
 E0130;VS65;abbreviation
 E0131;VS66;abbreviation
 E0132;VS67;abbreviation
 E0133;VS68;abbreviation
 E0134;VS69;abbreviation
 E0135;VS70;abbreviation
 E0136;VS71;abbreviation
 E0137;VS72;abbreviation
 E0138;VS73;abbreviation
 E0139;VS74;abbreviation
 E013A;VS75;abbreviation
 E013B;VS76;abbreviation
 E013C;VS77;abbreviation
 E013D;VS78;abbreviation
 E013E;VS79;abbreviation
 E013F;VS80;abbreviation
 E0140;VS81;abbreviation
 E0141;VS82;abbreviation
 E0142;VS83;abbreviation
 E0143;VS84;abbreviation
 E0144;VS85;abbreviation
 E0145;VS86;abbreviation
 E0146;VS87;abbreviation
 E0147;VS88;abbreviation
 E0148;VS89;abbreviation
 E0149;VS90;abbreviation
 E014A;VS91;abbreviation
 E014B;VS92;abbreviation
 E014C;VS93;abbreviation
 E014D;VS94;abbreviation
 E014E;VS95;abbreviation
 E014F;VS96;abbreviation
 E0150;VS97;abbreviation
 E0151;VS98;abbreviation
 E0152;VS99;abbreviation
 E0153;VS100;abbreviation
 E0154;VS101;abbreviation
 E0155;VS102;abbreviation
 E0156;VS103;abbreviation
 E0157;VS104;abbreviation
 E0158;VS105;abbreviation
 E0159;VS106;abbreviation
 E015A;VS107;abbreviation
 E015B;VS108;abbreviation
 E015C;VS109;abbreviation
 E015D;VS110;abbreviation
 E015E;VS111;abbreviation
 E015F;VS112;abbreviation
 E0160;VS113;abbreviation
 E0161;VS114;abbreviation
 E0162;VS115;abbreviation
 E0163;VS116;abbreviation
 E0164;VS117;abbreviation
 E0165;VS118;abbreviation
 E0166;VS119;abbreviation
 E0167;VS120;abbreviation
 E0168;VS121;abbreviation
 E0169;VS122;abbreviation
 E016A;VS123;abbreviation
 E016B;VS124;abbreviation
 E016C;VS125;abbreviation
 E016D;VS126;abbreviation
 E016E;VS127;abbreviation
 E016F;VS128;abbreviation
 E0170;VS129;abbreviation
 E0171;VS130;abbreviation
 E0172;VS131;abbreviation
 E0173;VS132;abbreviation
 E0174;VS133;abbreviation
 E0175;VS134;abbreviation
 E0176;VS135;abbreviation
 E0177;VS136;abbreviation
 E0178;VS137;abbreviation
 E0179;VS138;abbreviation
 E017A;VS139;abbreviation
 E017B;VS140;abbreviation
 E017C;VS141;abbreviation
 E017D;VS142;abbreviation
 E017E;VS143;abbreviation
 E017F;VS144;abbreviation
 E0180;VS145;abbreviation
 E0181;VS146;abbreviation
 E0182;VS147;abbreviation
 E0183;VS148;abbreviation
 E0184;VS149;abbreviation
 E0185;VS150;abbreviation
 E0186;VS151;abbreviation
 E0187;VS152;abbreviation
 E0188;VS153;abbreviation
 E0189;VS154;abbreviation
 E018A;VS155;abbreviation
 E018B;VS156;abbreviation
 E018C;VS157;abbreviation
 E018D;VS158;abbreviation
 E018E;VS159;abbreviation
 E018F;VS160;abbreviation
 E0190;VS161;abbreviation
 E0191;VS162;abbreviation
 E0192;VS163;abbreviation
 E0193;VS164;abbreviation
 E0194;VS165;abbreviation
 E0195;VS166;abbreviation
 E0196;VS167;abbreviation
 E0197;VS168;abbreviation
 E0198;VS169;abbreviation
 E0199;VS170;abbreviation
 E019A;VS171;abbreviation
 E019B;VS172;abbreviation
 E019C;VS173;abbreviation
 E019D;VS174;abbreviation
 E019E;VS175;abbreviation
 E019F;VS176;abbreviation
 E01A0;VS177;abbreviation
 E01A1;VS178;abbreviation
 E01A2;VS179;abbreviation
 E01A3;VS180;abbreviation
 E01A4;VS181;abbreviation
 E01A5;VS182;abbreviation
 E01A6;VS183;abbreviation
 E01A7;VS184;abbreviation
 E01A8;VS185;abbreviation
 E01A9;VS186;abbreviation
 E01AA;VS187;abbreviation
 E01AB;VS188;abbreviation
 E01AC;VS189;abbreviation
 E01AD;VS190;abbreviation
 E01AE;VS191;abbreviation
 E01AF;VS192;abbreviation
 E01B0;VS193;abbreviation
 E01B1;VS194;abbreviation
 E01B2;VS195;abbreviation
 E01B3;VS196;abbreviation
 E01B4;VS197;abbreviation
 E01B5;VS198;abbreviation
 E01B6;VS199;abbreviation
 E01B7;VS200;abbreviation
 E01B8;VS201;abbreviation
 E01B9;VS202;abbreviation
 E01BA;VS203;abbreviation
 E01BB;VS204;abbreviation
 E01BC;VS205;abbreviation
 E01BD;VS206;abbreviation
 E01BE;VS207;abbreviation
 E01BF;VS208;abbreviation
 E01C0;VS209;abbreviation
 E01C1;VS210;abbreviation
 E01C2;VS211;abbreviation
 E01C3;VS212;abbreviation
 E01C4;VS213;abbreviation
 E01C5;VS214;abbreviation
 E01C6;VS215;abbreviation
 E01C7;VS216;abbreviation
 E01C8;VS217;abbreviation
 E01C9;VS218;abbreviation
 E01CA;VS219;abbreviation
 E01CB;VS220;abbreviation
 E01CC;VS221;abbreviation
 E01CD;VS222;abbreviation
 E01CE;VS223;abbreviation
 E01CF;VS224;abbreviation
 E01D0;VS225;abbreviation
 E01D1;VS226;abbreviation
 E01D2;VS227;abbreviation
 E01D3;VS228;abbreviation
 E01D4;VS229;abbreviation
 E01D5;VS230;abbreviation
 E01D6;VS231;abbreviation
 E01D7;VS232;abbreviation
 E01D8;VS233;abbreviation
 E01D9;VS234;abbreviation
 E01DA;VS235;abbreviation
 E01DB;VS236;abbreviation
 E01DC;VS237;abbreviation
 E01DD;VS238;abbreviation
 E01DE;VS239;abbreviation
 E01DF;VS240;abbreviation
 E01E0;VS241;abbreviation
 E01E1;VS242;abbreviation
 E01E2;VS243;abbreviation
 E01E3;VS244;abbreviation
 E01E4;VS245;abbreviation
 E01E5;VS246;abbreviation
 E01E6;VS247;abbreviation
 E01E7;VS248;abbreviation
 E01E8;VS249;abbreviation
 E01E9;VS250;abbreviation
 E01EA;VS251;abbreviation
 E01EB;VS252;abbreviation
 E01EC;VS253;abbreviation
 E01ED;VS254;abbreviation
 E01EE;VS255;abbreviation
 E01EF;VS256;abbreviation
 
 # EOF
 
 */
