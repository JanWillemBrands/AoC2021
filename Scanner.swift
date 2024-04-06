//
//  Scanner.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

// TODO: explicit EOF notation
// TODO: explicit matching rules e.g. -\- any, regex101 not preceed or follow <<!  !>>, or exclude "\" not preceded "-/-" not followed "-\-"
// TODO: change to character-level scanner
// let s = CharacterSet.alphanumerics.union(CharacterSet.capitalizedLetters)

import Foundation
import RegexBuilder

// input is the string that's being scanned and parsed
var input: String = ""

//var token = tokens[tokenIndex]
var token: Token {
    tokens[tokenIndex]
}

//var token = Token(range: input.startIndex ..< input.endIndex, type: "")

typealias TokenPattern = (pattern: String, regex: Bool, muted: Bool)
var tokenPatterns: [String:TokenPattern] = [:]

func initScanner(fromString inputString: String, patterns: [String:TokenPattern]) {
    tokenPatterns = patterns
    input = inputString
    currentIndex(to: input.startIndex)
    scanTokens(in: inputString)
}

func initScanner(fromFile inputFileURL: URL, patterns: [String:TokenPattern]) {
    guard let inputFileContent = try? String(contentsOf: inputFileURL, encoding: .utf8) else {
        print("error: could not read from \(inputFileURL.absoluteString)")
        exit(1)
    }
    tokenPatterns = patterns
    input = inputFileContent
    currentIndex(to: input.startIndex)
    scanTokens(in: inputFileContent)
}

// handwritten parser: BE CAREFUL!
let handwrittenTokenPatterns: [String:TokenPattern] = [
    "whitespace":   (#"\s+"#,                   true,  true),
    "singleLine":   (#"//.*"#,                  true,  true),
    "multiLine":    (#"/\*(?s).*?\*/"#,         true,  true),
    "literal":      (#""(?:[^"\\]|\\.)*""#,     true,  false),
    "message":      (#"¶(?:[^¶\\]|\\.)*"#,      true,  false),
    "regex":        (#"/(?:[^\/\\]|\\.)*/"#,    true,  false),
    "action":       (#"@(?:[^@\\]|\\.)*@"#,     true,  false),
    "identifier":   (#"[\p{L}\p{N}\p{Pc}]+"#,   true,  false),
    ".":            (".",                       false, false),
    ";":            (";",                       false, false),
    ":":            (":",                       false, false),
    "=":            ("=",                       false, false),
    "|":            ("|",                       false, false),
    "(":            ("(",                       false, false),
    ")":            (")",                       false, false),
    "[":            ("[",                       false, false),
    "]":            ("]",                       false, false),
    "{":            ("{",                       false, false),
    "}":            ("}",                       false, false),
    "<":            ("<",                       false, false),
    ">":            (">",                       false, false),
    ")?":           (")?",                      false, false),
    ")*":           (")*",                      false, false),
    ")+":           (")+",                      false, false),
]

struct Token {
    var range: Range<String.Index>
    var type: String
    var image: String {
        String(input[range])
    }
    var stripped: String {
        switch type {
        case "literal":
            return String(image.dropFirst().dropLast())
                .escapesRemoved
        case "regex":
            return image.dropFirst().dropLast()
                .replacingOccurrences(of: "\\/", with: "/")
        case "action":
            return image.dropFirst().dropLast()
                .replacingOccurrences(of: "\\@", with: "@")
        case "message":
            return image.dropFirst()
                .replacingOccurrences(of: "\\¶", with: "¶")
        default:
            return image
        }
    }
}

func currentIndex(to i: String.Index) {
    currentIndex = i
//    token.range = currentIndex ..< currentIndex
//    token.type = ""
}

func next() {
    while tokenIndex < tokens.count && silentTokens.contains(tokens[tokenIndex].type) {
        tokenIndex += 1
    }
    if tokenIndex == tokens.count {
        print("end of file reached")
    } else {
        tokenIndex += 1
        print("next", token.image)
    }
}

//func next() {
//    var remainder = token.range.upperBound ..< input.endIndex // index_Ci is set to token.range.lowerBound
//    if remainder.isEmpty {
//        trace("end of input reached")
//        currentIndex = input.endIndex
//        token.range = currentIndex ..< currentIndex
//        token.type = ""
//        return
//    }
//    var longestMatchIsMuted = true
//    var longestMatchType = ""
//    var longestMatch = remainder.lowerBound ..< remainder.lowerBound
//    while longestMatchIsMuted {
//        longestMatch = remainder.lowerBound ..< remainder.lowerBound
//        for pattern in tokenPatterns {
//            var m: Range<String.Index>?
//            if pattern.value.regex {
//                m = input.range(of: pattern.value.pattern, options: [.regularExpression, .anchored], range: remainder)
//            } else {
//                m = input.range(of: pattern.value.pattern, options: [.anchored], range: remainder)
//            }
//            if let match = m {
//                if match.upperBound > longestMatch.upperBound {
//                    longestMatch = match
//                    longestMatchIsMuted = pattern.value.muted
//                    longestMatchType = pattern.key
//                } else if match.upperBound == longestMatch.upperBound && !pattern.value.regex {
//                    longestMatch = match
//                    longestMatchIsMuted = pattern.value.muted
//                    longestMatchType = pattern.key
//                }
//            }
//        }
//        if longestMatch.isEmpty {
//            if longestMatch.upperBound < remainder.upperBound {
//                print("error: input does not match any symbol in the grammar")
//                let lineRange = input.lineRange(for: longestMatch)
//                print(String(input[lineRange]).escapesAdded)
//                let before = lineRange.lowerBound ..< longestMatch.lowerBound
//                for _ in 0 ..< input[before].count {
//                    print(" ", terminator: "")
//                }
//                print("^~~~~~~~")
//                exit(2)
//            } else {
//                trace("end of input reached")
//            }
//            token.range = longestMatch
//            token.type = ""
//            currentIndex = token.range.lowerBound
//            return
//        }
//        remainder = longestMatch.upperBound..<input.endIndex
//    }
//    token.range = longestMatch
//    token.type = longestMatchType
//    currentIndex = token.range.lowerBound
//    trace("next token: '\(token.image.escapesAdded)' range: \(token.range.shortDescription)")
//}

func expect(_ expectedTokens: Set<String>) {
    trace("expect", token.type, "to be in", expectedTokens)
    if !expectedTokens.contains(token.type) {
        print("error: found '\(token.type.escapesAdded)' but expected one of \(expectedTokens)")
        let lineRange = input.lineRange(for: token.range)
        print(input[lineRange], terminator: "")
        let before = lineRange.lowerBound ..< token.range.lowerBound
        for _ in 0 ..< input[before].count {
            print("~", terminator: "")
        }
        for _ in 0 ..< token.image.count {
            print("^", terminator: "")
        }
        print()
    }
    
}

let whitespaceRegex101 = /\s+/
let whitespaceRegex = Regex {
    OneOrMore {
        .whitespace
    }
}
// a single line Swift-style comment
let singleLineRegex101 = /\/\/.*/
let singleLineRegex = Regex {
    "//"
    ZeroOrMore {
        /./
    }
}
let t = /"/
// a non-nested C-style multiline comment
let multiLineRegex101 = /\/\*(?s).*?\*\//
let multiLineRegex = Regex {
    "/*"
    ZeroOrMore(.reluctant) {
        .any
    }
    "*/"
}
// recommended ID syntax following https://unicode.org/reports/tr31/
let identifierRegex101 = /\p{ID_Start}\p{ID_Continue}*/
let identifierRegex = Regex {
    #/\p{ID_Start}/#
    ZeroOrMore {
        #/\p{ID_Continue}/#
    }
}
let literalRegex101 = /\"(?:[^\"\\]|\\.)*\"/
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
let regexRegex101 = /\/(?:[^\/\\]|\\.)*\//
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
let actionRegex101 = /@(?:[^@\\]|\\.)*@/
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
let messageRegex101 = /¶(?:[^¶\\]|\\.)*/
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
let keywordRegex = Regex {
    ChoiceOf {
        "."
        ";"
        ":"
        "="
        "|"
        "("
        ")"
        "["
        "]"
        "{"
        "}"
        "<"
        ">"
        ")?"
        ")*"
        ")+"
    }
}


let tokenizer = Regex {
    ChoiceOf {
        Capture { whitespaceRegex101 }
        Capture { singleLineRegex101 }
        Capture { multiLineRegex101 }
        Capture { identifierRegex101 }
        Capture { literalRegex101 }
        Capture { regexRegex101 }
        Capture { actionRegex101 }
        Capture { messageRegex101 }
        Capture { keywordRegex }
    }
}

var tokens: [Token] = []
let silentTokens: Set<String> = ["whitespace", "singleline", "multiline", "action"]

enum TokenKind: String {
    case whitespace,
         singleline,
         multiline,
         identifier,
         literal,
         regex,
         action,
         message,
         //                              keyword,
         fullStop,
         semicolon,
         colon,
         equalsSign,
         verticalLine,
         leftParenthesis,
         rightParenthesis,
         leftSquareBracket,
         rightSquareBracket,
         leftCurlyBracket,
         rightCurlyBracket,
         lessThanSign,
         greaterThanSign,
         rightParenthesisQuestionMark,
         rightParenthesisAsterisk,
         rightParenthesisPlusSign
}
//let silentTokens: Set<TokenKind> = [.whitespace, .singleline, .multiline, .action]
//
//func scanTokensENUM() {
//    for m in input.matches(of: tokenizer) {
//        var token = Token(range: m.0.startIndex ..< m.0.endIndex, type: .whitespace)
//        if m.1 != nil { token.type = .whitespace }
//        else if m.2 != nil { token.type = .singleline }
//        else if m.3 != nil { token.type = .multiline }
//        else if m.4 != nil { token.type = .identifier }
//        else if m.5 != nil { token.type = .literal }
//        else if m.6 != nil { token.type = .regex }
//        else if m.7 != nil { token.type = .action }
//        else if m.8 != nil { token.type = .message }
//        else if m.9 != nil { token.type = .keyword }
//        tokens.append(token)
//    }
//    var index = input.startIndex
//    for t in tokens {
//        if index != t.range.lowerBound {
//            print("ERROR", input[index ..< t.range.upperBound])
//        }
//        index = t.range.upperBound
//    }
//    if index != text.endIndex {
//                print("EOF ERROR", input[index ..< input.endIndex])
//            }
//}

func scanTokens(in text: String) {
    var start = text.startIndex
    for m in text.matches(of: tokenizer) {
        if let s = m.1 {
            if start != s.startIndex { reportError(range: s.startIndex ..< s.endIndex) }
            start = s.startIndex
        } else if let s = m.2 {
        } else if let s = m.3 {
        } else if let s = m.4 {
            tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "identifier"))
        } else if let s = m.5 {
            tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "literal"))
        } else if let s = m.6 {
            tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "regex"))
        } else if let s = m.7 {
            tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "action"))
        } else if let s = m.8 {
            tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "testInput"))
        }
    }
}

func reportError(range: Range<String.Index>) {
    print("error: input does not match any symbol in the grammar")
    let lineRange = input.lineRange(for: token.range)
    print(String(input[lineRange]).escapesAdded)
    let before = lineRange.lowerBound ..< token.range.lowerBound
    for _ in 0 ..< input[before].count {
        print(" ", terminator: "")
    }
    print("^~~~~~~~")
}


