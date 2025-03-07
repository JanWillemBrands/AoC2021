//: start of template code
import Foundation
import RegexBuilder

var input = ""

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"hup":	("hup",	Regex { "hup" },	true,	false),
	"lala":	("lala",	Regex { "lala" },	true,	false),
	"bla":	("bla",	Regex { "bla" },	true,	false),
	"!":	("!",	Regex { "!" },	true,	false),
]
func S() {
	if token.type = .ALT {
		next()
	}
	expect(["bla"])
}
