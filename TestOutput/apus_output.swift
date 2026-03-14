//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"linecomment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"message":	("/\\^\\^\\^(?:(?s).*?)(?=\\^\\^\\^|$)/",	/\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,	false,	false),
	"regex":	("/\\/(?:[^\\/\\\\]|\\\\.)+\\//",	/\/(?:[^\/\\]|\\.)+\//,	false,	false),
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"blockcomment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"action":	("/@(?:[^@\\\\]|\\\\.)+@/",	/@(?:[^@\\]|\\.)+@/,	false,	false),
	"epsilon":	("/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]/",	/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]/,	false,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
]
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
	expect(["regex", "action", "literal", "epsilon", "identifier"])
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
	expect(["epsilon", "regex", "action", "<", "(", "literal", "{", "identifier", "["])
}
func sequence() {
	if token.type = .ALT {
		// POS
	}
	expect(["<", "identifier", "action", "epsilon", "regex", "(", "{", "literal", "["])
}
func production() {
	if token.type = .ALT {
		next()
	}
	expect(["identifier"])
}
