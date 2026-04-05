
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
	"extendedSinglelineStringLiteral":	("/#+\".*?\"#+/",	/#+".*?"#+/,	false,	false),
	"linecomment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"interpolatedStringLiteralHead":	("/\"(?:[^\"\\\\]|\\\\u\\{[0-9a-fA-F]+\\}|\\\\[0\\\\tnr\"\']|\\\\.)*?\\\\\\(/",	/"(?:[^"\\]|\\u\{[0-9a-fA-F]+\}|\\[0\\tnr"']|\\.)*?\\\(/,	false,	false),
	"interpolatedStringLiteralPart":	("/\\)(?:[^\"\\\\]|\\\\u\\{[0-9a-fA-F]+\\}|\\\\[0\\\\tnr\"\']|\\\\.)*?\\\\\\(/",	/\)(?:[^"\\]|\\u\{[0-9a-fA-F]+\}|\\[0\\tnr"']|\\.)*?\\\(/,	false,	false),
	"singleLineStringLiteral":	("/\"(?!.*\\\\\\()(?:[^\"\\\\]|\\\\u\\{[0-9a-fA-F]+\\}|\\\\[0\\\\tnr\"\']|\\\\.)*\"/",	/"(?!.*\\\()(?:[^"\\]|\\u\{[0-9a-fA-F]+\}|\\[0\\tnr"']|\\.)*"/,	false,	false),
	"multilineStringLiteral":	("/\"\"\"(?!.*\\\\\\()(?:[^\\\\]|\\\\#*u\\{[0-9a-fA-F]+\\}|\\\\#*[0\\\\tnr\"\']|\\\\#*\\s*\\n|\\\\#*.)*\"\"\"/",	/"""(?!.*\\\()(?:[^\\]|\\#*u\{[0-9a-fA-F]+\}|\\#*[0\\tnr"']|\\#*\s*\n|\\#*.)*"""/,	false,	false),
	"extendedMultilineStringLiteral":	("/#+\"\"\"(?s).*?\"\"\"#+/",	/#+"""(?s).*?"""#+/,	false,	false),
	"interpolatedStringLiteralTail":	("/(?!.*\\\\\\()\\)(?:[^\"\\\\]|\\\\u\\{[0-9a-fA-F]+\\}|\\\\[0\\\\tnr\"\']|\\\\.)*?\"/",	/(?!.*\\\()\)(?:[^"\\]|\\u\{[0-9a-fA-F]+\}|\\[0\\tnr"']|\\.)*?"/,	false,	false),
	"parenthesisMode":	("parenthesisMode",	Regex { "parenthesisMode" },	true,	false),
	"expr":	("expr",	Regex { "expr" },	true,	false),
	"(":	("(",	Regex { "(" },	true,	false),
	")":	(")",	Regex { ")" },	true,	false),
	"interpolatedString":	("interpolatedString",	Regex { "interpolatedString" },	true,	false),
]
func expression() throws {
	switch token.kind {
	case "expr", "extendedMultilineStringLiteral", "extendedSinglelineStringLiteral", "interpolatedStringLiteralHead", "multilineStringLiteral", "singleLineStringLiteral":
		repeat {
			switch token.kind {
			case "expr":
				cI += 1
			case "extendedMultilineStringLiteral", "extendedSinglelineStringLiteral", "interpolatedStringLiteralHead", "multilineStringLiteral", "singleLineStringLiteral":
				try stringLiteral()
			default:
				expect("expr", "extendedMultilineStringLiteral", "extendedSinglelineStringLiteral", "interpolatedStringLiteralHead", "multilineStringLiteral", "singleLineStringLiteral")
			}
		} while ["expr", "extendedMultilineStringLiteral", "extendedSinglelineStringLiteral", "interpolatedStringLiteralHead", "multilineStringLiteral", "singleLineStringLiteral"].contains(token.kind)
	case "(":
		try parenthesizedExpression()
	default:
		expect("(", "expr", "extendedMultilineStringLiteral", "extendedSinglelineStringLiteral", "interpolatedStringLiteralHead", "multilineStringLiteral", "singleLineStringLiteral")
	}
}
func grammar() throws {
	while ["extendedMultilineStringLiteral", "extendedSinglelineStringLiteral", "interpolatedStringLiteralHead", "multilineStringLiteral", "singleLineStringLiteral"].contains(token.kind) {
		try stringLiteral()
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
func staticStringLiteral() throws {
	switch token.kind {
	case "singleLineStringLiteral":
		cI += 1
	case "extendedSinglelineStringLiteral":
		cI += 1
	case "multilineStringLiteral":
		cI += 1
	case "extendedMultilineStringLiteral":
		cI += 1
	default:
		expect("extendedMultilineStringLiteral", "extendedSinglelineStringLiteral", "multilineStringLiteral", "singleLineStringLiteral")
	}
}
func stringLiteral() throws {
	switch token.kind {
	case "extendedMultilineStringLiteral", "extendedSinglelineStringLiteral", "multilineStringLiteral", "singleLineStringLiteral":
		try staticStringLiteral()
	case "interpolatedStringLiteralHead":
		try interpolatedStringLiteral()
	default:
		expect("extendedMultilineStringLiteral", "extendedSinglelineStringLiteral", "interpolatedStringLiteralHead", "multilineStringLiteral", "singleLineStringLiteral")
	}
}
func parse() throws {
	try grammar()
	expect("$")
}
