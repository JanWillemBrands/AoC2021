
// MARK: - start of template code
import Foundation
import RegexBuilder

var tokens: [Token] = []
var cI = 0
var token: Token { tokens[cI] }

func expect(_ expected: String...) {
    if !expected.contains(token.kind) {
        let position = token.image.base.linePosition(of: token.image.startIndex)
        fatalError("\(position): expected \(expected) but found \"\(token.kind)\"")
    }
}

// MARK: - start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"blockcomment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"x":	("x",	Regex { "x" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	">>":	(">>",	Regex { ">>" },	true,	false),
]
func B() throws {
	expect(">>")
	cI += 1
}
func S() throws {
	switch token.kind {
	case "x":
		cI += 1
	case "<":
		cI += 1
		try Y()
	default:
		expect("<", "x")
	}
}
func Y() throws {
	try S()
	expect(">")
	cI += 1
}
func parse() throws {
	try S()
	expect("$")
}
