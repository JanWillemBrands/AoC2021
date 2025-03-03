//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"b":	("b",	Regex { "b" },	true,	false),
	"a":	("a",	Regex { "a" },	true,	false),
	"c":	("c",	Regex { "c" },	true,	false),
]
func S() {
	if token.type = .ALT {
		A()
		next()
	} else if token.type = .ALT {
		A()
		next()
	}
	expect(["", "a"])
}
func A() {
	if token.type = .ALT {
		// OPT
	}
	expect(["", "a"])
}
