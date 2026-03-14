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
	expect(["literal", "action", "epsilon", "regex", "identifier"])
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
	expect(["regex", "(", "{", "identifier", "[", "action", "epsilon", "<", "literal"])
}
func sequence() {
	if token.type = .ALT {
		// POS
	}
	expect(["[", "(", "action", "<", "identifier", "literal", "epsilon", "regex", "{"])
}
func production() {
	if token.type = .ALT {
		next()
	}
	expect(["identifier"])
}
