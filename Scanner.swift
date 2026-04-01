//
//  Scanner.swift
//  Advent
//
//  Created by Johannes Brands on 01/03/2024.
//

// TODO: explicit matching rules e.g. -\- any, regex101 not preceed or follow <<!  !>>, or exclude "\" not preceded "-/-" not followed "-\-"

import OSLog
import Foundation
import AdventMacros

enum ScannerFailure: Error {
    case charactersDoNotMatchAnySymbol(position: String.Index, input: String)
    case couldNotReadFile
}

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool)

final class Token: CustomStringConvertible {
    var image: Substring
    var kind: String
    /// Integer ID from `Grammar.symbolToID`, assigned by `MessageParser.parse(tokens:)`
    /// before the GLL algorithm runs. Enables O(1) integer comparison in `tokenMatch()`
    /// and O(1) BitSet membership tests in `testSelect()`.
    var kindID: Int!
    var dual: Token?                            // multiple regex matches of equal length create a 'Schrödinger' token linked list
    
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
        let idStr = kindID.map(String.init) ?? "?"
        if let dual {
            return "'" + kind + "':" + idStr + " ~ " + dual.description
        }
        return "'" + kind + "':" + idStr
    }
}

/// A literal keyword pattern matched via hasPrefix (no regex engine needed).
private struct LiteralPattern {
    let kind: String      // also the exact literal string to match
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
final class Scanner {
    
    let input: String
    var tokens: [Token] = []                // the visible tokens referenced in the grammar production rules
    var skippedTokens: [[Token]] = [[]]     // the skipped tokens e.g. whitespace and comment.
    // These are stored as lists in an array indexed by the token immediately following them.
    
    private let literalPatterns: [LiteralPattern]
    private let regexPatterns: [RegexPattern]
    
    init(fromString inputString: String, patterns: [String: TokenPattern]) throws {
        self.input = inputString
        
        // Partition: literal keywords use fast hasPrefix, the rest use regex engine.
        // A keyword is a true literal if the image string matches exactly the kind string.
        var literals: [LiteralPattern] = []
        var regexes: [RegexPattern] = []
        for (kind, pattern) in patterns {
            if pattern.isKeyword && kind == pattern.source {
                //                if pattern.isKeyword, let m = kind.prefixMatch(of: pattern.regex), m.0 == kind[...] {
                literals.append(LiteralPattern(kind: kind, isSkip: pattern.isSkip))
            } else {
                regexes.append(RegexPattern(kind: kind, regex: pattern.regex, isKeyword: pattern.isKeyword, isSkip: pattern.isSkip))
            }
        }
        self.literalPatterns = literals
        self.regexPatterns = regexes
        
        try scanAllTokens()
    }
    
    private func scanAllTokens() throws {
        var matchStart = input.startIndex
        while matchStart != input.endIndex {
            var headMatchIsSkip = true
            var matchEnd = matchStart
            var headMatch: Token?                // the highest priority match is at the head of the linked list of Schrödinger tokens
            var tailMatch: Token?                // the lowest priority match is at the end of the linked list
            let remaining = input[matchStart...]
            
            // Phase 1: literal keywords via hasPrefix (fast string comparison)
            for lp in literalPatterns {
                if remaining.hasPrefix(lp.kind) {
                    let literalEnd = input.index(matchStart, offsetBy: lp.kind.count)
                    if literalEnd > matchEnd {
                        // the match is longer than any so far
                        matchEnd = literalEnd
                        headMatch = Token(image: input[matchStart..<literalEnd], kind: lp.kind)
                        tailMatch = headMatch
                        headMatchIsSkip = lp.isSkip
                    } else if literalEnd == matchEnd {
                        // the match is the same length as a previous match
                        if lp.isSkip {
                            // Schrödinger token goes to the back
                            tailMatch?.dual = Token(image: input[matchStart..<literalEnd], kind: lp.kind)
                            tailMatch = tailMatch?.dual
                        } else {
                            // Schrödinger token goes to the front
                            let old = headMatch
                            headMatch = Token(image: input[matchStart..<literalEnd], kind: lp.kind)
                            headMatch?.dual = old
                            headMatchIsSkip = lp.isSkip
                        }
//                        Logger.scan.debug("Schrödinger strikes again! \(headMatch!)")
//                        #Trace("Schrödinger strikes again! \(headMatch!)")
                    }
                }
            }
            
            // Phase 2: regex patterns via prefixMatch (regex engine)
            for rp in regexPatterns {
                if let match = remaining.prefixMatch(of: rp.regex) {
                    if match.0.endIndex > matchEnd {
                        // the match is longer than any so far
                        matchEnd = match.0.endIndex
                        headMatch = Token(image: match.0, kind: rp.kind)
                        tailMatch = headMatch
                        headMatchIsSkip = rp.isSkip
                    } else if match.0.endIndex == matchEnd {
                        // the match is the same length as a previous match
                        if rp.isKeyword && !rp.isSkip {
                            // visible keyword Schrödinger token goes to the front
                            let old = headMatch
                            headMatch = Token(image: match.0, kind: rp.kind)
                            headMatch?.dual = old
                            headMatchIsSkip = rp.isSkip
                        } else {
                            // skip or non-keyword Schrödinger token goes to the back
                            tailMatch?.dual = Token(image: match.0, kind: rp.kind)
                            tailMatch = tailMatch?.dual
                        }
//                        Logger.scan.debug("Schrödinger strikes again! \(headMatch!)")
//                        #Trace("Schrödinger strikes again! \(headMatch!)")
                    }
                }
            }
            
            if let headMatch {
                if headMatchIsSkip {
                    skippedTokens[tokens.count].append(headMatch)
                } else {
                    tokens.append(headMatch)
                    skippedTokens.append([])
                }
                matchStart = matchEnd
            } else {
                try scanError(position: matchStart)
            }
        }
        // append EndOfString token
        tokens.append(Token(image: "$", kind: "$"))
//        Logger.scan.debug("tokens: \(self.tokens)")
//        Logger.scan.debug("skipped tokens: \(self.skippedTokens)")
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
