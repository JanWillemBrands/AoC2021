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
    "message":      (#"¶(?:[^¶\\]|\\.)*"#,      /¶(?:[^¶\\]|\\.)*/,                 false, false),
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
    "if":           ("if",                      try! Regex("if"),                   true,  false),
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
        var matchEnd = matchStart
        var token: Token?
        for (kind, pattern) in tokenPatterns {
            if let match = input[matchStart...].prefixMatch(of: pattern.regex) {
                if match.0.endIndex > matchEnd || match.0.endIndex == matchEnd && pattern.isKeyword {
                    matchEnd = match.0.endIndex
                    token = Token(image: match.0, kind: kind)
                }
            }
        }
        if let token {
            tokens.append(token)
            matchStart = matchEnd
        } else {
            print("ERROR illegal characters", input[matchStart...])
            matchStart = input.endIndex
        }
    }
}

func next() {
    currentIndex += 1
    while currentIndex < tokens.count, let t = tokenPatterns[tokens[currentIndex].kind], t.isSkip {
        currentIndex += 1
    }
    if currentIndex >= tokens.count {
        print("end of file reached")
    } else {
        print("next", token.image, token.kind)
    }
}

var tokens: [Token] = []

// the index of the current Token
var currentIndex = -1

var token: Token {
    if currentIndex < 0 {
        return Token(image: input[...input.startIndex], kind: "")
    } else if currentIndex >= tokens.count {
        return Token(image: input[input.endIndex...], kind: "")
    } else {
        return tokens[currentIndex]
    }
}

// the scanner uses regexes to identify tokens and is iniialized to the apus language

func initScanner(fromString inputString: String, patterns: [String:TokenPattern]) {
    tokenPatterns = patterns
    input = inputString
    tokens = []
    scanTokens()
    currentIndex = -1
    next()
}

func initScanner(fromFile inputFileURL: URL, patterns: [String:TokenPattern]) {
    guard let inputFileContent = try? String(contentsOf: inputFileURL, encoding: .utf8) else {
        print("error: could not read from \(inputFileURL.absoluteString)")
        exit(1)
    }
    tokenPatterns = patterns
    input = inputFileContent
    tokens = []
    scanTokens()
    currentIndex = -1
    next()
}

// TODO: use https://developer.apple.com/documentation/foundation/nsregularexpression/1408386-escapedpattern

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
    }
}

func reportError(range: Range<String.Index>) {
    print("error: input does not match any symbol in the grammar")
    let lineRange = input.lineRange(for: token.image.startIndex ..< token.image.endIndex)
    print(String(input[lineRange]).escapesAdded)
    let before = lineRange.lowerBound ..< token.image.startIndex
    for _ in 0 ..< input[before].count {
        print(" ", terminator: "")
    }
    print("^~~~~~~~")
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
    #/\p{XID_Start}/#
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

// the programmer name of each token kind in the apus language
//let _fullStop = 0
//let _semicolon = 1
//let _colon = 2
//let _equalsSign = 3
//let _verticalLine = 4
//let _leftParenthesis = 5
//let _rightParenthesis = 6
//let _leftSquareBracket = 7
//let _rightSquareBracket = 8
//let _leftCurlyBracket = 9
//let _rightCurlyBracket = 10
//let _lessThanSign = 11
//let _greaterThanSign = 12
//let _rightParenthesisQuestionMark = 13
//let _rightParenthesisAsterisk = 14
//let _rightParenthesisPlusSign = 15
//let _whitespace = 16
//let _linecomment = 17
//let _blockcomment = 18
//let _identifier = 19
//let _literal = 20
//let _regex = 21
//let _action = 22
//let _message = 23


