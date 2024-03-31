//: start of template code
import Foundation
typealias TokenPattern = (image: String, regular: Bool, muted: Bool)
//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
    "singleLine":	(#"//.*"#,	true,	true),
    "whitespace":	(#"\s+"#,	true,	true),
    "multiLine":	(#"(?s)(/\*).*?(\*/)"#,	true,	true),
    "literal":	(#"\"(\\"|[^\"]+?)*\""#,	true,	false),
    "message":	(#"\¶(\\\¶|[^\¶])+"#,	true,	false),
    "regular":	(#"'(\\'|[^']+?)*'"#,	true,	false),
    "action":	(#"@(\\@|[^@]+?)*@"#,	true,	false),
    "name":	(#"[\p{L}\p{N}\p{Pc}]+"#,	true,	false),
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
func term() {
    switch token.type {
    case "literal", "name", "action":
        terminal()
    case "[":
        next()
        selection()
        next()
    case "{":
        next()
        selection()
        next()
    case "<":
        next()
        selection()
        next()
    case "(":
        next()
        selection()
        switch token.type {
        case ")":
            next()
        case ")?":
            next()
        case ")*":
            next()
        case ")+":
            next()
        default:
            expect([")", ")*", ")?", ")+"])
        }
    default:
        expect(["action", "{", "literal", "name", "(", "[", "<"])
    }
}
func literal() {
    next()
}
func multiLine() {
    next()
}
func regular() {
    next()
}
func terminal() {
    switch token.type {
    case "name":
        name()
    case "literal":
        literal()
    case "action":
        action()
    default:
        expect(["literal", "name", "action"])
    }
}
func action() {
    next()
}
func S() {
    while ["name"].contains(token.type) {
        production()
    }
    while ["message"].contains(token.type) {
        input()
    }
}
func input() {
    message()
}
func whitespace() {
    next()
}
func singleLine() {
    next()
}
func message() {
    next()
}
func sequence() {
    term()
    while ["action", "{", "literal", "name", "(", "[", "<"].contains(token.type) {
        term()
    }
}
func production() {
    name()
    switch token.type {
    case ":":
        next()
        switch token.type {
        case "regular":
            regular()
        case "literal":
            literal()
        default:
            expect(["literal", "regular"])
        }
    case "=":
        next()
        switch token.type {
        case "regular":
            regular()
        case "action", "{", "literal", "name", "(", "[", "<":
            selection()
        default:
            expect(["[", "<", "{", "action", "regular", "literal", "(", "name"])
        }
    default:
        expect([":", "="])
    }
    switch token.type {
    case ".":
        next()
    case ";":
        next()
    default:
        expect([".", ";"])
    }
}
func name() {
    next()
}
func selection() {
    sequence()
    while ["|"].contains(token.type) {
        next()
        sequence()
    }
}
