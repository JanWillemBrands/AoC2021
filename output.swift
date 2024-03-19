//: start of template code
import Foundation
typealias TokenPattern = (image: String, regular: Bool, muted: Bool)
//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
    "identifier":	(#"[\p{L}\p{N}\p{Pc}]+"#,	true,	false),
    "singleLine":	(#"//.*"#,	true,	true),
    "whitespace":	(#"\s+"#,	true,	true),
    "multiLine":	(#"(?s)(/\*).*?(\*/)"#,	true,	true),
    "testInput":	(#"\¶(\\\¶|[^\¶])+"#,	true,	false),
    "keyword":	(#"\"(\\"|[^\"]+?)*\""#,	true,	false),
    "action":	(#"@(\\@|[^@]+?)*@"#,	true,	false),
    "regex":	(#"'(\\'|[^']+?)*'"#,	true,	false),
    ")*":	(")*",	false,	false),
    ")+":	(")+",	false,	false),
    ")?":	(")?",	false,	false),
    "(":	("(",	false,	false),
    ")":	(")",	false,	false),
    ".":	(".",	false,	false),
    ":":	(":",	false,	false),
    ";":	(";",	false,	false),
    "<":	("<",	false,	false),
    "=":	("=",	false,	false),
    ">":	(">",	false,	false),
    "[":	("[",	false,	false),
    "]":	("]",	false,	false),
    "{":	("{",	false,	false),
    "|":	("|",	false,	false),
    "}":	("}",	false,	false),
]
func rule() {
    identifier()
    next()
    switch token.type {
    case "regex":
        regex()
    case "<", "{", "[", "keyword", "identifier", "(", "action":
        selection()
    default:
        expect(["identifier", "keyword", "{", "<", "regex", "(", "[", "action"])
    }
    switch token.type {
    case ".":
        next()
    case ";":
        next()
    default:
        expect([";", "."])
    }
}
func whitespace() {
    next()
}
func singleLine() {
    next()
}
func oneOrMore() {
    switch token.type {
    case "(":
        next()
        selection()
        next()
    case "<":
        next()
        selection()
        next()
    default:
        expect(["<", "("])
    }
}
func grouping() {
    next()
    selection()
    next()
}
func production() {
    switch token.type {
    case "identifier":
        rule()
    case "identifier":
        silentRule()
    default:
        expect(["identifier"])
    }
}
func term() {
    switch token.type {
    case "action", "keyword", "identifier":
        terminal()
    case "[", "(":
        option()
    case "{", "(":
        zeroOrMore()
    case "<", "(":
        oneOrMore()
    case "(":
        grouping()
    default:
        expect(["<", "{", "[", "keyword", "identifier", "(", "action"])
    }
}
func regex() {
    next()
}
func S() {
    while ["identifier"].contains(token.type) {
        production()
    }
    while ["testInput"].contains(token.type) {
        testInput()
    }
}
func silentRule() {
    identifier()
    next()
    switch token.type {
    case "regex":
        regex()
    case "keyword":
        keyword()
    default:
        expect(["regex", "keyword"])
    }
    switch token.type {
    case ".":
        next()
    case ";":
        next()
    default:
        expect([";", "."])
    }
}
func multiLine() {
    next()
}
func keyword() {
    next()
}
func sequence() {
    term()
    while ["<", "{", "[", "keyword", "identifier", "(", "action"].contains(token.type) {
        term()
    }
}
func action() {
    next()
}
func selection() {
    sequence()
    while ["|"].contains(token.type) {
        next()
        sequence()
    }
}
func zeroOrMore() {
    switch token.type {
    case "(":
        next()
        selection()
        next()
    case "{":
        next()
        selection()
        next()
    default:
        expect(["{", "("])
    }
}
func option() {
    switch token.type {
    case "(":
        next()
        selection()
        next()
    case "[":
        next()
        selection()
        next()
    default:
        expect(["[", "("])
    }
}
func terminal() {
    switch token.type {
    case "identifier":
        identifier()
    case "keyword":
        keyword()
    case "action":
        action()
    default:
        expect(["action", "keyword", "identifier"])
    }
}
func identifier() {
    next()
}
func testInput() {
    next()
}
