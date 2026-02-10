//
//  Scanner.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

// TODO: explicit matching rules e.g. -\- any, regex101 not preceed or follow <<!  !>>, or exclude "\" not preceded "-/-" not followed "-\-"
// TODO: change to character-level scanner
// let s = CharacterSet.alphanumerics.union(CharacterSet.capitalizedLetters)

import Foundation
import RegexBuilder

enum ScannerFailure: Error { 
    case charactersDoNotMatchAnySymbol(position: String.Index, input: String)
    case couldNotReadFile 
}

var tokens: [Token] = []

// the index of the current active token
var currentIndex = 0

public var token: Token {
    tokens[currentIndex]
}

public func initScanner(fromString inputString: String, patterns: [String:TokenPattern]) throws {
    input = inputString
    tokenPatterns = patterns
    tokens = []
    try scanTokens()
    currentIndex = 0
}

public typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)
var tokenPatterns = apusTerminals

let apusTerminals: [String:TokenPattern] = [
    "whitespace":   (#"\s+"#,                   /\s+/,                              false, true),
    "linecomment":  (#"//.*"#,                  /\/\/.*/,                           false, true),
    "blockcomment": (#"/\*(?s).*?\*/"#,         /\/\*(?s).*?\*\//,                  false, true),
    "identifier":   (#"[\p{L}\p{N}\p{Pc}]+"#,   /\p{XID_Start}\p{XID_Continue}*/,   false, false),
    "literal":      (#""(?:[^"\\]|\\.)*""#,     /\"(?:[^\"\\]|\\.)*\"/,             false, false),
    "epsilon":      (#"[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]"#,       /[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]/,                  false, false),
    "regex":        (#"/(?:[^\/\\]|\\.)+/"#,    /\/(?:[^\/\\]|\\.)+\//,             false, false),
    "action":       (#"@(?:[^@\\]|\\.)*@"#,     /@(?:[^@\\]|\\.)*@/,                false, false),
    "message":      (#"\^\^\^(?:(?s).*?)(?=\^\^\^|$)"#,
                                                /\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,    false, false),
    ".":            (".",                       Regex { "." },                      true,  false),
    ";":            (";",                       Regex { ";" },                      true,  false),
    ":":            (":",                       Regex { ":" },                      true,  false),
    "=":            ("=",                       Regex { "=" },                      true,  false),
    "|":            ("|",                       Regex { "|" },                      true,  false),
    "(":            ("(",                       Regex { "(" },                      true,  false),
    ")":            (")",                       Regex { ")" },                      true,  false),
    "[":            ("[",                       Regex { "[" },                      true,  false),
    "]":            ("]",                       Regex { "]" },                      true,  false),
    "{":            ("{",                       Regex { "{" },                      true,  false),
    "}":            ("}",                       Regex { "}" },                      true,  false),
    "<":            ("<",                       Regex { "<" },                      true,  false),
    ">":            (">",                       Regex { ">" },                      true,  false),
    "?":            ("?",                       Regex { "?" },                      true,  false),
    "*":            ("*",                       Regex { "*" },                      true,  false),
    "+":            ("+",                       Regex { "+" },                      true,  false),
//    "nonASCII":     (#"[^\p{ASCII}]"#,          /[^\p{ASCII}]/,                     false,  false),
//    ")?":           (")?",                      Regex { ")?" },                     true,  false),
//    ")*":           (")*",                      Regex { ")*" },                     true,  false),
//    ")+":           (")+",                      Regex { ")+" },                     true,  false),
]

    
public final class Token: CustomStringConvertible {
    public var image: Substring
    public var kind: String
    public var dual: Token?                            // multiple regex matches of equal length create a 'Schrödinger' token linked list
    public init(image: Substring, kind: String) {
        self.image = image
        self.kind = kind
    }
    public var stripped: String {
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
    public var description: String {
        if let dual {
            return kind + " " + dual.description
        }
        return kind
    }
}

func _scanTokens() throws {
    var matchStart = input.startIndex
    while matchStart != input.endIndex {
        var skip = true
        var matchEnd = matchStart
        var matchedToken: Token?
        for (kind, pattern) in tokenPatterns {
            if let match = input[matchStart...].prefixMatch(of: pattern.regex) {
                // longest match wins, keyword wins if equal length
                if match.0.endIndex > matchEnd || (match.0.endIndex == matchEnd && pattern.isKeyword) {
                    matchEnd = match.0.endIndex
                    matchedToken = Token(image: match.0, kind: kind)
                    skip = pattern.isSkip
                }
            }
        }
        if let matchedToken {
            if !skip {
                tokens.append(matchedToken)
            }
            matchStart = matchEnd
        } else {
            try scanError(position: matchStart)
        }
    }
    // append EndOfString token
    // TODO: re-implement tokenKind as an Int, with 0 as EndOfString
    tokens.append(Token(image: "$", kind: "$"))
}

func scanTokens() throws {
    var matchStart = input.startIndex
    while matchStart != input.endIndex {
        var skip = true
        var matchEnd = matchStart
        var headMatch: Token?                // stores the most common match
        var tailMatch: Token?                // tracks any subsequent matches for Scrödinger tokens
        for (kind, pattern) in tokenPatterns {
            if let match = input[matchStart...].prefixMatch(of: pattern.regex) {
                if match.0.endIndex > matchEnd {
                    // longest match always wins
                    matchEnd = match.0.endIndex
                    headMatch = Token(image: match.0, kind: kind)
                    tailMatch = headMatch
                    skip = pattern.isSkip
                } else if match.0.endIndex == matchEnd {
                    if pattern.isKeyword {
                        // insert the new match at the front of the list to optimize parsing of keywords
                        let oldHead = headMatch
                        headMatch = Token(image: match.0, kind: kind)
                        headMatch?.dual = oldHead
                    } else {
                        // append the new match to the end of the list
                        tailMatch?.dual = Token(image: match.0, kind: kind)
                        tailMatch = tailMatch?.dual
                    }
                    #if DEBUG
                    trace("Schrödinger strikes again! \(headMatch!)")
                    #endif
                }
            }
        }
        if let headMatch {
            if !skip || headMatch.dual != nil {     // add non-skip or Schrödinger tokens
                tokens.append(headMatch)
            }
            matchStart = matchEnd
        } else {
            try scanError(position: matchStart)
        }
    }
    // append EndOfString token
    // TODO: re-implement tokenKind as an Int, with 0 as EndOfString
    tokens.append(Token(image: "$", kind: "$"))
}

public func next() {
    currentIndex += 1
    #if DEBUG
    trace("next", token.image, token.kind)
    #endif
}

// TODO: use https://developer.apple.com/documentation/foundation/nsregularexpression/1408386-escapedpattern

func scanError(position: String.Index) throws -> Never {
    print("scan error: input characters do not match any symbol in the grammar")
    let lineRange = input.lineRange(for: position ..< input.index(after: position))
    print(input[lineRange], terminator: "")
    let before = lineRange.lowerBound ..< position
    for _ in 0 ..< input[before].count {
        print(" ", terminator: "")
    }
    print("^~~~~~~~")
    throw ScannerFailure.charactersDoNotMatchAnySymbol(position: position, input: input)
}



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
// recommended ID syntax following https://unicode.org/reports/tr31/
let identifierRegex = Regex {
    // TODO: why are there #'s here?
    /\p{XID_Start}/
    ZeroOrMore {
        #/\p{XID_Continue}/#
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
//    "^ ^ ^"
    /\^\^\^/
    ZeroOrMore {
        ChoiceOf {
            // any character that is not a '^ ^ ^' or a backward slash '\'
            CharacterClass(.anyOf("^\\").inverted)
            // a backward slash '\' followed by single character, to escape '^ ^ ^' or '\', but catches more than legal escapes
            /\\./
        }
    }
}
