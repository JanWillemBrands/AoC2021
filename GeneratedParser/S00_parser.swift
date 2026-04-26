
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
	"word":	("/[a-z]+/",	/[a-z]+/,	false,	false),
	"alnum":	("/[a-z0-9]+/",	/[a-z0-9]+/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"name":	("/[a-z]+/",	/[a-z]+/,	false,	false),
	"number":	("/[0-9]+/",	/[0-9]+/,	false,	false),
	"do":	("do",	Regex { "do" },	true,	false),
	"then":	("then",	Regex { "then" },	true,	false),
	"if":	("if",	Regex { "if" },	true,	false),
	"end":	("end",	Regex { "end" },	true,	false),
]
func S00() throws {
	expect("if")
	cI += 1
	expect("then")
	cI += 1
	expect("end")
	cI += 1
}
func S01() throws {
	expect("name")
	cI += 1
	expect("name")
	cI += 1
}
func S02() throws {
	expect("if")
	cI += 1
	expect("name")
	cI += 1
	expect("then")
	cI += 1
	expect("name")
	cI += 1
	expect("end")
	cI += 1
}
func S03() throws {
	expect("name")
	cI += 1
}
func S04() throws {
	switch token.kind {
	case "if":
		cI += 1
	case "name":
		cI += 1
	default:
		expect("if", "name")
	}
}
func S05() throws {
	expect("do")
	cI += 1
	expect("name")
	cI += 1
	expect("end")
	cI += 1
}
func S06() throws {
	expect("name")
	cI += 1
	expect("name")
	cI += 1
	expect("name")
	cI += 1
}
func S07() throws {
	try kw()
	try ident()
}
func S08() throws {
	if ["if"].contains(token.kind) {
		cI += 1
	}
	expect("name")
	cI += 1
}
func S09() throws {
	while ["do"].contains(token.kind) {
		cI += 1
		expect("name")
		cI += 1
	}
}
func S10() throws {
	expect("alnum")
	cI += 1
	expect("alnum")
	cI += 1
}
func S11() throws {
	switch token.kind {
	case "if":
		cI += 1
	case "name":
		cI += 1
	case "word":
		cI += 1
	default:
		expect("if", "name", "word")
	}
}
func ident() throws {
	expect("name")
	cI += 1
}
func kw() throws {
	switch token.kind {
	case "if":
		cI += 1
	case "do":
		cI += 1
	default:
		expect("do", "if")
	}
}
func parse() throws {
	try S00()
	expect("$")
}
