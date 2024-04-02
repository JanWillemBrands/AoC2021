//
//  NewScanner.swift
//  Advent
//
//  Created by Johannes Brands on 29/03/2024.
//

import Foundation
import RegexBuilder

let whitespaceRegex101 = /\s+/
let whitespaceRegex = Regex {
    OneOrMore {
        .whitespace
    }
}
let singleLineRegex101 = /\/\/.*/
let singleLineRegex = Regex {
    "//"
    ZeroOrMore {
        /./
    }
}
let multiLineRegex101 = /\/\*(?s).*?\*\//
let multiLineRegex = Regex {
    "/*"
    ZeroOrMore(.reluctant) {
        .any
    }
    "*/"
}
let identifierRegex101 = /[\p{L}\p{N}\p{Pc}]+/
let identifierRegex  = Regex {
    OneOrMore {
        // any letter, numeral or punctuation character in any script
        #/[\p{L}\p{N}\p{Pc}]/#
    }
}
let literalRegex101 = /\"(?:[^\"\\]|\\.)*\"/
let literalRegex = Regex {
    "\""
    ZeroOrMore {
        ChoiceOf {
            // any character that is not a '"' or a backward slash '\'
            CharacterClass(.anyOf("\"\\").inverted)
            // a backward slash '\' followed by an escaped character
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
            // a backward slash '\' followed by an escaped character
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
            // a backward slash '\' followed by single escaped character
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
            // a backward slash '\' followed by single escaped character
            /\\./
        }
    }
}



let text =
#"""
My /*comment*/ name /\/(?:[^\/\\]|\\.)*\//  is "taylor"     // some comment
and I am "\"quoted\"" years old @ some action!!! jw\@att.com @     /* some multiline
comment */
¶some \¶test\\ing
¶more testing
"""#

let tokenizer = Regex {
    ChoiceOf {
        whitespaceRegex101
        singleLineRegex101
        multiLineRegex101
        Capture { identifierRegex101 }
        Capture { literalRegex101 }
        Capture { regexRegex101 }
        Capture { actionRegex101 }
        Capture { messageRegex101 }
    }
}

var tokens: [Token] = []

func testNewScanner() {
    for m in text.matches(of: tokenizer) {
        if let s = m.1 { tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "identifier", image: String(s))) }
        if let s = m.2 { tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "literal", image: String(s))) }
        if let s = m.3 { tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "regex", image: String(s))) }
        if let s = m.4 { tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "action", image: String(s))) }
        if let s = m.5 { tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "testInput", image: String(s))) }
    }
    for t in tokens {
        print(t.image, t.type)
    }
}
