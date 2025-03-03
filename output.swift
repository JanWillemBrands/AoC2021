//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated codelet tokenPatterns: [String:TokenPattern] = [
	"message":	("/¶(?:\\/(?:[^\\/\\\\]|\\\\.)*\\/|[^¶\\/]*)*/",	/¶(?:\/(?:[^\/\\]|\\.)*\/|[^¶\/]*)*/,	false,	false),
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)*\\\"/",	/\"(?:[^\"\\]|\\.)*\"/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"regex":	("/\\/(?:[^\\/\\\\]|\\\\.)*\\//",	/\/(?:[^\/\\]|\\.)*\//,	false,	false),
	"action":	("/@(?:[^@\\\\]|\\\\.)*@/",	/@(?:[^@\\]|\\.)*@/,	false,	false),
	"linecomment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"blockcomment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	")+":	(")+",	Regex { ")+" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	".":	(".",	Regex { "." },	true,	false),
	":":	(":",	Regex { ":" },	true,	false),
	"]":	("]",	Regex { "]" },	true,	false),
	")?":	(")?",	Regex { ")?" },	true,	false),
	"{":	("{",	Regex { "{" },	true,	false),
	"[":	("[",	Regex { "[" },	true,	false),
	"}":	("}",	Regex { "}" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	"|":	("|",	Regex { "|" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	")*":	(")*",	Regex { ")*" },	true,	false),
	";":	(";",	Regex { ";" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
]
func S() {
	if token.type = .ALT {
		// KLN
		while ["", "identifier"].contains(token.type) {
			if token.type = .ALT {
				production()
				// END
				
				
			}
			expect(["identifier"])
			
		}
		
	}
	expect(["", "identifier"])
	
	
}
func input() {
	if token.type = .ALT {
		next()
		   .dropFirst()
   .dropLast()
messages.append(String(message))
.

	}
	expect(["message"])
	
	
}
func sequence() {
	if token.type = .ALT {
		term()
		// KLN
		while ["", "(", "literal", "[", "<", "regex", "{", "action", "identifier"].contains(token.type) {
			if token.type = .ALT {
				term()
				// END
				
				}

			}
			expect(["{", "action", "identifier", "literal", "(", "[", "regex", "<"])
			
		}
		
		{

	}
	expect(["{", "action", "identifier", "literal", "(", "[", "regex", "<"])
	node = 
term

	
}
func terminal() {
	if token.type = .ALT {
		next()
		|

	} else if token.type = .ALT {
		next()
		|

	} else if token.type = .ALT {
		next()
		|

	} else if token.type = .ALT {
		next()
		|

	}
	expect(["identifier"])
	
	
}
func production() {
	if token.type = .ALT {
		next()
		(

	}
	expect(["identifier"])
	var muted = false
var terminalAlias: String?
identifier

	
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
		
		{

	}
	expect(["identifier", "(", "literal", "<", "[", "regex", "action", "{"])
	sequence

	
}
func term() {
	if token.type = .ALT {
		// DO
		
	}
	expect(["{", "literal", "regex", "action", "(", "<", "[", "identifier"])
	(

	
}
