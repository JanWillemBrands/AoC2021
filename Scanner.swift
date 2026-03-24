//
//  Scanner.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

// TODO: explicit matching rules e.g. -\- any, regex101 not preceed or follow <<!  !>>, or exclude "\" not preceded "-/-" not followed "-\-"

import Foundation
import RegexBuilder
import AdventMacros

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

/// A literal keyword pattern matched via hasPrefix (no regex engine needed).
private struct LiteralPattern {
    let kind: String
    let literal: String
    let isSkip: Bool
}

/// A regex pattern matched via prefixMatch (requires the regex engine).
private struct RegexPattern {
    let kind: String
    let regex: Regex<Substring>
    let isKeyword: Bool
    let isSkip: Bool
}

/// Scanner takes an input string and token patterns, and produces a token array.
/// One instance per scan — no shared mutable state.
/// Literal keywords are matched via hasPrefix; only true regex patterns use the regex engine.
public final class Scanner {
    
    public let input: String
    private let literalPatterns: [LiteralPattern]
    private let regexPatterns: [RegexPattern]
    
    public init(fromString inputString: String, patterns: [String: TokenPattern]) throws {
        self.input = inputString
        
        // Partition: isKeyword patterns use fast hasPrefix, the rest use regex engine.
        var literals: [LiteralPattern] = []
        var regexes: [RegexPattern] = []
        for (kind, pattern) in patterns {
            if pattern.isKeyword {
                literals.append(LiteralPattern(kind: kind, literal: kind, isSkip: pattern.isSkip))
            } else {
                regexes.append(RegexPattern(kind: kind, regex: pattern.regex, isKeyword: false, isSkip: pattern.isSkip))
            }
        }
        self.literalPatterns = literals
        self.regexPatterns = regexes
        
        try scanAllTokens()
    }

    public private(set) var tokens: [Token] = []

    private func scanAllTokens() throws {
        var matchStart = input.startIndex
        while matchStart != input.endIndex {
            var skip = true
            var matchEnd = matchStart
            var headMatch: Token?                // stores the most common match
            var tailMatch: Token?                // tracks any subsequent matches for Schrödinger tokens
            let remaining = input[matchStart...]
            
            // Phase 1: literal keywords via hasPrefix (fast string comparison)
            for lp in literalPatterns {
                if remaining.hasPrefix(lp.literal) {
                    let literalEnd = input.index(matchStart, offsetBy: lp.literal.count)
                    if literalEnd > matchEnd {
                        matchEnd = literalEnd
                        headMatch = Token(image: input[matchStart..<literalEnd], kind: lp.kind)
                        tailMatch = headMatch
                        skip = lp.isSkip
                    } else if literalEnd == matchEnd {
                        // Schrödinger token: keyword goes to front
                        let oldHead = headMatch
                        headMatch = Token(image: input[matchStart..<literalEnd], kind: lp.kind)
                        headMatch?.dual = oldHead
                    }
                }
            }
            
            // Phase 2: regex patterns via prefixMatch (regex engine)
            for rp in regexPatterns {
                if let match = remaining.prefixMatch(of: rp.regex) {
                    if match.0.endIndex > matchEnd {
                        matchEnd = match.0.endIndex
                        headMatch = Token(image: match.0, kind: rp.kind)
                        tailMatch = headMatch
                        skip = rp.isSkip
                    } else if match.0.endIndex == matchEnd {
                        if rp.isKeyword {
                            let oldHead = headMatch
                            headMatch = Token(image: match.0, kind: rp.kind)
                            headMatch?.dual = oldHead
                        } else {
                            tailMatch?.dual = Token(image: match.0, kind: rp.kind)
                            tailMatch = tailMatch?.dual
                        }
                        #Trace("Schrödinger strikes again! \(headMatch!)")
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
        #Trace("scan error: input characters do not match any symbol in the grammar")
        let lineRange = input.lineRange(for: position ..< input.index(after: position))
        #Trace(input[lineRange], terminator: "")
        let before = lineRange.lowerBound ..< position
        for _ in 0 ..< input[before].count {
            #Trace(" ", terminator: "")
        }
        #Trace("^~~~~~~~")
        throw ScannerFailure.charactersDoNotMatchAnySymbol(position: position, input: input)
    }
}
