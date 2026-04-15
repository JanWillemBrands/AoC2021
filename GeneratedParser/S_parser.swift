
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
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"blockcomment":	("/\\/\\*(?s).*?\\*\\//",	/\/\*(?s).*?\*\//,	false,	true),
	">>":	(">>",	Regex { ">>" },	true,	false),
	">":	(">",	Regex { ">" },	true,	false),
	"<":	("<",	Regex { "<" },	true,	false),
	"s":	("s",	Regex { "s" },	true,	false),
]
func S() throws {
	switch token.kind {
	case "<":
		cI += 1
		expect("s")
		cI += 1
		try S()
		expect(">")
		cI += 1
	default:
	case ">>":
		cI += 1
	}
}
func parse() throws {
	try S()
	expect("$")
}
