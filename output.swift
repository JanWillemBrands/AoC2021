//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"d":	("d",	Regex { "d" },	true,	false),
	"b":	("b",	Regex { "b" },	true,	false),
	"m":	("m",	Regex { "m" },	true,	false),
	"l":	("l",	Regex { "l" },	true,	false),
	"k":	("k",	Regex { "k" },	true,	false),
	"n":	("n",	Regex { "n" },	true,	false),
	"a":	("a",	Regex { "a" },	true,	false),
	"c":	("c",	Regex { "c" },	true,	false),
]
func S() {
	switch token.type {
	case "a":
		next()
		if ["b", "c"].contains(token.type) {
			switch token.type {
			case "b":
				next()
			case "c":
				next()
			default:
				expect(["b", "c"])
			}
		}
		next()
	case "k":
		next()
		if ["l", "m"].contains(token.type) {
			switch token.type {
			case "l":
				next()
			case "m":
				next()
			default:
				expect(["l", "m"])
			}
		}
		next()
	default:
		expect(["a", "k"])
	}
}
