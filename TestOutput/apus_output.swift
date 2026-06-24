
// MARK: - start of template code
import Foundation
import RegexBuilder

var tokens: [Token] = []
var trivia: [[Token]] = []
var cI = 0
var token: Token { tokens[cI] }

func lineBreakCountBetweenTokens(at first: Int, and second: Int) -> Int {
    guard let input = tokens[first].image.base else { return 0 }
    let span = input[tokens[first].image.startIndex..<tokens[second].image.startIndex]
    var breaks = 0
    var prevWasCR = false
    for ch in span {
        let isCR = ch == "\r"
        let isLF = ch == "\n"
        if isCR || (isLF && !prevWasCR) { breaks += 1 }
        prevWasCR = isCR
    }
    return breaks
}

func hasInterTokenGap(at first: Int, and second: Int) -> Bool {
    tokens[first].image.endIndex < tokens[second].image.startIndex
}

func boundary(_ kind: String) {
    guard cI > 0 && cI < tokens.count else {
        fatalError("boundary '\(kind)' cannot be evaluated at token index \(cI)")
    }
    let left = cI - 1
    let right = cI
    switch kind {
    case "<s>":
        if !hasInterTokenGap(at: left, and: right) {
            fatalError("expected spacing between tokens around '\(kind)'")
        }
    case "<n>":
        if lineBreakCountBetweenTokens(at: left, and: right) == 0 {
            fatalError("expected line break between tokens around '\(kind)'")
        }
    case ">s<":
        if hasInterTokenGap(at: left, and: right) {
            fatalError("expected adjacency between tokens around '\(kind)'")
        }
    case ">n<":
        if lineBreakCountBetweenTokens(at: left, and: right) > 0 {
            fatalError("expected same line between tokens around '\(kind)'")
        }
    default:
        fatalError("unknown boundary token '\(kind)'")
    }
}

func expect(_ expected: String...) {
    if !expected.contains(token.kind) {
        let position = token.image.base.linePosition(of: token.image.startIndex)
        fatalError("\(position): expected \(expected) but found \"\(token.kind)\"")
    }
}

// MARK: - start of generated code
let tokenPatterns: [String:TokenPattern] = [
	"comment":	("/\\/\\/.*/",	/\/\/.*/,	false,	true),
	"literal":	("/\\\"(?:[^\\\"\\\\]|\\\\.)+\\\"/",	/\"(?:[^\"\\]|\\.)+\"/,	false,	false),
	"whitespace":	("/\\s+/",	/\s+/,	false,	true),
	"regex":	("/\\/(?!\\*)(?:[^\\/\\\\]|\\\\.)+\\//",	/\/(?!\*)(?:[^\/\\]|\\.)+\//,	false,	false),
	"identifier":	("/\\p{XID_Start}\\p{XID_Continue}*/",	/\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"pragma":	("/@\\p{XID_Start}\\p{XID_Continue}*/",	/@\p{XID_Start}\p{XID_Continue}*/,	false,	false),
	"message":	("/\\^\\^\\^(?:(?s).*?)(?=\\^\\^\\^|$)/",	/\^\^\^(?:(?s).*?)(?=\^\^\^|$)/,	false,	false),
	"action":	("/\'(?:[^\'\\\\]|\\\\.)*\'/",	/'(?:[^'\\]|\\.)*'/,	false,	true),
	""-"":	("-",	Regex { "-" },	true,	false),
	"">n<"":	(">n<",	Regex { ">n<" },	true,	false),
	"":>"":	(":>",	Regex { ":>" },	true,	false),
	""}"":	("}",	Regex { "}" },	true,	false),
	""--1"":	("--1",	Regex { "--1" },	true,	false),
	""?"":	("?",	Regex { "?" },	true,	false),
	""{"":	("{",	Regex { "{" },	true,	false),
	""<"":	("<",	Regex { "<" },	true,	false),
	""ε"":	("ε",	Regex { "ε" },	true,	false),
	""*"":	("*",	Regex { "*" },	true,	false),
	"">s<"":	(">s<",	Regex { ">s<" },	true,	false),
	""["":	("[",	Regex { "[" },	true,	false),
	""+"":	("+",	Regex { "+" },	true,	false),
	""\"\""":	("\"\"",	Regex { "\"\"" },	true,	false),
	""|<<"":	("|<<",	Regex { "|<<" },	true,	false),
	""++2"":	("++2",	Regex { "++2" },	true,	false),
	""]"":	("]",	Regex { "]" },	true,	false),
	""--2"":	("--2",	Regex { "--2" },	true,	false),
	"":"":	(":",	Regex { ":" },	true,	false),
	""---"":	("---",	Regex { "---" },	true,	false),
	""++1"":	("++1",	Regex { "++1" },	true,	false),
	""<s>"":	("<s>",	Regex { "<s>" },	true,	false),
	""->"":	("->",	Regex { "->" },	true,	false),
	""|"":	("|",	Regex { "|" },	true,	false),
	"">"":	(">",	Regex { ">" },	true,	false),
	"")"":	(")",	Regex { ")" },	true,	false),
	""."":	(".",	Regex { "." },	true,	false),
	"">>|"":	(">>|",	Regex { ">>|" },	true,	false),
	""<n>"":	("<n>",	Regex { "<n>" },	true,	false),
	""("":	("(",	Regex { "(" },	true,	false),
]
func empty() throws {
	expect("\"\\\"\\\"\"")
	cI += 1
}
func epsilon() throws {
	expect("\"ε\"")
	cI += 1
}
func factor() throws {
	switch token.kind {
	case "\"\\\"\\\"\"", "\"ε\"", "identifier", "literal", "regex":
		try terminal()
	case "\"[\"":
		cI += 1
		try selection()
		expect("\"]\"")
		cI += 1
	case "\"{\"":
		cI += 1
		try selection()
		expect("\"}\"")
		cI += 1
	case "\"<\"":
		cI += 1
		try selection()
		expect("\">\"")
		cI += 1
	case "\"(\"":
		cI += 1
		try selection()
		expect("\")\"")
		cI += 1
	default:
		expect("\"(\"", "\"<\"", "\"[\"", "\"\\\"\\\"\"", "\"{\"", "\"ε\"", "identifier", "literal", "regex")
	}
}
func follow() throws {
	switch token.kind {
	case "\"++1\"":
		cI += 1
	case "\"++2\"":
		cI += 1
	case "\"--1\"":
		cI += 1
	case "\"--2\"":
		cI += 1
	default:
		expect("\"++1\"", "\"++2\"", "\"--1\"", "\"--2\"")
	}
	expect("\"(\"")
	cI += 1
	repeat {
		expect("literal")
		cI += 1
	} while ["literal"].contains(token.kind)
	expect("\")\"")
	cI += 1
}
func grammar() throws {
	repeat {
		try production()
	} while ["identifier", "pragma"].contains(token.kind)
	while ["message"].contains(token.kind) {
		cI += 1
	}
}
func layout() throws {
	switch token.kind {
	case "\">>|\"":
		cI += 1
	case "\"|<<\"":
		cI += 1
	case "\"<n>\"":
		cI += 1
	case "\"<s>\"":
		cI += 1
	case "\">n<\"":
		cI += 1
	case "\">s<\"":
		cI += 1
	default:
		expect("\"<n>\"", "\"<s>\"", "\">>|\"", "\">n<\"", "\">s<\"", "\"|<<\"")
	}
}
func production() throws {
	if ["pragma"].contains(token.kind) {
		cI += 1
	}
	expect("identifier")
	cI += 1
	switch token.kind {
	case "\":\"":
		cI += 1
		switch token.kind {
		case "regex":
			cI += 1
		case "literal":
			cI += 1
		default:
			expect("literal", "regex")
		}
		expect("\".\"")
		cI += 1
		if ["\"++1\"", "\"++2\"", "\"--1\"", "\"--2\""].contains(token.kind) {
			try follow()
		}
	case "\"-\"":
		cI += 1
		switch token.kind {
		case "regex":
			cI += 1
		case "literal":
			cI += 1
		default:
			expect("literal", "regex")
		}
		expect("\".\"")
		cI += 1
		if ["\"++1\"", "\"++2\"", "\"--1\"", "\"--2\""].contains(token.kind) {
			try follow()
		}
	case "\":>\"":
		cI += 1
		try selection()
		expect("\".\"")
		cI += 1
	case "\"->\"":
		cI += 1
		try selection()
		expect("\".\"")
		cI += 1
	default:
		expect("\"-\"", "\"->\"", "\":\"", "\":>\"")
	}
}
func selection() throws {
	try sequence()
	while ["\"|\""].contains(token.kind) {
		cI += 1
		try sequence()
	}
}
func sequence() throws {
	repeat {
		switch token.kind {
		case "\"<n>\"", "\"<s>\"", "\">>|\"", "\">n<\"", "\">s<\"", "\"|<<\"":
			try layout()
		case "\"(\"", "\"<\"", "\"[\"", "\"\\\"\\\"\"", "\"{\"", "\"ε\"", "identifier", "literal", "regex":
			try factor()
			switch token.kind {
			case "\"?\"":
				cI += 1
			case "\"*\"":
				cI += 1
			case "\"+\"":
				cI += 1
			default:
				break
			}
		default:
			expect("\"(\"", "\"<\"", "\"<n>\"", "\"<s>\"", "\">>|\"", "\">n<\"", "\">s<\"", "\"[\"", "\"\\\"\\\"\"", "\"{\"", "\"|<<\"", "\"ε\"", "identifier", "literal", "regex")
		}
	} while ["\"(\"", "\"<\"", "\"<n>\"", "\"<s>\"", "\">>|\"", "\">n<\"", "\">s<\"", "\"[\"", "\"\\\"\\\"\"", "\"{\"", "\"|<<\"", "\"ε\"", "identifier", "literal", "regex"].contains(token.kind)
}
func terminal() throws {
	switch token.kind {
	case "identifier":
		cI += 1
		if ["\"---\""].contains(token.kind) {
			cI += 1
			expect("\"(\"")
			cI += 1
			repeat {
				expect("literal")
				cI += 1
			} while ["literal"].contains(token.kind)
			expect("\")\"")
			cI += 1
		}
	case "literal":
		cI += 1
	case "regex":
		cI += 1
	case "\"ε\"":
		try epsilon()
	case "\"\\\"\\\"\"":
		try empty()
	default:
		expect("\"\\\"\\\"\"", "\"ε\"", "identifier", "literal", "regex")
	}
}
func parse() throws {
	try grammar()
	expect("$")
}
