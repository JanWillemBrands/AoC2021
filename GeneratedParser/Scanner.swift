//
//  Scanner.swift
//  GeneratedParser
//

import Foundation
import RegexBuilder

enum ScannerFailure: Error {
    case charactersDoNotMatchAnySymbol(position: String.Index, input: String)
}

typealias TokenPattern = (source: String, regex: Regex<Substring>, isLiteral: Bool, isSkip: Bool)

final class Token: CustomStringConvertible {
    var image: Substring
    var kind: String
    var dual: Token?

    init(image: Substring, kind: String) {
        self.image = image
        self.kind = kind
    }

    var stripped: String {
        switch kind {
        case "literal":
            return String(image.dropFirst().dropLast())
        case "regex":
            return String(image.dropFirst().dropLast())
        case "action":
            return image.dropFirst().dropLast()
                .replacingOccurrences(of: "\\@", with: "@")
        case "message":
            return String(image.dropFirst(3))
        default:
            return String(image)
        }
    }

    var description: String {
        if let dual {
            return kind + " " + dual.description
        }
        return kind
    }
}

/// Scanner takes an input string and token patterns, and produces a token array.
final class Scanner {

    let input: String
    private let tokenPatterns: [String: TokenPattern]

    init(fromString inputString: String, patterns: [String: TokenPattern]) throws {
        self.input = inputString
        self.tokenPatterns = patterns
        try scanAllTokens()
    }

    private(set) var tokens: [Token] = []

    private func scanAllTokens() throws {
        var matchStart = input.startIndex
        while matchStart != input.endIndex {
            var skip = true
            var matchEnd = matchStart
            var headMatch: Token?
            var tailMatch: Token?
            for (kind, pattern) in tokenPatterns {
                if let match = input[matchStart...].prefixMatch(of: pattern.regex) {
                    if match.0.endIndex > matchEnd {
                        matchEnd = match.0.endIndex
                        headMatch = Token(image: match.0, kind: kind)
                        tailMatch = headMatch
                        skip = pattern.isSkip
                    } else if match.0.endIndex == matchEnd {
                        if pattern.isLiteral {
                            let oldHead = headMatch
                            headMatch = Token(image: match.0, kind: kind)
                            headMatch?.dual = oldHead
                        } else {
                            tailMatch?.dual = Token(image: match.0, kind: kind)
                            tailMatch = tailMatch?.dual
                        }
                    }
                }
            }
            if let headMatch {
                if !skip || headMatch.dual != nil {
                    tokens.append(headMatch)
                }
                matchStart = matchEnd
            } else {
                try scanError(position: matchStart)
            }
        }
        let end = input.endIndex
        tokens.append(Token(image: input[end..<end], kind: "$"))
    }

    private func scanError(position: String.Index) throws -> Never {
        let lineRange = input.lineRange(for: position ..< input.index(after: position))
        let before = lineRange.lowerBound ..< position
        let pos = input.linePosition(of: position)
        print("scan error at \(pos): characters do not match any symbol")
        print(input[lineRange], terminator: "")
        for _ in 0 ..< input[before].count {
            print(" ", terminator: "")
        }
        print("^~~~~~~~")
        throw ScannerFailure.charactersDoNotMatchAnySymbol(position: position, input: input)
    }
}

extension String {
    func linePosition(of index: String.Index) -> String {
        var line = 0
        var lineStart = self.startIndex
        while let match = self[lineStart ..< index].firstIndex(of: "\n") {
            line += 1
            lineStart = self.index(match, offsetBy: 1)
        }
        let position = self.distance(from: lineStart, to: index)
        return "L\(line)P\(position)"
    }
}
