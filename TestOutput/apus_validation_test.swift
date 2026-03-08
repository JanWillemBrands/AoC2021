//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"message":	("/\\^\\^\\^(?:(?s).*?)(?=\\^\\^\\^|$)/",	/\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,	false,	false),
	"linecomment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"blockcomment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"action":	("/@(?:[^@\\\\]|\\\\.)+@/",	/@(?:[^@\\]|\\.)+@/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"epsilon":	("/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]/",	/[ΕεϵԐԑ𝛆𝛜𝜀𝜖𝜺𝝐𝝴𝞊𝞮𝟄#]/,	false,	false),
	"regex":	("/\\/(?:[^\\/\\\\]|\\\\.)+\\//",	/\/(?:[^\/\\]|\\.)+\//,	false,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"?":	("?",	Regex { "?" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"*":	("*",	Regex { "*" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	"+":	("+",	Regex { "+" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
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
	expect(["literal", "regex", "action", "epsilon", "identifier"])
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
		while ["", "|"].contains(token.type) {
			if token.type = .ALT {
				next()
			}
			expect(["|"])
		}
	}
	expect(["(", "regex", "identifier", "action", "<", "{", "literal", "epsilon", "["])
}
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
	expect(["[", "(", "{", "regex", "action", "literal", "<", "epsilon", "identifier"])
}
