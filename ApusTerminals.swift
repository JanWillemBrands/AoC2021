//
//  ApusTerminals.swift
//  Advent
//
//  Created by Johannes Brands on 2026.03.11.
//

import RegexBuilder

public let apusTerminals: [String:TokenPattern] = [
    "whitespace":   (#"\s+"#,                   /\s+/,                              false, true),
    "linecomment":  (#"//.*"#,                  /\/\/.*/,                           false, true),
    "blockcomment": (#"/\*(?s).*?\*/"#,         /\/\*(?s).*?\*\//,                  false, true),
    "identifier":   (#"[\p{L}\p{N}\p{Pc}]+"#,   /\p{XID_Start}\p{XID_Continue}*/,   false, false),
    "literal":      (#""(?:[^"\\]|\\.)*""#,     /\"(?:[^\"\\]|\\.)*\"/,             false, false),
    "regex":        (#"/(?:[^\/\\]|\\.)+/"#,    /\/(?:[^\/\\]|\\.)+\//,             false, false),
    "action":       (#"@(?:[^@\\]|\\.)*@"#,     /@(?:[^@\\]|\\.)*@/,                false, false),
    "message":      (#"\^\^\^(?:(?s).*?)(?=\^\^\^|$)"#,
                                                /\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,    false, false),
    "epsilon":      (#"[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]"#,       /[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]/,                   true,  false),
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

// the programmer name of each token kind in the apus language
let _endOfString                  = 0
let _fullStop                     = 1
let _semicolon                    = 2
let _colon                        = 3
let _equalsSign                   = 4
let _verticalLine                 = 5
let _leftParenthesis              = 6
let _rightParenthesis             = 7
let _leftSquareBracket            = 8
let _rightSquareBracket           = 9
let _leftCurlyBracket             = 10
let _rightCurlyBracket            = 11
let _lessThanSign                 = 12
let _greaterThanSign              = 13
let _questionMark                 = 14
let _asterisk                     = 15
let _plusSign                     = 16
let _whitespace                   = 17
let _linecomment                  = 18
let _blockcomment                 = 19
let _identifier                   = 20
let _literal                      = 21
let _regex                        = 22
let _action                       = 23
let _message                      = 24


enum TokenKind: Int, CustomStringConvertible {
    case endOfString, fullStop, semicolon, colon, equalsSign, verticalLine, leftParenthesis, rightParenthesis, leftSquareBracket, rightSquareBracket, leftCurlyBracket, rightCurlyBracket, lessThanSign, greaterThanSign, questionMark, asterisk, plusSign, whitespace, linecomment, blockcomment, identifier, literal, regex, action, message
    
    var description: String {
        ["endOfString", ".", ";", ":", "=", "|", "(", ")", "[", "]", "{", "}", "<", ">", "?", "*", "+", "whitespace", "linecomment", "blockcomment", "identifier", "literal", "regex", "action", "message"][self.rawValue]
    }
}

typealias TokenRegex = (kind: TokenKind, regex: Regex<Substring>)

let tokenRegexes: [TokenRegex] = [
    (.fullStop,                     Regex { "." } ),
    (.semicolon,                    Regex { ";" } ),
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
