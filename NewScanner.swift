//import Foundation
//import RegexBuilder
//
//enum TokenKind: String { case whitespace, singleline, multiline, identifier, literal ,regex, action, message, keyword }
//let silentTokens: Set<TokenKind> = [.whitespace, .singleline, .multiline, .action]
//struct Token {
//    var range: Range<String.Index>
//    var type: TokenKind
//    var image: String {
//        String(text[range])
//    }
//    var stripped: String {
//        switch type {
//        case .literal:
//            return String(image.dropFirst().dropLast())
//        case .regex:
//            return String(image.dropFirst().dropLast())
//        case .action:
//            return image.dropFirst().dropLast()
//                .replacingOccurrences(of: "\\@", with: "@")
//        case .message:
//            return image.dropFirst()
//                .replacingOccurrences(of: "\\¶", with: "¶")
//        default:
//            return image
//        }
//    }
//}
//
//let whitespaceRegex101 = /\s+/
//let whitespaceRegex = Regex {
//    OneOrMore {
//        .whitespace
//    }
//}
//let singleLineRegex101 = /\/\/.*/
//let singleLineRegex = Regex {
//    "//"
//    ZeroOrMore {
//        /./
//    }
//}
//let multiLineRegex101 = /\/\*(?s).*?\*\//
//let multiLineRegex = Regex {
//    "/*"
//    ZeroOrMore(.reluctant) {
//        .any
//    }
//    "*/"
//}
//// recommended ID syntax following https://unicode.org/reports/tr31/
//let identifierRegex101 = /\p{ID_Start}\p{ID_Continue}*/
//let identifierRegex = Regex {
//    #/\p{ID_Start}/#
//    ZeroOrMore {
//        #/\p{ID_Continue}/#
//    }
//}
//let literalRegex101 = /\"(?:[^\"\\]|\\.)*\"/
//let literalRegex = Regex {
//    "\""
//    ZeroOrMore {
//        ChoiceOf {
//            CharacterClass(.anyOf("\"\\").inverted)  // any character that is not a '"' or a backward slash '\'
//            /\\./                                   // a backward slash '\' followed by single character, to escape '"' or '\', but catches more than legal escapes
//        }
//    }
//    "\""
//}
//let regexRegex101 = /\/(?:[^\/\\]|\\.)*\//
//let regexRegex = Regex {
//    "/"
//    ZeroOrMore {
//        ChoiceOf {
//            CharacterClass(.anyOf("/\\").inverted)  // any character that is not a forward slash '/' or a backward slash '\'
//            /\\./                                   // a backward slash '\' followed by single character, to escape '/' or '\', but catches more than legal escapes
//        }
//    }
//    "/"
//}
//let actionRegex101 = /@(?:[^@\\]|\\.)*@/
//let actionRegex = Regex {
//    "@"
//    ZeroOrMore {
//        ChoiceOf {
//            CharacterClass(.anyOf("@\\").inverted)  // any character that is not a '@' or a backward slash '\'
//            /\\./                                   // a backward slash '\' followed by single character, to escape '@' or '\', but catches more than legal escapes
//        }
//    }
//    "@"
//}
//let messageRegex101 = /¶(?:[^¶\\]|\\.)*/
//let messageRegex = Regex {
//    "¶"
//    ZeroOrMore {
//        ChoiceOf {
//            CharacterClass(.anyOf("¶\\").inverted)  // any character that is not a '¶' or a backward slash '\'
//            /\\./                                   // a backward slash '\' followed by single character, to escape '¶' or '\', but catches more than legal escapes
//        }
//    }
//}
//let keywordRegex = Regex {
//    ChoiceOf {
//        "."
//        ";"
//        ":"
//        "="
//        "|"
//        "("
//        ")"
//        "["
//        "]"
//        "{"
//        "}"
//        "<"
//        ">"
//        ")?"
//        ")*"
//        ")+"
//    }
//}
//
//let text =
//#"""
//    whitespace  : /\s+/ .
//    singleLine  : /\/\/.*/ .
//    multiLine   : /\/\*(?s).*?\*\// .
//
//    identifier  = /[\p{L}\p{N}\p{Pc}]+/ .
//    literal     = /\"(?:[^\"\\]|\\.)*\"/ .
//    regex       = /\/(?:[^\/\\]|\\.)*\// .
//    action      = /@(?:[^@\\]|\\.)*@/ .
//    message     = /\¶(?:[^\¶\\]|\\.)*/ .
//
//    S     = { production } { input } .
//                  
//    input       = message               @let message = token.image@
//                                        @   .dropFirst()@
//                                        @   .dropLast()@
//                                        @messages.append(String(message))@
//                .
//    production  =                       @var node: Node@
//                                        @var muted = false@
//                                        @var terminalAlias: String?@
//                    identifier          @let nonTerminalName = token.image@
//                    ( ":"               @muted = true@
//                                        @terminalAlias = nonTerminalName@
//                        ( regex         @node = regular()@
//                        | literal       @node = literal()@
//                        )
//                    | "="               @muted = false@
//                        ( regex         @terminalAlias = nonTerminalName@
//                                        @node = regular()@
//                        | selection     @node = selection()@
//                        )
//                    )
//                                        @terminalAlias = nil@
//                    ( "." | ";" )
//                .
//    selection   =                       @var node: Node@
//                sequence                @node = sequence()@
//                { "|" sequence          @node = Node(.ALT(left: node, right: sequence()))@
//                } .
//    sequence    =                       @var node: Node@
//                @node = @ term          @node = term()@
//                { term                  @node = Node(.SEQ(head: node, tail: term()))@
//                } .
//    term        =                       @var node: Node@
//                (   terminal            @node = terminal()@
//                | "[" selection         @node = Node(.OPT(body: node))@
//                    "]"
//                | "{" selection         @node = Node(.REP(body: node))@
//                    "}"
//                | "<" selection         @node = Node(.SEQ(head: node,
//                                                          tail: Node(.REP(body: node))))@
//                    ">"
//                | "(" selection         @node = selection()@
//                    ( ")"
//                    | ")?"              @node = Node(.OPT(body: node))@
//                    | ")*"              @node = Node(.REP(body: node))@
//                    | ")+"              @node = Node(.SEQ(head: node,
//                                                                tail: Node(.REP(body: node))))@
//                    )
//                 ) .
//    terminal    = identifier            @node = Node(.NTM(name: token.image))@
//                | literal               @node = _literal()@
//                | action                @node = Node(.TRM(type: "action"))@
//                                        @actionList[node] = token.stripped@
//                .
//"""#
//
//let tokenizer = Regex {
//    ChoiceOf {
//        Capture { whitespaceRegex101 }
//        Capture { singleLineRegex101 }
//        Capture { multiLineRegex101 }
//        Capture { identifierRegex101 }
//        Capture { literalRegex101 }
//        Capture { regexRegex101 }
//        Capture { actionRegex101 }
//        Capture { messageRegex101 }
//        Capture { keywordRegex }
//    }
//}
//
//var tokens: [Token] = []
//
//func initScanner() {
//    for m in text.matches(of: tokenizer) {
//        var token = Token(range: m.0.startIndex ..< m.0.endIndex, type: .whitespace)
//        if m.1 != nil { token.type = .whitespace }
//        else if m.2 != nil { token.type = .singleline }
//        else if m.3 != nil { token.type = .multiline }
//        else if m.4 != nil { token.type = .identifier }
//        else if m.5 != nil { token.type = .literal }
//        else if m.6 != nil { token.type = .regex }
//        else if m.7 != nil { token.type = .action }
//        else if m.8 != nil { token.type = .message }
//        else if m.9 != nil { token.type = .keyword }
//        tokens.append(token)
//    }
//    var index = text.startIndex
//    for t in tokens {
//        if index != t.range.lowerBound {
//            print("ERROR", text[index ..< t.range.upperBound])
//        }
//        index = t.range.upperBound
//    }
//    if index != text.endIndex {
//        print("EOF ERROR", text[index ..< text.endIndex])
//    }
//}
//
//func next() {
//    while tokenIndex < tokens.count && silentTokens.contains(tokens[tokenIndex].type) {
//        tokenIndex += 1
//    }
//    if tokenIndex == tokens.count {
//        print("end of file reached")
//    } else {
//        token = tokens[tokenIndex]
//        tokenIndex += 1
//        print("next", token.image)
//    }
//}
//
//initScanner()
//var tokenIndex = 0
//var token = tokens[tokenIndex]
//for _ in 0...150 {
//    next()
//}
//
