// the programmer name of each token kind in the apus language
//let _endOfString                  = 0
//let _fullStop                     = 1
//let _semicolon                    = 2
//let _colon                        = 3
//let _equalsSign                   = 4
//let _verticalLine                 = 5
//let _leftParenthesis              = 6
//let _rightParenthesis             = 7
//let _leftSquareBracket            = 8
//let _rightSquareBracket           = 9
//let _leftCurlyBracket             = 10
//let _rightCurlyBracket            = 11
//let _lessThanSign                 = 12
//let _greaterThanSign              = 13
//let _questionMark                 = 14
//let _asterisk                     = 15
//let _plusSign                     = 16
//let _whitespace                   = 17
//let _linecomment                  = 18
//let _blockcomment                 = 19
//let _identifier                   = 20
//let _literal                      = 21
//let _regex                        = 22
//let _action                       = 23
//let _message                      = 24


import Foundation
import RegexBuilder

enum TokenKind: CustomStringConvertible {
    case endOfString, fullStop, semicolon, colon, equalsSign, verticalLine, leftParenthesis, rightParenthesis, leftSquareBracket, rightSquareBracket, leftCurlyBracket, rightCurlyBracket, lessThanSign, greaterThanSign, questionMark, asterisk, plusSign, whitespace, linecomment, blockcomment, identifier, literal, regex, action, message
    
    var description: String {
        ["endOfString", ".", ";", ":", "=", "|", "(", ")", "[", "]", "{", "}", "<", ">", "?", "*", "+", "whitespace", "linecomment", "blockcomment", "identifier", "literal", "regex", "action", "message"][self.rawValue]
    }
}

let skipTokens: Set<TokenKind> = [.whitespace, .linecomment, .blockcomment, .action]

struct Token {
    var image: Substring
    var kind: TokenKind
    var stripped: String {
        switch kind {
        case .literal:
            return String(image.dropFirst().dropLast())
        case .regex:
            return String(image.dropFirst().dropLast())
        case .action:
            return image.dropFirst().dropLast()
                .replacingOccurrences(of: "\\@", with: "@")
        case .message:
            return image.dropFirst(3)
        default:
            return String(image)
        }
    }
}

let whitespaceRegex = Regex {
    OneOrMore { .whitespace }
}
let linecommentRegex = Regex {
    "//"
    ZeroOrMore { .anyNonNewline }
}
let blockcommentRegex = Regex {
    "/*"
    ZeroOrMore(.reluctant) { .any }
    "*/"
}
// recommended ID syntax following https://unicode.org/reports/tr31/
let identifierRegex = Regex {
    /\p{XID_Start}/
    ZeroOrMore { /\p{XID_Continue}/ }
}
let literalRegex = Regex {
    "\""
    ZeroOrMore {
        ChoiceOf {
            CharacterClass(.anyOf("\"\\").inverted)
            // any character that is not a '"' or a backward slash '\'
            /\\./
            // a backward slash '\' followed by single character, to escape '"' or '\', but catches more than legal escapes
        }
    }
    "\""
}
let regexRegex = Regex {
    "/"
    ZeroOrMore {
        ChoiceOf {
            CharacterClass(.anyOf("/\\").inverted)
            // any character that is not a forward slash '/' or a backward slash '\'
            /\\./
            // a backward slash '\' followed by single character, to escape '/' or '\', but catches more than legal escapes
        }
    }
    "/"
}
let actionRegex = Regex {
    "@"
    ZeroOrMore {
        ChoiceOf {
            CharacterClass(.anyOf("@\\").inverted)
            // any character that is not a '@' or a backward slash '\'
            /\\./
            // a backward slash '\' followed by single character, to escape '@' or '\', but catches more than legal escapes
        }
    }
    "@"
}
let messageRegex = Regex {
    /\/^\^\^/
    ZeroOrMore {
        ChoiceOf {
            CharacterClass(.anyOf("^\\").inverted)
            // any character that is not a '^' or a backward slash '\'
            /\\./
            // a backward slash '\' followed by single character, to escape '^ ^ ^' or '\', but catches more than legal escapes
        }
    }
}

let input = #"""
whitespace   : /\s+/ .  // some characters
lineComment  : /\/\/.*/ .
blockComment : /\/\*(?s).*?\*\// .
if iffy
"""#

typealias TokenRegex = (kind: TokenKind, regex: Regex<Substring>)

// an ordered list of regexes; when multiple matches of equal length, the first one wins
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
    (.rightParenthesisQuestionMark, Regex { ")?" } ),
    (.rightParenthesisAsterisk,     Regex { ")*" } ),
    (.rightParenthesisPlusSign,     Regex { ")+" } ),
    (.whitespace,                   whitespaceRegex ),
    (.linecomment,                  linecommentRegex ),
    (.blockcomment,                 blockcommentRegex ),
    (.identifier,                   identifierRegex ),
    (.literal,                      literalRegex ),
    (.regex,                        regexRegex ),
    (.action,                       actionRegex ),
    (.message,                      messageRegex ),
]

var tokens: [Token] = []
var tokenIndex = 0
var token: Token { tokens[tokenIndex] }

func scanTokens() {
    var matchStart = input.startIndex
    while matchStart != input.endIndex {
        var matchEnd = matchStart
        var matchToken: Token?
        for tr in tokenRegexes {
            if let match = input[matchStart ..< input.endIndex].prefixMatch(of: tr.regex) {
                if match.0.endIndex > matchEnd {
                    matchEnd = match.0.endIndex
                    matchToken = Token(image: match.0, kind: tr.kind)
                }
            }
        }
        if let matchToken {
            if !skipTokens.contains(matchToken.kind) {
                tokens.append(matchToken)
            }
            matchStart = matchEnd
        } else {
            print("no match possible")
            matchStart = input.endIndex
        }
    }
    tokens.append(Token(image: "", kind: .endOfString))
}

scanTokens()
for i in 0..<tokens.count {
    print(tokens[i])
}
