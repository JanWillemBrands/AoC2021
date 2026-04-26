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
    var isPush = false
    var isCheck = false
    var isPop = false
    
    var isActive: Bool {
        isPush || isCheck || isPop
    }
    
    var description: String {
        var d = ""
        if isPush {
            d += ">>> \(modeName)"
        }
        if isCheck {
            d += "=== \(modeName)"
        }
        if isPop {
            d += "<<< \(modeName)"
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
        return modeStack.last ?? ""
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
        var charsScanned = 0
        let inputSize = input.utf8.count
        let scanInterval = 10_000
        let scanByteLimit = 0
        var patternTime: [String: Double] = [:]
        var patternCalls: [String: Int] = [:]

        while matchStart != input.endIndex {
            var matchEnd = matchStart
            var candidates: [Candidate] = []
            let remaining = input[matchStart...]

            // Phase 1: literal keywords via hasPrefix (fast string comparison)
            for lp in literalPatterns {
                guard lp.mode.modeName == "" || lp.mode.modeName == scannerMode || lp.mode.isPush else { continue }

                if remaining.hasPrefix(lp.kind) {
                    let literalEnd = input.index(matchStart, offsetBy: lp.kind.count)
                    if literalEnd > matchEnd {
                        matchEnd = literalEnd
                        candidates.removeAll()
                    }
                    if literalEnd == matchEnd {
                        candidates.append(Candidate(
                            token: Token(image: input[matchStart..<literalEnd], kind: lp.kind),
                            pattern: lp))
                    }
                }
            }

            // Phase 2: regex patterns via prefixMatch (regex engine)
            for rp in regexPatterns {
                guard rp.mode.modeName == "" || rp.mode.modeName == scannerMode  || rp.mode.isPush else { continue }

                let t0 = CFAbsoluteTimeGetCurrent()
                let match = remaining.prefixMatch(of: rp.regex)
                let elapsed = CFAbsoluteTimeGetCurrent() - t0
                patternTime[rp.kind, default: 0] += elapsed
                patternCalls[rp.kind, default: 0] += 1
                if elapsed > 1.0 {
                    print("  SLOW REGEX: '\(rp.kind)' took \(String(format: "%.1f", elapsed))s at byte \(charsScanned)/\(inputSize)")
                }

                if let match {
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
                    Logger.scan.warning("multiple mode-active patterns match: \(modeActive.map(\.pattern.kind), privacy: .public)")
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
                }
            }
            
            if headPattern.isSkip {
                trivia[tokens.count].append(headMatch)
            } else {
                tokens.append(headMatch)
                trivia.append([])
            }
            matchStart = matchEnd
            charsScanned += headMatch.image.utf8.count
            if charsScanned % scanInterval < headMatch.image.utf8.count {
                print("  scan: \(charsScanned)/\(inputSize) bytes, \(tokens.count) tokens")
            }
            if scanByteLimit > 0 && charsScanned >= scanByteLimit {
                print("  scan stopped at byte limit \(scanByteLimit)")
                break
            }

            // manage the scanner mode
            if headPattern.mode.isPush {
                modeStack.append(headPattern.mode.modeName)
//                Logger.scan.debug("pushed new scan mode: \(self.scannerMode) match: \(headMatch.image) pattern: \(headPattern.kind)")
            } else if headPattern.mode.isPop {
                if let _ = modeStack.popLast() {
//                    Logger.scan.debug("popped into previous scan mode: \(self.scannerMode)")
                } else {
                    fatalError("\(#function) too many pops from scanner mode stack!")
                }
            }
        }
        
        tokens.append(Token(image: "$", kind: "○"))  // append EndOfString token

        let sortedByTime = patternTime.sorted { $0.value > $1.value }
        print("  scan complete: \(inputSize) bytes, \(tokens.count) tokens")
        print("  regex pattern timing (top 10):")
        for (kind, time) in sortedByTime.prefix(10) {
            let calls = patternCalls[kind, default: 0]
            let avg = calls > 0 ? time / Double(calls) : 0
            print("    \(String(format: "%8.3f", time * 1000))ms total, \(String(format: "%6d", calls)) calls, \(String(format: "%.3f", avg * 1000))ms avg — \(kind)")
        }
    }

    var gaps: GapChannel {
        GapChannel(tokens: tokens, input: input, tabWidth: 8)
    }

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
        Logger.scan.error("\(error, privacy: .public)")
        throw ScannerFailure.charactersDoNotMatchAnySymbol(position: position, input: input)
    }
}

// MARK: - Gap Channel
//
// Layer 1 of the layout-sensitive parsing architecture (see "Layout Sensitive Parsing.md").
//
// GapChannel is a lazy, non-caching view that computes spatial relationships between adjacent
// tokens on demand. All computations derive from Token.image Substring positions in the original
// input string — no auxiliary data structures needed.
//
// Three fields answer three questions:
//   empty      — are the tokens touching?       (for future >:< / <:> constraints)
//   lineBreaks — how many lines apart?           (for >>| / |<< indent injection)
//   column     — where on the line does it sit?  (for >>| / |<< indent injection)
//
// Key design choice: the newline scan spans from the previous token's START (not END) to the
// current token's start. This is necessary for languages where newlines are visible tokens
// (e.g. Python's NEWLINE): the \n is consumed by the token, leaving zero characters in the
// inter-token gap. Scanning from the previous token's start ensures the newline is detected.

struct Gap {
    let empty: Bool
    let lineBreaks: Int
    let column: Int
}

struct GapChannel {
    let tokens: [Token]
    let input: String
    let tabWidth: Int

    subscript(i: Int) -> Gap {
        guard i > 0 else {
            let col = columnOf(tokens[0].image.startIndex)
            return Gap(empty: true, lineBreaks: 1, column: col)
        }
        let prevEnd = tokens[i - 1].image.endIndex
        let currStart = tokens[i].image.startIndex
        let gapEmpty = prevEnd == currStart
        // Scan from previous token's START so that newlines inside the
        // previous token (e.g. a visible NEWLINE terminal) are detected.
        let span = input[tokens[i - 1].image.startIndex..<currStart]
        var breaks = 0
        var prevWasCR = false
        for ch in span {
            let isCR = ch == "\r"
            let isLF = ch == "\n"
            if isCR || (isLF && !prevWasCR) { breaks += 1 }
            prevWasCR = isCR
        }
        return Gap(empty: gapEmpty, lineBreaks: breaks, column: columnOf(currStart))
    }

    private func columnOf(_ index: String.Index) -> Int {
        var col = 0
        var i = index
        while i > input.startIndex {
            let prev = input.index(before: i)
            let ch = input[prev]
            if ch == "\n" || ch == "\r" { break }
            col += ch == "\t" ? (tabWidth - col % tabWidth) : 1
            i = prev
        }
        return col
    }
}

