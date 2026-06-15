
// MARK: - start of template code
import Foundation
import RegexBuilder

var tokens: [Token] = []
var trivia: [[Token]] = []
var cI = 0
var token: Token { tokens[cI] }

func lineBreakCountBetweenTokens(at first: Int, and second: Int) -> Int {
    guard let input = tokens[first].image.base else { return 0 }
    let span = input[tokens[first].image.startIndex..<tokens[second].image.startIndex]
    var breaks = 0
    var prevWasCR = false
    for ch in span {
        let isCR = ch == "\r"
        let isLF = ch == "\n"
        if isCR || (isLF && !prevWasCR) { breaks += 1 }
        prevWasCR = isCR
    }
    return breaks
}

func hasInterTokenGap(at first: Int, and second: Int) -> Bool {
    tokens[first].image.endIndex < tokens[second].image.startIndex
}

func boundary(_ kind: String) {
    guard cI > 0 && cI < tokens.count else {
        fatalError("boundary '\(kind)' cannot be evaluated at token index \(cI)")
    }
    let left = cI - 1
    let right = cI
    switch kind {
    case "<s>":
        if !hasInterTokenGap(at: left, and: right) {
            fatalError("expected spacing between tokens around '\(kind)'")
        }
    case "<n>":
        if lineBreakCountBetweenTokens(at: left, and: right) == 0 {
            fatalError("expected line break between tokens around '\(kind)'")
        }
    case ">s<":
        if hasInterTokenGap(at: left, and: right) {
            fatalError("expected adjacency between tokens around '\(kind)'")
        }
    case ">n<":
        if lineBreakCountBetweenTokens(at: left, and: right) > 0 {
            fatalError("expected same line between tokens around '\(kind)'")
        }
    default:
        fatalError("unknown boundary token '\(kind)'")
    }
}

func expect(_ expected: String...) {
    if !expected.contains(token.kind) {
        let position = token.image.base.linePosition(of: token.image.startIndex)
        fatalError("\(position): expected \(expected) but found \"\(token.kind)\"")
    }
}

// MARK: - start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)+\\\"/",	/\"(?:[^\"\\]|\\.)+\"/,	false,	false),
	"regex":	("/\\/(?!\\*)(?:[^\\/\\\\]|\\\\.)+\\//",	/\/(?!\*)(?:[^\/\\]|\\.)+\//,	false,	false),
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	""|"":	("|",	Regex { "|" },	true,	false),
	""["":	("[",	Regex { "[" },	true,	false),
	""{"":	("{",	Regex { "{" },	true,	false),
	""("":	("(",	Regex { "(" },	true,	false),
	"":-"":	(":-",	Regex { ":-" },	true,	false),
	""."":	(".",	Regex { "." },	true,	false),
	"">"":	(">",	Regex { ">" },	true,	false),
	""]"":	("]",	Regex { "]" },	true,	false),
	"")"":	(")",	Regex { ")" },	true,	false),
	""}"":	("}",	Regex { "}" },	true,	false),
	""<"":	("<",	Regex { "<" },	true,	false),
]
func factor() throws {
	switch token.kind {
	case "identifier", "literal", "regex":
		try terminal()
	case "\"[\"":
		cI += 1
		try selection()
		expect("\"]\"")
		cI += 1
	case "\"{\"":
		cI += 1
		try selection()
		expect("\"}\"")
		cI += 1
	case "\"<\"":
		cI += 1
		try selection()
		expect("\">\"")
		cI += 1
	case "\"(\"":
		cI += 1
		try selection()
		expect("\")\"")
		cI += 1
	default:
		expect("\"(\"", "\"<\"", "\"[\"", "\"{\"", "identifier", "literal", "regex")
	}
}
func production() throws {
	expect("identifier")
	cI += 1
	expect("\":-\"")
	cI += 1
	try selection()
	expect("\".\"")
	cI += 1
}
func selection() throws {
	try sequence()
	while ["\"|\""].contains(token.kind) {
		cI += 1
		try sequence()
	}
}
func sequence() throws {
	repeat {
		try factor()
	} while ["\"(\"", "\"<\"", "\"[\"", "\"{\"", "identifier", "literal", "regex"].contains(token.kind)
}
func terminal() throws {
	switch token.kind {
	case "identifier":
		cI += 1
	case "literal":
		cI += 1
	case "regex":
		cI += 1
	default:
		expect("identifier", "literal", "regex")
	}
}
func parse() throws {
	try production()
	expect("$")
}
