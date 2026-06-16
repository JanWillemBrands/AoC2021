
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
	"singleLine":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"आक्षरिक":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"multiLine":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"action":	("/@(?:[^@\\\\]|\\\\.)*@/",	/@(?:[^@\\]|\\.)*@/,	false,	false),
	"message":	("/\\^^^(?:[^\\^^^\\\\]|\\\\.)*/",	/\^^^(?:[^\^^^\\]|\\.)*/,	false,	false),
	"正規表現":	("/\\/(?:[^\\/\\\\]|\\\\.)*\\//",	/\/(?:[^\/\\]|\\.)*\//,	false,	false),
	"ідентифікатор":	("/[\\p{L}\\p{N}\\p{Pc}]+/",	/[\p{L}\p{N}\p{Pc}]+/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	""."":	(".",	Regex { "." },	true,	false),
	""("":	("(",	Regex { "(" },	true,	false),
	""]"":	("]",	Regex { "]" },	true,	false),
	""["":	("[",	Regex { "[" },	true,	false),
	"")?"":	(")?",	Regex { ")?" },	true,	false),
	""<"":	("<",	Regex { "<" },	true,	false),
	""|"":	("|",	Regex { "|" },	true,	false),
	""{"":	("{",	Regex { "{" },	true,	false),
	"":"":	(":",	Regex { ":" },	true,	false),
	""="":	("=",	Regex { "=" },	true,	false),
	""}"":	("}",	Regex { "}" },	true,	false),
	"")+"":	(")+",	Regex { ")+" },	true,	false),
	"">"":	(">",	Regex { ">" },	true,	false),
	"")*"":	(")*",	Regex { ")*" },	true,	false),
	"")"":	(")",	Regex { ")" },	true,	false),
]
func S() throws {
	while ["ідентифікатор"].contains(token.kind) {
		try production()
	}
	while ["message"].contains(token.kind) {
		cI += 1
	}
}
func factor() throws {
	switch token.kind {
	case "action", "ідентифікатор", "आक्षरिक", "正規表現":
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
		switch token.kind {
		case "\")\"":
			cI += 1
		case "\")?\"":
			cI += 1
		case "\")*\"":
			cI += 1
		case "\")+\"":
			cI += 1
		default:
			expect("\")\"", "\")*\"", "\")+\"", "\")?\"")
		}
	default:
		expect("\"(\"", "\"<\"", "\"[\"", "\"{\"", "action", "ідентифікатор", "आक्षरिक", "正規表現")
	}
}
func production() throws {
	expect("ідентифікатор")
	cI += 1
	switch token.kind {
	case "\":\"":
		cI += 1
	case "\"=\"":
		cI += 1
	default:
		expect("\":\"", "\"=\"")
	}
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
	try factor()
	while ["\"(\"", "\"<\"", "\"[\"", "\"{\"", "action", "ідентифікатор", "आक्षरिक", "正規表現"].contains(token.kind) {
		try factor()
	}
}
func terminal() throws {
	switch token.kind {
	case "ідентифікатор":
		cI += 1
	case "आक्षरिक":
		cI += 1
	case "正規表現":
		cI += 1
	case "action":
		cI += 1
	default:
		expect("action", "ідентифікатор", "आक्षरिक", "正規表現")
	}
}
func parse() throws {
	try S()
	expect("$")
}
