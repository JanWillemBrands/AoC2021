//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"b":	("b",	Regex { "b" },	true,	false),
	"c":	("c",	Regex { "c" },	true,	false),
	"a":	("a",	Regex { "a" },	true,	false),
]
func S() {
	switch token.type {
	case "a", "b":
		switch token.type {
		case "a":
			next()
		case "b":
			next()
		default:
			expect(["a", "b"])
		}
	case "c":
		next()
	default:
		expect(["a", "b", "c"])
	}
}
