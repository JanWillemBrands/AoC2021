
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
	"message":	("/\\^\\^\\^(?:(?s).*?)(?=\\^\\^\\^|$)/",	/\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,	false,	false),
	"blockcomment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"action":	("/@(?:[^@\\\\]|\\\\.)+@/",	/@(?:[^@\\]|\\.)+@/,	false,	true),
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"epsilon":	("/[εϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄]/",	/[εϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄]/,	false,	false),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"regex":	("/\\/(?:[^\\/\\\\]|\\\\.)+\\//",	/\/(?:[^\/\\]|\\.)+\//,	false,	false),
	"linecomment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"]":	("]",	Regex { "]" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"-":	("-",	Regex { "-" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
]
func factor() throws {
	switch token.kind {
	case "epsilon", "identifier", "literal", "regex":
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
		expect(")")
		cI += 1
	default:
		expect("(", "<", "[", "epsilon", "identifier", "literal", "regex", "{")
	}
}
func grammar() throws {
	repeat {
		try production()
	} while ["identifier"].contains(token.kind)
	while ["message"].contains(token.kind) {
		cI += 1
	}
}
func production() throws {
	expect("identifier")
	cI += 1
	switch token.kind {
	case ":":
		cI += 1
		expect("regex")
		cI += 1
	case "-":
		cI += 1
		expect("regex")
		cI += 1
	case "=":
		cI += 1
		try selection()
	default:
		expect("-", ":", "=")
	}
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
	repeat {
		try factor()
		switch token.kind {
		case "?":
			cI += 1
		case "*":
			cI += 1
		case "+":
			cI += 1
		default:
			break
		}
	} while ["(", "<", "[", "epsilon", "identifier", "literal", "regex", "{"].contains(token.kind)
}
func terminal() throws {
	switch token.kind {
	case "identifier":
		cI += 1
	case "literal":
		cI += 1
	case "regex":
		cI += 1
	case "epsilon":
		cI += 1
	default:
		expect("epsilon", "identifier", "literal", "regex")
	}
}
func parse() throws {
	try grammar()
	expect("$")
}
