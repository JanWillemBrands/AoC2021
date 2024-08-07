//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"a":	("a",	Regex { "a" },	true,	false),
	"b":	("b",	Regex { "b" },	true,	false),
]
func S() {
	while ["a"].contains(token.type) {
		next()
	}
	next()
}
