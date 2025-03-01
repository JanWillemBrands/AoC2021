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

enum ScannerFailure: Error { case charactersDoNotMatchAnySymbol, couldNotReadFile }

class Scanner {
    var input: String
    var tokens: [Token]
    var tokenPatterns: [String:TokenPattern]
    
    init(input: String, tokenPatterns: [String:TokenPattern]) {
        self.input = input
        self.tokenPatterns = tokenPatterns
        self.tokens = []
    }
    
    init(fromString inputString: String, patterns: [String:TokenPattern]) {
        tokenPatterns = patterns
        input = inputString
        tokens = []
        scanTokens()
        index = 0
//        next()
    }

    init(fromFile inputFileURL: URL, patterns: [String:TokenPattern]) throws {
        guard let inputFileContent = try? String(contentsOf: inputFileURL, encoding: .utf8) else {
            print("error: could not read from \(inputFileURL.absoluteString)")
            throw ScannerFailure.couldNotReadFile
        }
        tokenPatterns = patterns
        input = inputFileContent
        tokens = []
        scanTokens()
        index = 0
//        next()
    }

}

// input is the string that's being scanned and parsed
var input: String = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)
var tokenPatterns = apusTerminals

let apusTerminals: [String:TokenPattern] = [
    "whitespace":   (#"\s+"#,                   /\s+/,                              false, true),
    "linecomment":  (#"//.*"#,                  /\/\/.*/,                           false, true),
    "blockcomment": (#"/\*(?s).*?\*/"#,         /\/\*(?s).*?\*\//,                  false, true),
    "identifier":   (#"[\p{L}\p{N}\p{Pc}]+"#,   /\p{XID_Start}\p{XID_Continue}*/,   false, false),
    "literal":      (#""(?:[^"\\]|\\.)*""#,     /\"(?:[^\"\\]|\\.)*\"/,             false, false),
    "regex":        (#"/(?:[^\/\\]|\\.)*/"#,    /\/(?:[^\/\\]|\\.)*\//,             false, false),
    "action":       (#"@(?:[^@\\]|\\.)*@"#,     /@(?:[^@\\]|\\.)*@/,                false, false),
    "message":      (#"¶(?:/(?:[^/\\]|\\.)*/|[^¶/]*)*"#,      /¶(?:\/(?:[^\/\\]|\\.)*\/|[^¶\/]*)*/,                 false, false),
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
    ")?":           (")?",                      Regex { ")?" },                     true,  false),
    ")*":           (")*",                      Regex { ")*" },                     true,  false),
    ")+":           (")+",                      Regex { ")+" },                     true,  false),
]

struct Token {
    var image: Substring
    var kind: String
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
            return image.dropFirst()
                .replacingOccurrences(of: "\\¶", with: "¶")
        default:
            return String(image)
        }
    }
    var range: Range<String.Index> {
        self.image.startIndex ..< self.image.endIndex
    }
}

func scanTokens() {
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
            scanError(position: matchStart)
        }
    }
    // append EndOfString token
    // TODO: re-implement tokenKind as an Int, with 0 as EndOfString
//    tokens.append(Token(image: "", kind: "$"))
    tokens.append(Token(image: "$", kind: "$"))
}

func next() {
    index += 1
    trace("next", token.image, token.kind)

    // TODO: remove isSkip tokens from the list
//    while _currentIndex < tokens.count, let t = tokenPatterns[tokens[_currentIndex].kind], t.isSkip {
//        _currentIndex += 1
//    }
//    // TODO: restrict currentIndex to tokens.range
//    if _currentIndex < tokens.count {
//        trace("next", token.image, token.kind)
//    } else {
//        print("end of file reached")
//    }
}

var tokens: [Token] = []

// the index of the current active token
var index = 0

var token: Token {
    tokens[index]
//    if _currentIndex < 0 {
//        return Token(image: input[...input.startIndex], kind: "")
//    } else if _currentIndex >= tokens.count {
//        return Token(image: input[input.endIndex...], kind: "")
//    } else {
//        return tokens[_currentIndex]
//    }
}

// the scanner uses regexes to identify tokens and is initialized to the apus language

func initScanner(fromString inputString: String, patterns: [String:TokenPattern]) {
    input = inputString
    tokenPatterns = patterns
    tokens = []
    scanTokens()
    index = 0
}

func initScanner(fromFile inputFileURL: URL, patterns: [String:TokenPattern]) {
    guard let inputFileContent = try? String(contentsOf: inputFileURL, encoding: .utf8) else {
        print("error: could not read from \(inputFileURL.absoluteString)")
        exit(2)
    }
    input = inputFileContent
    tokenPatterns = patterns
    tokens = []
    scanTokens()
    index = 0
}

// TODO: use https://developer.apple.com/documentation/foundation/nsregularexpression/1408386-escapedpattern

func scanError(position: String.Index) {
    print("error: input characters do not match any symbol in the grammar")
    let lineRange = input.lineRange(for: position ..< input.index(after: position))
    print(input[lineRange], terminator: "")
    let before = lineRange.lowerBound ..< position
    for _ in 0 ..< input[before].count {
        print(" ", terminator: "")
    }
    print("^~~~~~~~")
    exit(11)
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
    "¶"
    ZeroOrMore {
        ChoiceOf {
            // any character that is not a '¶' or a backward slash '\'
            CharacterClass(.anyOf("¶\\").inverted)
            // a backward slash '\' followed by single character, to escape '¶' or '\', but catches more than legal escapes
            /\\./
        }
    }
}
