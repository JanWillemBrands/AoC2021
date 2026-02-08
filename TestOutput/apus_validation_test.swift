//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"linecomment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"blockcomment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)+\\\"/",	/\"(?:[^\"\\]|\\.)+\"/,	false,	false),
	"regex":	("/\\/(?:[^\\/\\\\]|\\\\.)+\\//",	/\/(?:[^\/\\]|\\.)+\//,	false,	false),
	"message":	("/\\^\\^\\^(?:(?s).*?)(?=\\^\\^\\^|$)/",	/\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,	false,	false),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"action":	("/@(?:[^@\\\\]|\\\\.)+@/",	/@(?:[^@\\]|\\.)+@/,	false,	false),
	"L21P25":	("/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄]/",	/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄]/,	false,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
]
func grammar() {
	if token.type = .ALT {
		// POS
	}
	expect(["identifier"])
}
func sequence() {
	if token.type = .ALT {
		// POS
	}
	expect(["[", "identifier", "<", "L21P25", "*", "?", "action", "(", "regex", "", "literal", "{", "+"])
}
func production() {
	if token.type = .ALT {
		next()
	}
	expect(["identifier"])
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
	expect(["(", "L21P25", "+", "", "[", "literal", "action", "<", "|", "regex", "identifier", "*", "?", "{"])
}
func epsilon() {
	if token.type = .ALT {
	} else if token.type = .ALT {
	} else if token.type = .ALT {
	}
	expect([""])
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
	expect(["L21P25", "regex", "literal", "identifier", "action", ""])
}
