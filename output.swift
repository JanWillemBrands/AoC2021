//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated codelet tokenPatterns: [String:TokenPattern] = [
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"regex":	("/\\/(?:[^\\/\\\\]|\\\\.)*\\//",	/\/(?:[^\/\\]|\\.)*\//,	false,	false),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"multiLine":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"singleLine":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"action":	("/@(?:[^@\\\\]|\\\\.)*@/",	/@(?:[^@\\]|\\.)*@/,	false,	false),
	"message":	("/¶(?:\\/(?:[^\\/\\\\]|\\\\.)*\\/|[^¶\\/]*)*/",	/¶(?:\/(?:[^\/\\]|\\.)*\/|[^¶\/]*)*/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"{":	("{",	Regex { "{" },	true,	false),
	")*":	(")*",	Regex { ")*" },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	")+":	(")+",	Regex { ")+" },	true,	false),
	")?":	(")?",	Regex { ")?" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
]
func production() {
	production()
	 {
		if token.type = ALT {
			next()
			expect(["identifier"])
		}
	}
}
func sequence() {
	sequence()
	 {
		if token.type = ALT {
			term()
			// KLN
			expect(["action", "literal", "(", "identifier", "<", "{", "regex", "["])
		}
	}
}
func term() {
	term()
	 {
		if token.type = ALT {
			terminal()
			// END
			expect(["identifier", "regex", "action", "literal"])
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
func selection() {
	selection()
	 {
		if token.type = ALT {
			sequence()
			// KLN
			expect(["literal", "regex", "<", "identifier", "(", "[", "{", "action"])
		}
	}
}
func S() {
	S()
	 {
		if token.type = ALT {
			// KLN
			expect(["identifier", "message", ""])
		}
	}
}
