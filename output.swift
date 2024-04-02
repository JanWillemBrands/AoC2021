//: start of template code
import Foundation
typealias TokenPattern = (image: String, regex: Bool, muted: Bool)
//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
    "singleLine":	(#"//.*"#,	true,	true),
    "whitespace":	(#"\s+"#,	true,	true),
    "multiLine":	(#"/\*(?s).*?\*/"#,	true,	true),
    "a":	("a",	false,	false),
    "b":	("b",	false,	false),
    "c":	("c",	false,	false),
    "d":	("d",	false,	false),
]
func S() {
    switch token.type {
    case "a":
        next()
        next()
        next()
    case "a":
        next()
        next()
        next()
    default:
        expect(["a"])
    }
    next()
}
func singleLine() {
    next()
}
func multiLine() {
    next()
}
func whitespace() {
    next()
}
