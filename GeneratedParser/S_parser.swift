
// MARK: - start of template code
import Foundation
import RegexBuilder

var g = Grammar()
var node: GrammarNode!
var result: GrammarNode!
var skip = false
var terminalAlias: String?

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
	"name":	("/[a-z]+/",	/[a-z]+/,	false,	false),
	"identifier":	("/[a-z]+/",	/[a-z]+/,	false,	false),
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
]
func S() throws {
	expect("name")
	cI += 1
	expect("identifier")
	cI += 1
}
func parse() throws {
	try S()
	expect("$")
}
