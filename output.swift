//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"blockcomment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"action":	("/@(?:[^@\\\\]|\\\\.)+@/",	/@(?:[^@\\]|\\.)+@/,	false,	false),
	"linecomment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"L21P25":	("/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄]/",	/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄]/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"regex":	("/\\/(?:[^\\/\\\\]|\\\\.)+\\//",	/\/(?:[^\/\\]|\\.)+\//,	false,	false),
	"message":	("/\\^\\^\\^(?:(?s).*?)(?=\\^\\^\\^|$)/",	/\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,	false,	false),
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
]
func term() {
	if token.type = .ALT {
		terminal()
		// END
	} else if token.type = .ALT {
		terminal()
		// END
	} else if token.type = .ALT {
		terminal()
		// END
	} else if token.type = .ALT {
		terminal()
		// END
	} else if token.type = .ALT {
		terminal()
		// END
	}
	expect(["L21P25", "", "literal", "regex", "action", "identifier"])
}
func terminal() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["identifier"])
}
func grammar() {
	if token.type = .ALT {
		// POS
	}
	expect(["identifier"])
}
func epsilon() {
	if token.type = .ALT {
	} else if token.type = .ALT {
	} else if token.type = .ALT {
	}
	expect([""])
}
func sequence() {
	if token.type = .ALT {
		// POS
	}
	expect(["<", "action", "literal", "", "regex", "(", "?", "+", "{", "L21P25", "[", "identifier", "*"])
}
func selection() {
	if token.type = .ALT {
		sequence()
		// KLN
		while ["|", ""].contains(token.type) {
			if token.type = .ALT {
				next()
			}
			expect(["|"])
		}
	}
	expect(["(", "|", "<", "{", "L21P25", "", "identifier", "[", "*", "regex", "+", "literal", "?", "action"])
}
func production() {
	if token.type = .ALT {
		next()
	}
	expect(["identifier"])
}
