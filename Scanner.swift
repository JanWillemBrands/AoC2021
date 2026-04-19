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
    var modeName = ""   // only scan this tokenpattern when scannerMode == modeName
    var pushName = ""   //
    var isPop = false
    
    var isActive: Bool {
        !modeName.isEmpty || !pushName.isEmpty || isPop
    }
    
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

private struct Pattern {
    let kind: String
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
    var tokens: [Token] = []                // normal, visible tokens that can be referenced in the grammar production rules
    var trivia: [[Token]] = [[]]            // skipped tokens are stored as lists in an array indexed by the visible token following them
    
    private var modeStack: [String] = []    // tracks state to allow e.g. nested token construction
    private var scannerMode: String {       // isolated to the scanner, not driven by the parser
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
                literalPatterns.append(Pattern(kind: kind, regex: pattern.regex, isKeyword: pattern.isKeyword, isSkip: pattern.isSkip, mode: pattern.mode))
            } else {
                regexPatterns.append(Pattern(kind: kind, regex: pattern.regex, isKeyword: pattern.isKeyword, isSkip: pattern.isSkip, mode: pattern.mode))
            }
        }
        
        try scanAllTokens()
    }
    
    private struct Candidate {
        let token: Token
        let pattern: Pattern
    }

    private func scanAllTokens() throws {
        var matchStart = input.startIndex

        while matchStart != input.endIndex {
            var matchEnd = matchStart
            var candidates: [Candidate] = []
            let remaining = input[matchStart...]

            // Phase 1: literal keywords via hasPrefix (fast string comparison)
            for lp in literalPatterns {
                guard lp.mode.modeName == "" || lp.mode.modeName == scannerMode else { continue }

                if remaining.hasPrefix(lp.kind) {
                    let literalEnd = input.index(matchStart, offsetBy: lp.kind.count)
                    if literalEnd > matchEnd {
                        matchEnd = literalEnd
                        candidates.removeAll()
                    }
                    // TODO: there can never be more than one literal in a Schrödinger token ???
                   if literalEnd == matchEnd {
                        candidates.append(Candidate(
                            token: Token(image: input[matchStart..<literalEnd], kind: lp.kind),
                            pattern: lp))
                    }
                }
            }

            // Phase 2: regex patterns via prefixMatch (regex engine)
            for rp in regexPatterns {
                guard rp.mode.modeName == "" || rp.mode.modeName == scannerMode else { continue }

                if let match = remaining.prefixMatch(of: rp.regex) {
                    if match.0.endIndex > matchEnd {
                        matchEnd = match.0.endIndex
                        candidates.removeAll()
                    }
                    if match.0.endIndex == matchEnd {
                        candidates.append(Candidate(
                            token: Token(image: match.0, kind: rp.kind),
                            pattern: rp))
                    }
                }
            }

            // Phase 3: resolve candidates — mode-active patterns suppress Schrödinger duals
            guard !candidates.isEmpty else {
                try scanError(position: matchStart)
            }

            let modeActive = candidates.filter { $0.pattern.mode.isActive }

            let headMatch: Token
            let headPattern: Pattern

            if let winner = modeActive.first {
                // Mode-active pattern wins, no Schrödinger duals
                if modeActive.count > 1 {
                    Logger.scan.warning("multiple mode-active patterns match: \(modeActive.map(\.pattern.kind))")
                }
                headMatch = winner.token
                headPattern = winner.pattern
            } else {
                // No mode-active patterns — build Schrödinger chain
                // Keywords/non-skip go to front, skip/non-keyword go to back
                let front = candidates.filter { $0.pattern.isKeyword && !$0.pattern.isSkip }
                let back = candidates.filter { !($0.pattern.isKeyword && !$0.pattern.isSkip) }
                let ordered = front + back

                headMatch = ordered[0].token
                headPattern = ordered[0].pattern
                var tail = headMatch
                for candidate in ordered.dropFirst() {
                    tail.dual = candidate.token
                    tail = candidate.token
//                    Logger.scan.debug("Schrödinger: \(candidate.token.kind)")
                }
            }

            if headPattern.isSkip {
                trivia[tokens.count].append(headMatch)
            } else {
                tokens.append(headMatch)
                trivia.append([])
            }
            matchStart = matchEnd

            // manage the scanner mode
            if headPattern.mode.isPop {
                if let _ = modeStack.popLast() {
//                    Logger.scan.debug("popped into previous scan mode: \(self.scannerMode)")
                } else {
                    Logger.scan.error("too many pops from scanner mode stack!")
                    exit(1)
                }
            } else if !headPattern.mode.pushName.isEmpty {
                modeStack.append(headPattern.mode.pushName)
//                Logger.scan.debug("pushed new scan mode: \(self.scannerMode) match: \(headMatch.image) pattern: \(headPattern.kind)")
            }
        }

        tokens.append(Token(image: "$", kind: "○"))  // append EndOfString token
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
//        for rp in regexPatterns {
//            error += "\n\(rp.kind)"
//        }
        Logger.scan.error("\(error)")
        throw ScannerFailure.charactersDoNotMatchAnySymbol(position: position, input: input)
    }
}
