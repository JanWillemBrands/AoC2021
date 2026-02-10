//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"action":	("/@(?:[^@\\\\]|\\\\.)+@/",	/@(?:[^@\\]|\\.)+@/,	false,	false),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"message":	("/\\^\\^\\^(?:(?s).*?)(?=\\^\\^\\^|$)/",	/\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,	false,	false),
	"blockcomment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"epsilon":	("/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]/",	/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"linecomment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"regex":	("/\\/(?:[^\\/\\\\]|\\\\.)+\\//",	/\/(?:[^\/\\]|\\.)+\//,	false,	false),
	":":	(":",	Regex { ":" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
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
func sequence() {
	if token.type = .ALT {
		// POS
	}
	expect(["{", "literal", "(", "<", "[", "identifier", "action", "epsilon", "regex"])
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
	expect(["action", "regex", "identifier", "literal", "epsilon"])
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
	expect(["epsilon", "(", "action", "literal", "{", "identifier", "regex", "<", "["])
}
