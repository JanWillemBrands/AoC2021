//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"b":	("b",	Regex { "b" },	true,	false),
	"a":	("a",	Regex { "a" },	true,	false),
]
func S() {
	if token.type = .ALT {
		next()
	}
	expect(["a"])
}
func B() {
	if token.type = .ALT {
		next()
	}
	expect(["b"])
}
