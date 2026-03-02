//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"blockcomment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"message":	("/\\^\\^\\^(?:(?s).*?)(?=\\^\\^\\^|$)/",	/\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,	false,	false),
	"linecomment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"epsilon":	("/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]/",	/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]/,	false,	false),
	"regex":	("/\\/(?:[^\\/\\\\]|\\\\.)+\\//",	/\/(?:[^\/\\]|\\.)+\//,	false,	false),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"action":	("/@(?:[^@\\\\]|\\\\.)+@/",	/@(?:[^@\\]|\\.)+@/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
]
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
	expect(["regex", "<", "(", "epsilon", "[", "action", "{", "literal", "identifier"])
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
	expect(["{", "<", "literal", "action", "regex", "identifier", "[", "(", "epsilon"])
}
func grammar() {
	if token.type = .ALT {
		// POS
	}
	expect(["identifier"])
}
func production() {
	if token.type = .ALT {
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
	expect(["literal", "identifier", "action", "regex", "epsilon"])
}
