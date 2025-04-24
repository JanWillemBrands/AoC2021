//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"b":	("b",	Regex { "b" },	true,	false),
	"c":	("c",	Regex { "c" },	true,	false),
	"t":	("t",	Regex { "t" },	true,	false),
	"a":	("a",	Regex { "a" },	true,	false),
]
func T() {
	if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	} else if token.type = .ALT {
		next()
	}
	expect(["a"])
}
func S() {
	if token.type = .ALT {
		T()
		next()
	}
	expect(["c", "b", "a"])
}
