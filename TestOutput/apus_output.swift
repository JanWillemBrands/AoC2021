//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"epsilon":	("/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]/",	/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]/,	false,	false),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"message":	("/\\^\\^\\^(?:(?s).*?)(?=\\^\\^\\^|$)/",	/\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,	false,	false),
	"blockcomment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"action":	("/@(?:[^@\\\\]|\\\\.)+@/",	/@(?:[^@\\]|\\.)+@/,	false,	false),
	"linecomment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"regex":	("/\\/(?:[^\\/\\\\]|\\\\.)+\\//",	/\/(?:[^\/\\]|\\.)+\//,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"<":	("<",	Regex { "<" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
]
func grammar() {
	if token.type = .ALT {
		// POS
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
	expect(["action", "epsilon", "regex", "<", "identifier", "{", "literal", "(", "["])
}
func production() {
	if token.type = .ALT {
		next()
	}
	expect(["identifier"])
}
func sequence() {
	if token.type = .ALT {
		// POS
	}
	expect(["action", "{", "(", "<", "regex", "identifier", "epsilon", "[", "literal"])
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
	expect(["action", "literal", "identifier", "regex", "epsilon"])
}
