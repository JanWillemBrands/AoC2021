//
//  NewScanner.swift
//  Advent
//
//  Created by Johannes Brands on 29/03/2024.
//

import Foundation
import RegexBuilder

let whitespaceRegex  = Regex {
    OneOrMore { .whitespace }
}
let singleLineRegex = Regex {
    "//"
    ZeroOrMore { /./ }
}
let multiLineRegex = Regex {
    "/*"
    ZeroOrMore(.reluctant) {
        .any
    }
    "*/"
}
let identifierRegex  = Regex {
    OneOrMore {
        #/[\p{L}\p{N}\p{Pc}]/#
    }
}
let regexRegex = Regex {
    "/"
    ZeroOrMore(.reluctant) {
        .any
    }
    "/"
}
let actionRegex = Regex {
    "@"
    ZeroOrMore(.reluctant) {
        .any
    }
    "@"
}
let keywordRegex = Regex {
    "\""
    ZeroOrMore(.reluctant) {
        .any
    }
    "\""
}
let testInputRegex = Regex {
    "¶"
    ZeroOrMore(
        CharacterClass(.anyOf("¶").inverted)
    )
}


let text = #"""
My name /hello/  is "taylor"     // some comment
 and I am years old @ some action!!! @     /* some multiline
 comment */
¶some test text
¶more tests
"""#

let tokenizer = Regex {
    ChoiceOf {
        whitespaceRegex
        singleLineRegex
        multiLineRegex
        Capture { identifierRegex }
        Capture { regexRegex }
        Capture { actionRegex }
        Capture { keywordRegex }
        Capture { testInputRegex }
    }
}

var tokens: [Token] = []

func testNewScanner() {
    for m in text.matches(of: tokenizer) {
        if let s = m.1 { tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "identifier", image: String(s))) }
        if let s = m.2 { tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "regex", image: String(s))) }
        if let s = m.3 { tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "action", image: String(s))) }
        if let s = m.4 { tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "keyword", image: String(s))) }
        if let s = m.5 { tokens.append(Token(range: s.startIndex ..< s.endIndex, type: "testInput", image: String(s))) }
    }
    for t in tokens {
        print(t.image, t.type, t.range)
    }
}

