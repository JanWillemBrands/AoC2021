//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated codelet tokenPatterns: [String:TokenPattern] = [
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"multiLine":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"action":	("/@(?:[^@\\\\]|\\\\.)*@/",	/@(?:[^@\\]|\\.)*@/,	false,	false),
	"message":	("/¶(?:\\/(?:[^\\/\\\\]|\\\\.)*\\/|[^¶\\/]*)*/",	/¶(?:\/(?:[^\/\\]|\\.)*\/|[^¶\/]*)*/,	false,	false),
	"singleLine":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"regex":	("/\\/(?:[^\\/\\\\]|\\\\.)*\\//",	/\/(?:[^\/\\]|\\.)*\//,	false,	false),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	")?":	(")?",	Regex { ")?" },	true,	false),
	")*":	(")*",	Regex { ")*" },	true,	false),
	")+":	(")+",	Regex { ")+" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
]
func S() {
	S()
	 {
		if token.type = ALT {
			// KLN
			expect(["", "identifier"])
		}
	}
}
func sequence() {
	sequence()
	 {
		if token.type = ALT {
			term()
			// KLN
			expect(["<", "regex", "action", "literal", "{", "(", "identifier", "["])
		}
	}
}
func production() {
	production()
	 {
		if token.type = ALT {
			next()
			expect(["identifier"])
		}
	}
}
func selection() {
	selection()
	 {
		if token.type = ALT {
			sequence()
			// KLN
			expect(["{", "identifier", "(", "[", "<", "literal", "regex", "action"])
		}
	}
}
func term() {
	term()
	 {
		if token.type = ALT {
			terminal()
			// END
			expect(["action", "identifier", "regex", "literal"])
		}
	}
}
func terminal() {
	terminal()
	 {
		if token.type = ALT {
			next()
			expect(["identifier"])
		}
	}
}
