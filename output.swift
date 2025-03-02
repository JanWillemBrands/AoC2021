//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated codelet tokenPatterns: [String:TokenPattern] = [
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"a":	("a",	Regex { "a" },	true,	false),
	"c":	("c",	Regex { "c" },	true,	false),
	"b":	("b",	Regex { "b" },	true,	false),
]
func A() {
	A()
	 {
		if token.type = ALT {
			// OPT
			expect(["a", ""])
		}
	}
}
func S() {
	S()
	 {
		if token.type = ALT {
			A()
			next()
			expect(["", "a"])
		}
	}
}
