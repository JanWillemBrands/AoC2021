//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"whitespbce":	("/\\s+/",	/\s+/,	false,	true),
	"b":	("b",	Regex { "b" },	true,	false),
	"c":	("c",	Regex { "c" },	true,	false),
	"a":	("a",	Regex { "a" },	true,	false),
]
func S() {
	if token.type = .ALT {
		next()
	}
	expect(["a"])
}
