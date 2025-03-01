//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated codelet tokenPatterns: [String:TokenPattern] = [
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"c":	("c",	Regex { "c" },	true,	false),
	"b":	("b",	Regex { "b" },	true,	false),
	"a":	("a",	Regex { "a" },	true,	false),
]
func S() {
	S()
	 {
		if token.type = ALT {
			// OPT
			expect(["a", ""])
		}
	}
}
