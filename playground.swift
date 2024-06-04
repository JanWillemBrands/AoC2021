
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


import Foundation
import RegexBuilder

enum TokenKind: Int, CustomStringConvertible, CaseIterable {
    case fullStop, semicolon, colon, equalsSign, verticalLine, leftParenthesis, rightParenthesis, leftSquareBracket, rightSquareBracket, leftCurlyBracket, rightCurlyBracket, lessThanSign, greaterThanSign, rightParenthesisQuestionMark, rightParenthesisAsterisk, rightParenthesisPlusSign, whitespace, linecomment, blockcomment, identifier, literal, regex, action, message
    var description: String {
        [".", ";", ":", "=", "|", "(", ")", "[", "]", "{", "}", "<", ">", ")?", ")*", ")+", "whitespace", "linecomment", "blockcomment", "identifier", "literal", "regex", "action", "message"][self.rawValue]
    }
}

let skipTokens: Set<TokenKind> = [.whitespace, .lineComment, .blockComment, .action]

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
            return image.dropFirst()
                .replacingOccurrences(of: "\\¶", with: "¶")
        default:
            return String(image)
        }
    }
}

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
            CharacterClass(.anyOf("\"\\").inverted)  // any character that is not a '"' or a backward slash '\'
            /\\./                                   // a backward slash '\' followed by single character, to escape '"' or '\', but catches more than legal escapes
        }
    }
    "\""
}
let regexRegex = Regex {
    "/"
    ZeroOrMore {
        ChoiceOf {
            CharacterClass(.anyOf("/\\").inverted)  // any character that is not a forward slash '/' or a backward slash '\'
            /\\./                                   // a backward slash '\' followed by single character, to escape '/' or '\', but catches more than legal escapes
        }
    }
    "/"
}
let actionRegex = Regex {
    "@"
    ZeroOrMore {
        ChoiceOf {
            CharacterClass(.anyOf("@\\").inverted)  // any character that is not a '@' or a backward slash '\'
            /\\./                                   // a backward slash '\' followed by single character, to escape '@' or '\', but catches more than legal escapes
        }
    }
    "@"
}
let messageRegex = Regex {
    "¶"
    ZeroOrMore {
        ChoiceOf {
            CharacterClass(.anyOf("¶\\").inverted)  // any character that is not a '¶' or a backward slash '\'
            /\\./                                   // a backward slash '\' followed by single character, to escape '¶' or '\', but catches more than legal escapes
        }
    }
}

let text = #"""
whitespace   : /\s+/ .  // some characters
lineComment  : /\/\/.*/ .
blockComment : /\/\*(?s).*?\*\// .
if 1_f-fy ***
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
    (.whitespace,                   /\s+/ ),
    (.linecomment,                  /\/\/.*/ ),
    (.blockcomment,                 /\/\*(?s).*?\*\// ),
    (.identifier,                   /\p{XID_Start}\p{XID_Continue}*/ ),
    (.literal,                      /\"(?:[^\"\\]|\\.)*\"/ ),
    (.regex,                        /\/(?:[^\/\\]|\\.)*\// ),
    (.action,                       /@(?:[^@\\]|\\.)*@/ ),
    (.message,                      /¶(?:[^¶\\]|\\.)*/ ),
]

var tokens: [Token] = []
var tokenIndex = 0
var token: Token


func scanTokens() {
    var matchStart = text.startIndex
    while matchStart != text.endIndex {
        var matchEnd = matchStart
        var token: Token?
        for tr in tokenRegexes {
            if let match = text[matchStart ..< text.endIndex].prefixMatch(of: tr.regex) {
                if match.0.endIndex > matchEnd {
                    matchEnd = match.0.endIndex
                    token = Token(image: match.0, kind: tr.kind)
                }
            }
        }
        if let token {
            tokens.append(token)
            matchStart = matchEnd
        } else {
            print("error")
            matchStart = text.endIndex
        }
    }
}

func next() {
    while tokenIndex < tokens.count && skipTokens.contains(tokens[tokenIndex].kind) {
        tokenIndex += 1
    }
    if tokenIndex == tokens.count {
        print("end of file reached")
    } else {
        token = tokens[tokenIndex]
        tokenIndex += 1
        print("next", token.image, token.kind)
    }
}
