//: start of template code
import Foundation
typealias TokenPattern = (image: String, regular: Bool, muted: Bool)
//: start of generated code
let tokenPatterns: [String:TokenPattern] = [
    "whitespace":	(#"\s+"#,	true,	true),
    "x":	("x",	false,	false),
]
func S() {
    next()
    if ["x"].contains(token.type) {
        next()
    }
}
func whitespace() {
    next()
}
