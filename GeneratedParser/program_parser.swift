
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
	"name":	("/[a-z]+/",	/[a-z]+/,	false,	false),
	"if":	("if",	Regex { "if" },	true,	false),
	"=":	("=",	Regex { "=" },	true,	false),
	"end":	("end",	Regex { "end" },	true,	false),
	"do":	("do",	Regex { "do" },	true,	false),
]
func assignment() throws {
	expect("name")
	cI += 1
	expect("=")
	cI += 1
	expect("name")
	cI += 1
}
func doStatement() throws {
	expect("do")
	cI += 1
	try statement()
	expect("end")
	cI += 1
}
func ifStatement() throws {
	expect("if")
	cI += 1
	expect("name")
	cI += 1
	expect("do")
	cI += 1
	try statement()
	expect("end")
	cI += 1
}
func program() throws {
	while ["do", "if", "name"].contains(token.kind) {
		try statement()
	}
}
func statement() throws {
	switch token.kind {
	case "if":
		try ifStatement()
	case "do":
		try doStatement()
	case "name":
		try assignment()
	default:
		expect("do", "if", "name")
	}
}
func parse() throws {
	try program()
	expect("$")
}
