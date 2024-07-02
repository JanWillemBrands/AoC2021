//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"x":	("x",	Regex { "x" },	true,	false),
]
func S() {
	if ["x"].contains(token.type) {
		next()
	}
}
