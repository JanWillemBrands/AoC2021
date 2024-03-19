//
//  Scanner.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

// TODO: explicit EOF notation
// TODO: explicit matching rules e.g. -\- any, regex101 not preceed or follow <<!  !>>
// TODO: change to character-level scanner
// let s = CharacterSet.alphanumerics.union(CharacterSet.capitalizedLetters)

import Foundation

// input is the string that's being scanned and parsed
var input: String = ""

// index is right before the first character of the current token
var index_Ci: String.Index = input.startIndex

var token = Token()

typealias TokenPattern = (pattern: String, regular: Bool, muted: Bool)
var tokenPatterns: [String:TokenPattern] = [:]

func initScanner(fromString inputString: String, patterns: [String:TokenPattern]) {
    tokenPatterns = patterns
    input = inputString
    index_Ci(to: input.startIndex)
}

func initScanner(fromFile inputFileURL: URL, patterns: [String:TokenPattern]) {
    guard let inputFileContent = try? String(contentsOf: inputFileURL, encoding: .utf8) else {
        print("error: could not read from \(inputFileURL.absoluteString)")
        exit(1)
    }
    tokenPatterns = patterns
    input = inputFileContent
    index_Ci(to: input.startIndex)
}

// TODO: future defs
//let whitespace  = /\s+/                         // any regex whitespace
//let singleLine  = /\/\/.*/                      // anything on the same line after //
//let multiLine   = /(?s)\/\*.*?\*\//             // anything on multiple lines between /* and */
//
//let identifier  = /[\p{L}\p{N}\p{Pc}]+/         // one or more letters or numbers or punctuation in any script
//let i           = /a-zA-Z[_a-zA-Z0-9]*/         // a letters followed by zero or more letters or digits or underscores
//
//let regex       = /\/[^\/]*\//                  // anything between /, no escape for //
//let action      = /@[^@]*@/                     // anything between @, no escape for /@
//
//let keyword     = /"(\"|[^"]+?)*\"/
//let k           = /"[^"\\]*(?:\\.[^"\\]*)*"/    // anything between ", with escapes for /" and //
//
//let testInput   = /¶(¶|[^¶])+/


// handwritten parser: BE CAREFUL!
let handwrittenTokenPatterns: [String:TokenPattern] = [
    "singleLine":   (#"//.*"#,                  true,  true),
    "whitespace":   (#"\s+"#,                   true,  true),
    "multiLine":    (#"(?s)(/\*).*?(\*/)"#,     true,  true),
    "literal":      (#""(\\"|[^"]+?)*""#,       true,  false),
    "message":      (#"¶(\\\¶|[^¶])+"#,         true,  false),
    "regular":      (#"'(\\'|[^']+?)*'"#,       true,  false),
    "action":       (#"@(\\@|[^@]+?)*@"#,       true,  false),
    "name":         (#"[\p{L}\p{N}\p{Pc}]+"#,   true,  false),
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
    var range: Range<String.Index> = input.startIndex ..< input.startIndex
    var type = ""
    var image = ""
    var stripped: String {
        switch type {
        case "literal":
            return String(image.dropFirst().dropLast())
                .escapesRemoved
        case "regular":
            return image.dropFirst().dropLast()
                .replacingOccurrences(of: "\\'", with: "'")
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

func index_Ci(to i: String.Index) {
    index_Ci = i
    token.range = index_Ci ..< index_Ci
    token.image = ""
    token.type = ""
}

func next() {
    var remainder = token.range.upperBound ..< input.endIndex // index_Ci is set to token.range.lowerBound
    if remainder.isEmpty {
        trace("end of input reached")
        index_Ci = input.endIndex
        token.range = index_Ci ..< index_Ci
        token.image = ""
        token.type = ""
        return
    }
    var longestMatchIsMuted = true
    var longestMatchType = ""
    var longestMatch = remainder.lowerBound ..< remainder.lowerBound
    while longestMatchIsMuted {
        longestMatch = remainder.lowerBound ..< remainder.lowerBound
        for pattern in tokenPatterns {
            var m: Range<String.Index>?
            if pattern.value.regular {
                m = input.range(of: pattern.value.pattern, options: [.regularExpression, .anchored], range: remainder)
            } else {
                m = input.range(of: pattern.value.pattern, options: [.anchored], range: remainder)
            }
            if let match = m {
                if match.upperBound > longestMatch.upperBound {
                    longestMatch = match
                    longestMatchIsMuted = pattern.value.muted
                    longestMatchType = pattern.key
                } else if match.upperBound == longestMatch.upperBound && !pattern.value.regular {
                    longestMatch = match
                    longestMatchIsMuted = pattern.value.muted
                    longestMatchType = pattern.key
                }
            }
        }
        if longestMatch.isEmpty {
            if longestMatch.upperBound < remainder.upperBound {
                print("error: input does not match any symbol in the grammar")
                let lineRange = input.lineRange(for: longestMatch)
                print(String(input[lineRange]).escapesAdded)
                let before = lineRange.lowerBound ..< longestMatch.lowerBound
                for _ in 0 ..< input[before].count {
                    print(" ", terminator: "")
                }
                print("^~~~~~~~")
                exit(2)
            } else {
                trace("end of input reached")
            }
            token.range = longestMatch
            token.image = ""
            token.type = ""
            index_Ci = token.range.lowerBound
            return
        }
        remainder = longestMatch.upperBound..<input.endIndex
    }
    token.range = longestMatch
    token.image = String(input[token.range])
    token.type = longestMatchType
    index_Ci = token.range.lowerBound
    trace("next token: \"\(token.image.escapesAdded)\" range: \(token.range.shortDescription)")
}

func expect(_ expectedTokens: Set<String>) {
    trace("expect", token.type, "to be in", expectedTokens)
    if !expectedTokens.contains(token.type) {
        print("error: found \"\(token.type.escapesAdded)\" but expected one of \(expectedTokens)")
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
