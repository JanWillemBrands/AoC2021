
// MARK: - start of template code
import Foundation
import RegexBuilder

var tokens: [Token] = []
var cI = 0
var token: Token { tokens[cI] }

func expect(_ expected: String...) {
    if !expected.contains(token.kind) {
        let position = token.image.base.linePosition(of: token.image.startIndex)
        fatalError("\(position): expected \(expected) but found \"\(token.kind)\"")
    }
}

// MARK: - start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"正規表現":	("/\\/(?:[^\\/\\\\]|\\\\.)*\\//",	/\/(?:[^\/\\]|\\.)*\//,	false,	false),
	"singleLine":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"action":	("/@(?:[^@\\\\]|\\\\.)*@/",	/@(?:[^@\\]|\\.)*@/,	false,	false),
	"multiLine":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"message":	("/\\^^^(?:[^\\^^^\\\\]|\\\\.)*/",	/\^^^(?:[^\^^^\\]|\\.)*/,	false,	false),
	"आक्षरिक":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"ідентифікатор":	("/[\\p{L}\\p{N}\\p{Pc}]+/",	/[\p{L}\p{N}\p{Pc}]+/,	false,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	")?":	(")?",	Regex { ")?" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	")*":	(")*",	Regex { ")*" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	")+":	(")+",	Regex { ")+" },	true,	false),
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
	case "[":
		cI += 1
		try selection()
		expect("]")
		cI += 1
	case "{":
		cI += 1
		try selection()
		expect("}")
		cI += 1
	case "<":
		cI += 1
		try selection()
		expect(">")
		cI += 1
	case "(":
		cI += 1
		try selection()
		switch token.kind {
		case ")":
			cI += 1
		case ")?":
			cI += 1
		case ")*":
			cI += 1
		case ")+":
			cI += 1
		default:
			expect(")", ")*", ")+", ")?")
		}
	default:
		expect("(", "<", "[", "action", "{", "ідентифікатор", "आक्षरिक", "正規表現")
	}
}
func production() throws {
	expect("ідентифікатор")
	cI += 1
	switch token.kind {
	case ":":
		cI += 1
	case "=":
		cI += 1
	default:
		expect(":", "=")
	}
	try selection()
	expect(".")
	cI += 1
}
func selection() throws {
	try sequence()
	while ["|"].contains(token.kind) {
		cI += 1
		try sequence()
	}
}
func sequence() throws {
	try factor()
	while ["(", "<", "[", "action", "{", "ідентифікатор", "आक्षरिक", "正規表現"].contains(token.kind) {
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
