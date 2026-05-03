
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
	"regex":	("/\\/(?!\\*)(?:[^\\/\\\\]|\\\\.)+\\//",	/\/(?!\*)(?:[^\/\\]|\\.)+\//,	false,	false),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"message":	("/\\^\\^\\^(?:(?s).*?)(?=\\^\\^\\^|$)/",	/\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,	false,	false),
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"L9P14":	("/\'(?:[^\\\'\\n])*\'/",	/'(?:[^\'\n])*'/,	false,	false),
	"action":	("/@(?:[^@\\\\]|\\\\.)+@/",	/@(?:[^@\\]|\\.)+@/,	false,	true),
	"]":	("]",	Regex { "]" },	true,	false),
	"-":	("-",	Regex { "-" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"---":	("---",	Regex { "---" },	true,	false),
	"===":	("===",	Regex { "===" },	true,	false),
	"\"\"":	("\"\"",	Regex { "\"\"" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"<<<":	("<<<",	Regex { "<<<" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	">>>":	(">>>",	Regex { ">>>" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"~~~":	("~~~",	Regex { "~~~" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	"ε":	("ε",	Regex { "ε" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
]
func epsilon() throws {
	switch token.kind {
	case "ε":
		cI += 1
	case "\\\"\\\"":
		cI += 1
	default:
		expect("\\\"\\\"", "ε")
	}
}
func factor() throws {
	switch token.kind {
	case "\\\"\\\"", "identifier", "literal", "regex", "ε":
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
		expect("(", "<", "[", "\\\"\\\"", "identifier", "literal", "regex", "{", "ε")
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
func pragma() throws {
	expect("L9P14")
	cI += 1
}
func production() throws {
	expect("identifier")
	cI += 1
	switch token.kind {
	case ":":
		cI += 1
		switch token.kind {
		case "regex":
			cI += 1
		case "literal":
			cI += 1
		default:
			expect("literal", "regex")
		}
		expect(".")
		cI += 1
		try scanmode()
	case "-":
		cI += 1
		switch token.kind {
		case "regex":
			cI += 1
		case "literal":
			cI += 1
		default:
			expect("literal", "regex")
		}
		expect(".")
		cI += 1
		try scanmode()
	case "=":
		cI += 1
		try selection()
		expect(".")
		cI += 1
	default:
		expect("-", ":", "=")
	}
}
func scanmode() throws {
	switch token.kind {
	case "===":
		cI += 1
		expect("literal")
		cI += 1
	case ">>>":
		cI += 1
		expect("literal")
		cI += 1
	case "<<<":
		cI += 1
		expect("literal")
		cI += 1
	default:
		break
	}
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
	} while ["(", "<", "[", "\\\"\\\"", "identifier", "literal", "regex", "{", "ε"].contains(token.kind)
}
func terminal() throws {
	switch token.kind {
	case "identifier":
		cI += 1
		if ["---"].contains(token.kind) {
			cI += 1
			expect("(")
			cI += 1
			repeat {
				expect("literal")
				cI += 1
			} while ["literal"].contains(token.kind)
			expect(")")
			cI += 1
		}
	case "literal":
		cI += 1
		if ["~~~"].contains(token.kind) {
			cI += 1
		}
	case "regex":
		cI += 1
	case "\\\"\\\"", "ε":
		try epsilon()
	default:
		expect("\\\"\\\"", "identifier", "literal", "regex", "ε")
	}
}
func parse() throws {
	try pragma()
	expect("$")
}
