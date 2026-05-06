
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
	"L5P14":	("/\\w+/",	/\w+/,	false,	false),
]
func article() throws {
	try title()
	expect(">>|")
	cI += 1
	repeat {
		try section()
	} while ["L5P14"].contains(token.kind)
	expect("|<<")
	cI += 1
}
func paragraph() throws {
	repeat {
		try word()
	} while ["L5P14"].contains(token.kind)
}
func section() throws {
	try title()
	expect(">>|")
	cI += 1
	repeat {
		try paragraph()
	} while ["L5P14"].contains(token.kind)
	expect("|<<")
	cI += 1
}
func title() throws {
	repeat {
		try word()
		expect(">n<")
		cI += 1
	} while ["L5P14"].contains(token.kind)
}
func word() throws {
	expect("L5P14")
	cI += 1
}
func parse() throws {
	try word()
	expect("$")
}
