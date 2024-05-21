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
	"c":	("c",	Regex { "c" },	true,	false),
	"b":	("b",	Regex { "b" },	true,	false),
]
func comment() {
	next()
}
func S() {
	switch token.type {
	case "a":
		next()
		B()
		next()
	case "a":
		next()
		B()
		next()
	default:
		expect(["a"])
	}
}
func whitespace() {
	next()
}
func B() {
	next()
}
