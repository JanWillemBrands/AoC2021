//
//  Scanner.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

// TODO: explicit matching rules e.g. -\- any, regex101 not preceed or follow <<!  !>>, or exclude "\" not preceded "-/-" not followed "-\-"
// TODO: change to character-level scanner
// let s = CharacterSet.alphanumerics.union(CharacterSet.capitalizedLetters)

import Foundation
import RegexBuilder

public enum ScannerFailure: Error { 
    case charactersDoNotMatchAnySymbol(position: String.Index, input: String)
    case couldNotReadFile 
}

public typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)
    
public final class Token: CustomStringConvertible {
    public var image: Substring
    public var kind: String
    public var dual: Token?                            // multiple regex matches of equal length create a 'Schrödinger' token linked list

    public init(image: Substring, kind: String) {
        self.image = image
        self.kind = kind
    }

    public var stripped: String {
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

    public var description: String {
        if let dual {
            return kind + " " + dual.description
        }
        return kind
    }
}

/// Scanner takes an input string and token patterns, and produces a token array.
/// One instance per scan — no shared mutable state.
public final class Scanner {
    
    public let input: String
    private let tokenPatterns: [String: TokenPattern]
    
    public init(fromString inputString: String, patterns: [String: TokenPattern]) throws {
        self.input = inputString
        self.tokenPatterns = patterns
        try scanAllTokens()
    }

    public private(set) var tokens: [Token] = []

    private func scanAllTokens() throws {
        var matchStart = input.startIndex
        while matchStart != input.endIndex {
            var skip = true
            var matchEnd = matchStart
            var headMatch: Token?                // stores the most common match
            var tailMatch: Token?                // tracks any subsequent matches for Scrödinger tokens
            for (kind, pattern) in tokenPatterns {
                if let match = input[matchStart...].prefixMatch(of: pattern.regex) {
                    if match.0.endIndex > matchEnd {
                        // longest match always wins
                        matchEnd = match.0.endIndex
                        headMatch = Token(image: match.0, kind: kind)
                        tailMatch = headMatch
                        skip = pattern.isSkip
                    } else if match.0.endIndex == matchEnd {
                        if pattern.isKeyword {
                            // insert the new match at the front of the list to optimize parsing of keywords
                            let oldHead = headMatch
                            headMatch = Token(image: match.0, kind: kind)
                            headMatch?.dual = oldHead
                        } else {
                            // append the new match to the end of the list
                            tailMatch?.dual = Token(image: match.0, kind: kind)
                            tailMatch = tailMatch?.dual
                        }
                        #if DEBUG
                        trace("Schrödinger strikes again! \(headMatch!)")
                        #endif
                    }
                }
            }
            if let headMatch {
                if !skip || headMatch.dual != nil {     // add non-skip or Schrödinger tokens
                    tokens.append(headMatch)
                }
                matchStart = matchEnd
            } else {
                try scanError(position: matchStart)
            }
        }
        // append EndOfString token
        // TODO: re-implement tokenKind as an Int, with 0 as EndOfString
        tokens.append(Token(image: "$", kind: "$"))
    }
    
    // TODO: use https://developer.apple.com/documentation/foundation/nsregularexpression/1408386-escapedpattern
    
    private func scanError(position: String.Index) throws -> Never {
        trace("scan error: input characters do not match any symbol in the grammar")
        let lineRange = input.lineRange(for: position ..< input.index(after: position))
        trace(input[lineRange], terminator: "")
        let before = lineRange.lowerBound ..< position
        for _ in 0 ..< input[before].count {
            trace(" ", terminator: "")
        }
        trace("^~~~~~~~")
        throw ScannerFailure.charactersDoNotMatchAnySymbol(position: position, input: input)
    }
}
