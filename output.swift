//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)
//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"multiLine":	("/\\/\\*(?s).*?\\*\\//,	Regex<Substring>(program: _StringProcessing.Regex<Swift.Substring>.Program),	false,	true),
	"b":	("\"b\",	Regex { "Regex<Substring>(program: _StringProcessing.Regex<Swift.Substring>.Program)" },	true,	false),
	"singleLine":	("/\\/\\/.*/,	Regex<Substring>(program: _StringProcessing.Regex<Swift.Substring>.Program),	false,	true),
	"whitespace":	("/\\s+/,	Regex<Substring>(program: _StringProcessing.Regex<Swift.Substring>.Program),	false,	true),
	"a":	("\"a\",	Regex { "Regex<Substring>(program: _StringProcessing.Regex<Swift.Substring>.Program)" },	true,	false),
	"d":	("\"d\",	Regex { "Regex<Substring>(program: _StringProcessing.Regex<Swift.Substring>.Program)" },	true,	false),
]
func whitespace() {
	next()
}
func S() {
	switch token.type {
	case "a":
		next()
		S()
		next()
	case "a":
		next()
		S()
		next()
	case "a":
		next()
	default:
		expect(["a"])
	}
}
func multiLine() {
	next()
}
func singleLine() {
	next()
}
