//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"message":	("/\\^\\^\\^(?:(?s).*?)(?=\\^\\^\\^|$)/",	/\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"regex":	("/\\/(?:[^\\/\\\\]|\\\\.)+\\//",	/\/(?:[^\/\\]|\\.)+\//,	false,	false),
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)+\\\"/",	/\"(?:[^\"\\]|\\.)+\"/,	false,	false),
	"action":	("/@(?:[^@\\\\]|\\\\.)+@/",	/@(?:[^@\\]|\\.)+@/,	false,	false),
	"blockcomment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"linecomment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"L21P25":	("/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄]/",	/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄]/,	false,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
]
func production() {
	if token.type = .ALT {
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
func sequence() {
	if token.type = .ALT {
		// POS
	}
	expect(["regex", "[", "*", "?", "+", "literal", "", "L21P25", "identifier", "<", "{", "action", "("])
}
func selection() {
	if token.type = .ALT {
		sequence()
		// KLN
		while ["", "|"].contains(token.type) {
			if token.type = .ALT {
				next()
			}
			expect(["|"])
		}
	}
	expect(["regex", "", "+", "(", "*", "L21P25", "identifier", "[", "literal", "|", "{", "<", "?", "action"])
}
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
	expect(["literal", "regex", "action", "L21P25", "identifier", ""])
}
func epsilon() {
	if token.type = .ALT {
	} else if token.type = .ALT {
	} else if token.type = .ALT {
	}
	expect([""])
}
