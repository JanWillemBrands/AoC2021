//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"y":	("y",	Regex { "y" },	true,	false),
	"z":	("z",	Regex { "z" },	true,	false),
	"a":	("a",	Regex { "a" },	true,	false),
	"x":	("x",	Regex { "x" },	true,	false),
	"b":	("b",	Regex { "b" },	true,	false),
]
func S() {
	while ["a"].contains(token.type) {
		next()
	}
	next()
	next()
	next()
	while ["b"].contains(token.type) {
		next()
	}
}
