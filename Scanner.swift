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

typealias TokenPattern = (source: String, regex: Regex<Substring>, isKeyword: Bool, isSkip: Bool, mode: Mode)

struct Mode: CustomStringConvertible {
    var modeName = ""
    var pushName = ""
    var isPop = false
    
    var description: String {
        var d = ""
        if !modeName.isEmpty {
            d += "=== \(modeName) "
        }
        if !pushName.isEmpty {
            d += ">>> \(pushName)"
        }
        if isPop {
            d += "<<<"
        }
        return d
    }
}

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
private struct Pattern {
    let kind: String      // also the exact literal string to match
    let regex: Regex<Substring>
    let isKeyword: Bool
    let isSkip: Bool
    let mode: Mode
}

/// Scanner takes an input string and token patterns, and produces a token array.
/// One instance per scan — no shared mutable state.
/// Literal keywords are matched via hasPrefix; only true regex patterns use the regex engine.
final class Scanner {
    
    let input: String
    var tokens: [Token] = []                // visible tokens can be referenced in the grammar production rules
    var skippedTokens: [[Token]] = [[]]     // skipped tokens are stored as lists in an array indexed by the visible token following them
    
    var modeStack: [String] = []
    var currentMode: String {
        modeStack.last ?? ""
    }
    
    private var literalPatterns: [Pattern] = []
    private var regexPatterns: [Pattern] = []
    
    init(fromString inputString: String, patterns: [String: TokenPattern]) throws {
        self.input = inputString
        
        // Partition: literal keywords use fast hasPrefix, the rest use regex engine.
        // A keyword is a true literal if the image string matches exactly the kind string.
        for (kind, pattern) in patterns {
            if pattern.isKeyword && kind == pattern.source {
                //                if pattern.isKeyword, let m = kind.prefixMatch(of: pattern.regex), m.0 == kind[...] {
                literalPatterns.append(Pattern(kind: kind, regex: pattern.regex, isKeyword: pattern.isKeyword, isSkip: pattern.isSkip, mode: pattern.mode))
            } else {
                regexPatterns.append(Pattern(kind: kind, regex: pattern.regex, isKeyword: pattern.isKeyword, isSkip: pattern.isSkip, mode: pattern.mode))
            }
        }
        
        try scanAllTokens()
    }
    
    private func scanAllTokens() throws {
        var matchStart = input.startIndex
        while matchStart != input.endIndex {
            var headMatchIsSkip = true  // TODO: get rid of this, use headMatchPattern.isKip instead
            var headMatchPattern: Pattern!      // sentinel
            var matchEnd = matchStart
            var headMatch: Token?                // the highest priority match is at the head of the linked list of Schrödinger tokens
            var tailMatch: Token?                // the lowest priority match is at the end of the linked list
            let remaining = input[matchStart...]
            
            // Phase 1: literal keywords via hasPrefix (fast string comparison)
            for lp in literalPatterns {
                
                guard lp.mode.modeName == "" || lp.mode.modeName == currentMode else { continue }     // only attempt to match if the patternMode is default or an exact match

                if remaining.hasPrefix(lp.kind) {
                    let literalEnd = input.index(matchStart, offsetBy: lp.kind.count)
                    if literalEnd > matchEnd {
                        // the match is longer than any so far
                        matchEnd = literalEnd
                        headMatch = Token(image: input[matchStart..<literalEnd], kind: lp.kind)
                        tailMatch = headMatch
                        headMatchPattern = lp
                        headMatchIsSkip = lp.isSkip
                    } else if literalEnd == matchEnd {
                        // TODO: check that Schrödinger tokens all have the same push/popmode annotation

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
                            headMatchPattern = lp
                            headMatchIsSkip = lp.isSkip
                        }
//                        Logger.scan.debug("Schrödinger strikes again! \(headMatch!)")
//                        #Trace("Schrödinger strikes again! \(headMatch!)")
                    }
                }
            }
            
            // Phase 2: regex patterns via prefixMatch (regex engine)
            for rp in regexPatterns {
                
                guard rp.mode.modeName == "" || rp.mode.modeName == currentMode else { continue }     // only attempt to match if the patternMode is default or an exact match

                if let match = remaining.prefixMatch(of: rp.regex) {
                    if match.0.endIndex > matchEnd {
                        // the match is longer than any other match so far
                        matchEnd = match.0.endIndex
                        headMatch = Token(image: match.0, kind: rp.kind)
                        tailMatch = headMatch
                        headMatchPattern = rp
                        headMatchIsSkip = rp.isSkip
                    } else if match.0.endIndex == matchEnd {
                        // the match is the same length as a previous match
                        // TODO: check that Schrödinger tokens all have the same mode annotation

                        if rp.isKeyword && !rp.isSkip {
                            // visible keyword Schrödinger token goes to the front
                            let old = headMatch
                            headMatch = Token(image: match.0, kind: rp.kind)
                            headMatch?.dual = old
                            headMatchPattern = rp
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
                    Logger.scan.debug("adding token: \(headMatch) image: '\(headMatch.image)' \(headMatchPattern.mode)")
                    tokens.append(headMatch)
                    skippedTokens.append([])
                }
                matchStart = matchEnd
                if headMatchPattern.mode.isPop {
                    if let _ = modeStack.popLast() {
                        Logger.scan.debug("popped into new scan mode: \(self.currentMode)")
                    } else {
                        Logger.scan.error("too many pops from mode stack!")
                        exit(1)
                    }
                } else if headMatchPattern.mode.pushName != "" {
                    modeStack.append(headMatchPattern.mode.pushName)
                    Logger.scan.debug("pushed new scan mode: \(self.currentMode)")
                }
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
        var error = "scan error: input characters at position \(input.linePosition(of: position)) do not match any symbol in the grammar\n"
        let lineRange = input.lineRange(for: position ..< input.index(after: position))
        error += input[lineRange]
        let before = lineRange.lowerBound ..< position
        for _ in 0 ..< input[before].count {
            error += " "
        }
        error += "^~~~~~~~"
        Logger.scan.error("\(error)")
        throw ScannerFailure.charactersDoNotMatchAnySymbol(position: position, input: input)
    }
}
