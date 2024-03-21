//: start of template code
import Foundation
typealias TokenPattern = (image: String, regular: Bool, muted: Bool)
//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
    "whitespace":	(#"\s+"#,	true,	true),
    "a":	("a",	false,	false),
    "b":	("b",	false,	false),
    "d":	("d",	false,	false),
]
func whitespace() {
    next()
}
func S() {
    switch token.type {
    case "a":
        next()
        S()
        next()
    case "a":
        next()
        S()
        next()
    case "a":
        next()
    default:
        expect(["a"])
    }
}
