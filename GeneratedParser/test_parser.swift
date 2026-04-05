
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
	"interpolatedStringLiteralHead":	("/\"(?:[^\"\\\\]|\\\\u\\{[0-9a-fA-F]+\\}|\\\\[0\\\\tnr\"\']|\\\\.)*?\\\\\\(/",	/"(?:[^"\\]|\\u\{[0-9a-fA-F]+\}|\\[0\\tnr"']|\\.)*?\\\(/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"identifier":	("/[\\p{XID_Start}_]\\p{XID_Continue}*/",	/[\p{XID_Start}_]\p{XID_Continue}*/,	false,	false),
	"interpolatedStringLiteralPart":	("/\\)(?:[^\"\\\\]|\\\\u\\{[0-9a-fA-F]+\\}|\\\\[0\\\\tnr\"\']|\\\\.)*?\\\\\\(/",	/\)(?:[^"\\]|\\u\{[0-9a-fA-F]+\}|\\[0\\tnr"']|\\.)*?\\\(/,	false,	false),
	"comment":	("/\\/\\/.*\\r?\\n?/",	/\/\/.*\r?\n?/,	false,	true),
	"interpolatedStringLiteralTail":	("/(?!.*\\\\\\()\\)(?:[^\"\\\\]|\\\\u\\{[0-9a-fA-F]+\\}|\\\\[0\\\\tnr\"\']|\\\\.)*?\"/",	/(?!.*\\\()\)(?:[^"\\]|\\u\{[0-9a-fA-F]+\}|\\[0\\tnr"']|\\.)*?"/,	false,	false),
	"singleLineStringLiteral":	("/\"(?:[^\"\\\\]|\\\\u\\{[0-9a-fA-F]+\\}|\\\\[0\\\\tnr\"\']|\\\\(?!\\().)*?\"/",	/"(?:[^"\\]|\\u\{[0-9a-fA-F]+\}|\\[0\\tnr"']|\\(?!\().)*?"/,	false,	false),
	"interpolatedString":	("interpolatedString",	Regex { "interpolatedString" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"parenthesisMode":	("parenthesisMode",	Regex { "parenthesisMode" },	true,	false),
	"\\":	("\\",	Regex { "\\" },	true,	false),
]
func expression() throws {
	switch token.kind {
	case "identifier":
		cI += 1
	case "(":
		try parenthesizedExpression()
	case "interpolatedStringLiteralHead", "singleLineStringLiteral":
		try stringLiteral()
	default:
		expect("(", "identifier", "interpolatedStringLiteralHead", "singleLineStringLiteral")
	}
}
func interpolatedStringLiteral() throws {
	expect("interpolatedStringLiteralHead")
	cI += 1
	try expression()
	while ["interpolatedStringLiteralPart"].contains(token.kind) {
		cI += 1
		try expression()
	}
	expect("interpolatedStringLiteralTail")
	cI += 1
}
func parenthesizedExpression() throws {
	expect("(")
	cI += 1
	try expression()
	expect(")")
	cI += 1
}
func stringLiteral() throws {
	switch token.kind {
	case "singleLineStringLiteral":
		cI += 1
	case "interpolatedStringLiteralHead":
		try interpolatedStringLiteral()
	default:
		expect("interpolatedStringLiteralHead", "singleLineStringLiteral")
	}
}
func test() throws {
	while ["\\\\"].contains(token.kind) {
		cI += 1
	}
}
func parse() throws {
	try test()
	expect("$")
}
